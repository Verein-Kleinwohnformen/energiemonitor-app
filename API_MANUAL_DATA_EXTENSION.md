# API-Erweiterung für Manuelle Daten

## Übersicht

Die `energiemonitor-api` muss erweitert werden, um manuelle Energiedaten aus der Flutter-App zu exportieren und mit automatischen Telemetriedaten zu kombinieren.

## Neue Firestore-Struktur (App-seitig)

### Pfad
```
/devices/{device_id}/manual/{year}/data/{uuid}
```

**Wichtig:** 
- `{year}` ist ein Dokument (z.B. "2026")
- `data` ist eine Subcollection unter dem Jahr-Dokument
- `{uuid}` ist das Dokument für den einzelnen Eintrag

### Dokumentformat
```json
{
  "sensor_id": "app_form",
  "device_id": "emon01",
  "metering_point": "M1",
  "date": "2026-02-11",
  "day": 11,
  "year": 2026,
  "start_timestamp": 1739232000000,
  "end_timestamp": 1739232000000,
  "data_points": [
    {
      "timestamp": 1739232000000,
      "values": {
        "added_quantity": 150.0,
        "leftover_quantity": 50.0,
        "consumed_quantity": 100.0,
        "unit": "kg"
      }
    }
  ],
  "count": 1,
  "created_at": "2026-02-11T10:30:00Z",
  "metadata": {
    "description": "Holz gekauft bei Brennholz Meyer",
    "purchase_date": 1739232000000,
    "estimated_usage_date": 1741824000000,
    "usage_date_provisory": false,
    "user_id": "user123",
    "energy_type": "woodKg"
  }
}
```

### Metering Points
```
/devices/{device_id}/metering_points/{metering_point}
```

Neue manuelle Metering Points:
- **M0** - Gemischte Nutzung
- **M1** - Warmwasser
- **M2** - Heizwärme

Format (identisch mit automatischen):
```json
{
  "metering_point": "M1",
  "device_id": "emon01",
  "sensor_types": ["app_form"],
  "first_seen": 1739232000000,
  "last_seen": 1739232000000,
  "value_fields": ["added_quantity", "leftover_quantity", "consumed_quantity", "unit"],
  "description": "Warmwasser"
}
```

## API-Änderungen

### 1. Export-Endpoint erweitern

**Endpoint:** `GET /export`

**Neue Query-Parameter:**

| Parameter | Typ | Default | Beschreibung |
|-----------|-----|---------|--------------|
| `include_manual` | boolean | `true` | Manuelle Daten einbeziehen |
| `manual_only` | boolean | `false` | Nur manuelle Daten exportieren |

**Beispiele:**

```bash
# Automatische + Manuelle Daten
GET /export?start_date=2026-01-01&end_date=2026-02-11&include_manual=true

# Nur manuelle Daten
GET /export?start_date=2026-01-01&end_date=2026-02-11&manual_only=true

# Nur automatische Daten (bisheriges Verhalten)
GET /export?start_date=2026-01-01&end_date=2026-02-11&include_manual=false
```

### 2. Firestore Query-Logik

**Python-Code in `firebase_service.py`:**

```python
def get_manual_data(self, 
                    device_id: str, 
                    start_timestamp: int, 
                    end_timestamp: int) -> List[Dict[str, Any]]:
    """
    Retrieve manual energy data for a date range.
    
    Args:
        device_id: Device identifier
        start_timestamp: Start time in milliseconds
        end_timestamp: End time in milliseconds
        
    Returns:
        List of individual data points from manual entries
    """
    try:
        start_dt = datetime.fromtimestamp(start_timestamp / 1000, tz=timezone.utc)
        end_dt = datetime.fromtimestamp(end_timestamp / 1000, tz=timezone.utc)
        
        all_data_points = []
        
        # Query manual data by year
        for year in range(start_dt.year, end_dt.year + 1):
            # Query the year document's data subcollection
            year_doc_path = f'devices/{device_id}/manual/{year}'
            collection_ref = self.db.collection(f'{year_doc_path}/data')
            
            # Query all documents in this year's data collection
            docs = collection_ref.stream()
            
            for doc in docs:
                doc_data = doc.to_dict()
                data_points = doc_data.get('data_points', [])
                
                # Extract metadata
                sensor_id = doc_data.get('sensor_id', 'app_form')
                metering_point = doc_data.get('metering_point', 'M0')
                device_id_from_doc = doc_data.get('device_id')
                metadata = doc_data.get('metadata', {})
                
                # Flatten data points and filter by timestamp
                for point in data_points:
                    point_timestamp = point.get('timestamp')
                    
                    if start_timestamp <= point_timestamp <= end_timestamp:
                        full_point = {
                            'timestamp': point_timestamp,
                            'values': point.get('values', {}),
                            'sensor_id': sensor_id,
                            'metering_point': metering_point,
                            'device_id': device_id_from_doc,
                            'metadata': metadata  # Include description, energy_type, etc.
                        }
                        all_data_points.append(full_point)
        
        # Sort by timestamp
        all_data_points.sort(key=lambda x: x['timestamp'])
        
        logger.info(f"Retrieved {len(all_data_points)} manual data points for device {device_id}")
        return all_data_points
        
    except Exception as e:
        logger.error(f"Error retrieving manual data: {e}", exc_info=True)
        return []
```

