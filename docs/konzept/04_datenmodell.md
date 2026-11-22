# Datenmodell und Tests

Stand: 21.11.2026, umgesetzt in Etappe 1: Haushalt, Studienmodus, Rollen (siehe unten).

## 1. Ergänzungen im Datenmodell

### `/monitors/{monitorId}` (bestehend, Felder neu)

| Feld | Typ | Wer setzt | Zweck |
|---|---|---|---|
| `study_mode` | bool, Default `false` | Team in der Firebase Console | Studienmodus, blendet Auswertungen aus |
| `study_note` | string, optional | Team | Text im Hinweis, z.B. "Messjahr bis Oktober 2028" |

### `/monitors/{monitorId}/household/{validFrom}` (neu)

| Feld | Typ | Zweck |
|---|---|---|
| `valid_from` | Datum | ab wann gültig |
| `persons` | number | Personen, die hier wohnen |
| `living_area_m2` | number | Wohnfläche |
| `label_w_per_person` | number, optional | Wert aus dem KWF-Energielabel, z.B. 90 |
| `updated_by`, `updated_at` | | Nachvollziehbarkeit |

Bewohnende mit `monitor_edit` dürfen Einträge anlegen, aber nicht löschen oder rückwirkend ändern. Korrekturen erfolgen mit einem neuen Eintrag. Damit bleibt für die Studie nachvollziehbar, wann sich die Belegung geändert hat.

### `/users/{uid}` (bestehend, Feld neu)

| Feld | Zweck |
|---|---|
| `role: "admin"` | Team Energiemonitor, sieht Studienmonitore vollständig und den Systemstatus aller Monitore. Nur über Console oder Admin SDK änderbar. |

### `/devices/{deviceId}/metering_points/{mp}` (bestehend, Feld neu)

| Feld | Zweck |
|---|---|
| `sensors.{sensor_id}.last_seen` | Status pro Sensor, damit ein Ausfall der Netatmo unter K0 sichtbar wird. Wird von der API bei `POST /telemetry` nachgeführt. |

### `/monitors/{monitorId}` weitere Felder

| Feld | Zweck |
|---|---|
| `upload_interval_min` | Sende-Intervall des Connectors, für "nächste Daten gegen 15:00" und die Status-Schwellen |

### `/config/info_texts` (neu, optional)

Texte der Info-Overlays mit Platzhaltern, damit sie ohne neuen App-Build angepasst werden können. Startfassung in `05_Datenherkunft_und_Infotexte.md`, Abschnitt 4.

### `/config/factors` (neu)

Heizwerte und Primärenergiefaktoren mit Quelle und Datum (siehe `02_Daten_und_Widgets.md`, 3.4). Nur lesbar für die App.

### `/devices/{deviceId}/daily/{YYYY-MM-DD}` (neu, nur durch Backend geschrieben)

Ein Dokument pro Tag in Lokalzeit Europe/Zurich:

```json
{
  "date": "2026-07-14",
  "energy_kwh": { "E1": 0.0, "E2": 0.0, "E3": 3.4, "A1": 0.08, "I1": 0, "I2": 0.0, "I3": 2.3 },
  "manual_kwh_estimated": { "propane": 0.8, "pellets": 0 },
  "climate": { "t_in_median": 26.1, "t_in_p05": 22.0, "t_in_p95": 31.4, "rh_in_median": 44,
               "co2_median": 610, "co2_max": 1420, "t_out_mean": 21.3, "hours_over_28": 6.5 },
  "occupied": true, "occupancy_source": "sensirion_scd4x",
  "fire_events": [{"start": "19:20", "end": "22:40", "rise_k_per_h": 5.8, "weight": 3.3}],
  "manual_alloc": { "pellets": {"kg": 1.6, "method": "ofensignatur", "provisional": false},
                     "propane": {"kg": 0.06, "method": "bewohnte_tage", "provisional": true} },
  "climate_source": "netatmo",
  "availability": { "E1": 1.0, "E3": 1.0, "I2": 1.0, "K1": 0.98 },
  "hourly_kwh": { "E3": [0,0,0,0,0,0.05, ...24 Werte] },
  "computed_at": "...", "version": 1
}
```

Klimawerte werden nach `sensor_id` getrennt aggregiert (Studienquelle `netatmo`), weil alle Klimasensoren heute unter K0 und mit gleichen Feldnamen ankommen. `method` und `provisional` sagen der App und dem Info-Overlay, wie ein Brennstoffwert entstanden ist. Ein neuer Formulareintrag löst eine Neuberechnung der `manual_alloc` aller Tage seit dem vorherigen Eintrag aus.