### 3. Export-Service erweitern

**Datei:** `export_service.py`

**Änderungen:**

```python
def generate_xlsx(self, 
                  device_id: str, 
                  start_timestamp: int, 
                  end_timestamp: int,
                  include_manual: bool = True,
                  manual_only: bool = False) -> BytesIO:
    """
    Generate XLSX export with automatic and/or manual data.
    
    Args:
        device_id: Device identifier
        start_timestamp: Start time in milliseconds
        end_timestamp: End time in milliseconds
        include_manual: Include manual data
        manual_only: Export only manual data
        
    Returns:
        BytesIO: Excel file in memory
    """
    
    # Get automatic telemetry data (unless manual_only)
    telemetry_data = [] if manual_only else \
                     self.firebase_service.get_telemetry_data(
                         device_id, start_timestamp, end_timestamp
                     )
    
    # Get manual data (if requested)
    manual_data = [] if not include_manual else \
                  self.firebase_service.get_manual_data(
                      device_id, start_timestamp, end_timestamp
                  )
    
    # Combine and sort by timestamp
    all_data = telemetry_data + manual_data
    all_data.sort(key=lambda x: x['timestamp'])
    
    # Create Excel workbook
    wb = Workbook()
    
    # Sheet 1: All data combined (optional)
    ws_all = wb.active
    ws_all.title = "All Data"
    
    # Sheet 2: Automatic data only
    if telemetry_data:
        ws_auto = wb.create_sheet("Automatic")
        self._write_telemetry_sheet(ws_auto, telemetry_data)
    
    # Sheet 3: Manual data only
    if manual_data:
        ws_manual = wb.create_sheet("Manual")
        self._write_manual_sheet(ws_manual, manual_data)
    
    # Write combined data to first sheet
    self._write_combined_sheet(ws_all, all_data)
    
    # Save to BytesIO
    output = BytesIO()
    wb.save(output)
    output.seek(0)
    
    return output


def _write_manual_sheet(self, ws, manual_data: List[Dict[str, Any]]) -> None:
    """
    Write manual data to Excel sheet with special formatting.
    
    Columns:
    - Timestamp
    - Date
    - Time
    - Metering Point
    - Energy Type
    - Description
    - Added Quantity
    - Leftover Quantity
    - Consumed Quantity
    - Unit
    - Purchase Date
    - Estimated Usage Date
    - Provisory
    """
    
    # Headers
    headers = [
        'Timestamp', 'Date', 'Time', 'Metering Point', 
        'Energy Type', 'Description',
        'Added Quantity', 'Leftover Quantity', 'Consumed Quantity', 'Unit',
        'Purchase Date', 'Estimated Usage Date', 'Provisory'
    ]
    
    ws.append(headers)
    
    # Data rows
    for point in manual_data:
        timestamp = point['timestamp']
        dt = datetime.fromtimestamp(timestamp / 1000, tz=timezone.utc)
        
        values = point.get('values', {})
        metadata = point.get('metadata', {})
        
        # Extract fields
        purchase_date_ts = metadata.get('purchase_date', timestamp)
        purchase_date = datetime.fromtimestamp(purchase_date_ts / 1000, tz=timezone.utc)
        
        usage_date_ts = metadata.get('estimated_usage_date', timestamp)
        usage_date = datetime.fromtimestamp(usage_date_ts / 1000, tz=timezone.utc)
        
        row = [
            timestamp,
            dt.strftime('%Y-%m-%d'),
            dt.strftime('%H:%M:%S'),
            point.get('metering_point', 'M0'),
            metadata.get('energy_type', 'unknown'),
            metadata.get('description', ''),
            values.get('added_quantity', 0),
            values.get('leftover_quantity', 0),
            values.get('consumed_quantity', 0),
            values.get('unit', ''),
            purchase_date.strftime('%Y-%m-%d %H:%M'),
            usage_date.strftime('%Y-%m-%d %H:%M'),
            'Ja' if metadata.get('usage_date_provisory', True) else 'Nein'
        ]
        
        ws.append(row)
    
    # Format headers
    for cell in ws[1]:
        cell.font = Font(bold=True)
        cell.fill = PatternFill(start_color="CCCCCC", end_color="CCCCCC", fill_type="solid")
```

### 4. Route-Handler anpassen

**Datei:** `routes/export.py`

```python
@export_bp.route('/export', methods=['GET'])
@require_device_key
def export_data(device_id):
    """
    Export telemetry and/or manual data as XLSX.
    
    Query parameters:
    - start_date: Start date (YYYY-MM-DD or ISO timestamp)
    - end_date: End date (YYYY-MM-DD or ISO timestamp)
    - include_manual: Include manual data (default: true)
    - manual_only: Export only manual data (default: false)
    """
    try:
        # ... existing timestamp parsing logic ...
        
        # Get new query parameters
        include_manual = request.args.get('include_manual', 'true').lower() == 'true'
        manual_only = request.args.get('manual_only', 'false').lower() == 'true'
        
        logger.info(f"Device {device_id}: Exporting data - "
                   f"include_manual={include_manual}, manual_only={manual_only}")
        
        # Generate XLSX
        xlsx_file = export_service.generate_xlsx(
            device_id=device_id,
            start_timestamp=start_timestamp,
            end_timestamp=end_timestamp,
            include_manual=include_manual,
            manual_only=manual_only
        )
        
        # ... rest of existing code ...
```

## Testing

### Test-Szenarien

1. **Nur automatische Daten (bisheriges Verhalten)**
   ```bash
   curl -H "KWF-Device-Key: $API_KEY" \
        "$BASE_URL/export?start_date=2026-01-01&end_date=2026-02-11&include_manual=false" \
        -o export_auto.xlsx
   ```

2. **Kombinierte Daten**
   ```bash
   curl -H "KWF-Device-Key: $API_KEY" \
        "$BASE_URL/export?start_date=2026-01-01&end_date=2026-02-11&include_manual=true" \
        -o export_combined.xlsx
   ```

3. **Nur manuelle Daten**
   ```bash
   curl -H "KWF-Device-Key: $API_KEY" \
        "$BASE_URL/export?start_date=2026-01-01&end_date=2026-02-11&manual_only=true" \
        -o export_manual.xlsx
   ```

### Erwartete Ergebnisse

- Excel-Datei mit 2-3 Sheets:
  - "All Data" - Kombinierte Zeitreihe
  - "Automatic" - Nur Telemetriedaten (falls vorhanden)
  - "Manual" - Nur manuelle Daten (falls vorhanden)

## Backwards Compatibility

- Default `include_manual=true` → Manuelle Daten werden standardmäßig mitexportiert
- Bestehende Aufrufe ohne Parameter funktionieren weiterhin
- Keine Breaking Changes

## Performance-Überlegungen

- Manuelle Daten sind deutlich geringer im Volumen als Telemetriedaten
- Query-Performance sollte nicht signifikant beeinträchtigt werden
- Für große Zeiträume: Pagination oder Limit erwägen

## Firestore-Kosten

- Manuelle Daten: ~5-20 Einträge/Monat pro Device
- Zusätzliche Reads: Minimal (nur beim Export)
- Storage: Vernachlässigbar (~1-5 KB/Monat)

## Implementierungs-Checkliste

- [ ] `firebase_service.py` - `get_manual_data()` Methode hinzufügen
- [ ] `export_service.py` - `generate_xlsx()` erweitern
- [ ] `export_service.py` - `_write_manual_sheet()` implementieren
- [ ] `export_service.py` - `_write_combined_sheet()` anpassen
- [ ] `routes/export.py` - Query-Parameter `include_manual` und `manual_only` hinzufügen
- [ ] Tests schreiben
- [ ] Dokumentation aktualisieren (README.md)
- [ ] Deployment

## Beispiel-Ausgabe

### Manual Data Sheet

| Timestamp | Date | Time | Metering Point | Energy Type | Description | Added Quantity | Leftover | Consumed | Unit | Purchase Date | Est. Usage Date | Provisory |
|-----------|------|------|----------------|-------------|-------------|----------------|----------|----------|------|---------------|-----------------|-----------|
| 1739232000000 | 2026-02-11 | 10:00:00 | M1 | woodKg | Holz gekauft | 150.0 | 50.0 | 100.0 | kg | 2026-02-11 10:00 | 2026-04-09 10:00 | Nein |
| 1740441600000 | 2026-02-25 | 08:00:00 | M2 | diesel | Diesel-Nachfüllung | 20.0 | 5.0 | 15.0 | Liter | 2026-02-25 08:00 | 2026-03-15 08:00 | Ja |

---

**Erstellt:** 2026-02-11  
**Projekt:** KWF Energiemonitor API  
**Version:** 2.0