Damit liest die Jahresauswertung 365 kleine Dokumente statt rund 12 Mio. Datenpunkte. Die Belegung und alle Schwellen sind dieselben wie in der Auswertung Langzeittest, damit App und Studie gleich rechnen.

**Wo gerechnet wird:** Vorschlag als neuer Endpunkt in der bestehenden `energiemonitor-api` (`POST /aggregate?device=…&date=…`), ausgelöst stündlich durch Cloud Scheduler für "heute bis jetzt" und einmal nachts für gestern (Nachlieferungen nach Funkunterbruch). Die Logik aus dem Python-Auswerteskript des Langzeittests kann weitgehend übernommen werden. Kosten: gering, ein Cloud-Scheduler-Job und kurze Cloud-Run-Aufrufe **(prüfen)**.

## 2. Firestore-Rules

- `daily`: lesen mit `monitor_read`, schreiben nur Backend.
- `household`: lesen mit `monitor_read`, anlegen mit `monitor_edit`, kein Update und kein Delete für User.
- `monitors.study_mode`: lesen ja, schreiben nein.
- Optional strenger Studienmodus: Lesen von `telemetry` und `daily` nur, wenn `study_mode == false` oder `role == admin` **(offen, mit HSLU klären, ob nötig)**.


## 5. Tests vor dem Livegang

- Formular: gleiche Eingaben in alter und neuer App ergeben byte-gleiche Firestore-Dokumente (ausser ID und `created_at`). Testfälle: erster Eintrag, zweiter Eintrag gleicher Träger, Eintrag über den Jahreswechsel, Holz kg und Ster, Rest grösser als Vorrat (consumed 0).
- Ofensignatur: Für Beispielhaus April und Mai müssen die erkannten Feuer die acht Abende aus der Auswertung Langzeittest treffen (21., 22., 24.4., 12., 14. bis 17.5.). Im Winter 2026/27 Schwellen nachprüfen, wenn der Ofen länger brennt.
- Erfassen: Screenshot-Vergleich normaler Modus und Studienmodus, die Seite muss pixelgleich sein.
- Studienmodus: Monitor mit Flag zeigt nur Erfassen und Mehr, Deep-Links auf Auswertung führen zurück zu Erfassen, Admin sieht alles mit Band.
- Tageswerte für Beispielhaus April bis September stimmen mit interne Auswertung überein (PV 555.1 kWh, Netz 0, I2 79.8 kWh, 125 bewohnte Tage).


## Umsetzung Etappe 1: Abweichungen und Ergänzungen

- **Rolle Admin:** nicht als Feld `role` im User-Dokument, sondern in `/roles/{uid}` mit `admin: true`. Lesen darf nur die Person selbst, schreiben niemand aus der App (nur Firebase Console oder Admin SDK). So kann sich niemand selbst Rechte geben. Ein Superadmin mit Verwaltungs-Oberfläche folgt in Etappe 1b.
- **Haushalt:** Dokument-ID `YYYY-MM-DD_<Erfassungszeitpunkt>`, damit auch eine Korrektur am selben Tag ein neuer Eintrag ist und nichts überschrieben wird. Gültig ist der jüngste Eintrag mit `valid_from` bis zum gefragten Tag. Die Rules prüfen Felder und Wertebereiche (1 bis 20 Personen, Fläche bis 1000 m², `updated_by` = angemeldete Person, `updated_at` = Serverzeit).
- **Studien-Dialog:** gesehen pro Person und Monitor in `/users/{uid}.study_dialog_seen` (Liste der Monitor-IDs).
- **Formular:** Mengen dürfen ein Komma haben ("11,5" = "11.5"), negative Mengen werden abgelehnt. Sonst fachlich unverändert, gespeichert über `Energy.addToFirebase()`.

## Tests in der Umsetzung

| Test | Wo | Läuft mit |
|---|---|---|
| Formular-Regressionstest: altes und neues Formular ergeben denselben Firestore-Zustand | `integration_test/form_regression_test.dart` | `node tool/run_integration.mjs` (Chrome und Firebase-Emulator) |
| Firestore-Rules mit allen Ablehnungsfällen | `integration_test/rules_test.dart` | wie oben |
| Erfassen im normalen Modus, im Studienmodus und als Admin pixelgleich | `test/golden/erfassen_golden_test.dart` | `flutter test` |
| Navigation, Studienmodus, Admin-Band, Studien-Dialog, Haushalt-Einstieg | `test/widget/navigation_test.dart` | `flutter test` |
| Logik (Vorrat, Erinnerung, Vorschlag, Status-Schwellen, Download-Aufteilung, Texte) | `test/unit/` | `flutter test` |
