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

- **Keine Admin-Rolle.** Das Feld `role: "admin"` aus dem Konzept gibt es nicht. Niemand sieht alle Häuser; Zugriff auf ein Haus gibt es nur über `monitor_read` und `monitor_edit`. Der Studienmodus gilt für alle, auch für das Team.
- **Haushalt:** Dokument-ID `YYYY-MM-DD_<Erfassungszeitpunkt>`, damit auch eine Korrektur am selben Tag ein neuer Eintrag ist und nichts überschrieben wird. Gültig ist der jüngste Eintrag mit `valid_from` bis zum gefragten Tag. Die Rules prüfen Felder und Wertebereiche (1 bis 20 Personen, Fläche bis 1000 m², `updated_by` = angemeldete Person, `updated_at` = Serverzeit).
- **Studien-Dialog:** gesehen pro Person und Monitor in `/users/{uid}.study_dialog_seen` (Liste der Monitor-IDs).
- **Formular:** Mengen dürfen ein Komma haben ("11,5" = "11.5"), negative Mengen werden abgelehnt. Sonst fachlich unverändert, gespeichert über `Energy.addToFirebase()`.

## Etappe 1b: Superadmin und Zugriffsverwaltung

- **Superadmin** ist ein Custom Claim `superadmin: true` im Login-Token von Firebase Auth. Er wird nur mit `tool/admin/set_superadmin.mjs` gesetzt (Identity Toolkit API mit dem gcloud-Login des Teams), nie aus der App. Die Rules prüfen `request.auth.token.superadmin == true`. Nach dem Setzen muss sich die Person einmal neu anmelden.
- Ein Superadmin **verwaltet Zugriffe, sieht aber keine Messdaten** von Häusern, die ihm nicht zugeordnet sind.
- **Verwaltung** in der App unter "Mehr > Zugänge verwalten": alle Konten mit E-Mail, pro Haus "Kein Zugriff", "Lesen" oder "Bearbeiten", Übersicht pro Haus, Protokoll.
- **E-Mail im User-Dokument** (`/users/{uid}.email`): beim Registrieren und bei jeder Anmeldung aus dem Login-Token nachgeführt; die Rules lassen nur die E-Mail aus dem Token zu. Bestehende Konten einmalig mit `tool/admin/backfill_emails.mjs`.
- **Protokoll** `/admin_log/{id}` mit Verfasser, Konto, vorher und nachher. Die Rules verlangen, dass jede Änderung von `monitor_read`/`monitor_edit` durch den Superadmin im selben Batch einen Protokolleintrag schreibt, der genau diese Änderung beschreibt (`access_log_id`). Einträge kann niemand ändern oder löschen.

| Pfad | Lesen | Schreiben |
|---|---|---|
| `/users/{uid}` | eigene Person; Superadmin alle | eigene Person nur `user_name`, `nickname_changed`, `study_dialog_seen`, `email` (= Token); Superadmin nur `monitor_read`, `monitor_edit` mit Protokoll; Bearbeiten nur zusammen mit Lesen |
| `/monitors/{id}` | mit Zugriff auf das Haus; Liste nur Superadmin | niemand aus der App |
| `/admin_log/{id}` | Superadmin | Superadmin anlegen (als er selbst, Serverzeit), nie ändern |

## Tests in der Umsetzung

| Test | Wo | Läuft mit |
|---|---|---|
| Formular-Regressionstest: altes und neues Formular ergeben denselben Firestore-Zustand | `integration_test/form_regression_test.dart` | `node tool/run_integration.mjs` (Chrome und Firebase-Emulator) |
| Firestore-Rules mit allen Ablehnungsfällen, inklusive Superadmin und Protokoll | `integration_test/rules_test.dart` | wie oben |
| Verwaltung der Zugänge | `test/widget/admin_test.dart` | `flutter test` |
| Erfassen im normalen Modus und im Studienmodus pixelgleich | `test/golden/erfassen_golden_test.dart` | `flutter test` |
| Navigation, Studienmodus, Admin-Band, Studien-Dialog, Haushalt-Einstieg | `test/widget/navigation_test.dart` | `flutter test` |
| Logik (Vorrat, Erinnerung, Vorschlag, Status-Schwellen, Download-Aufteilung, Texte) | `test/unit/` | `flutter test` |

## Umsetzung Etappe 2: Tageswerte

Die Tageswerte rechnet die `energiemonitor-api` (Endpunkt `POST /aggregate`, Code in `src/aggregation/`). Die App liest sie nur (`lib/daily/daily_values.dart`); die Diagramme folgen in Etappe 3.

**Wann gerechnet wird:** Cloud Scheduler ruft stündlich `mode=hourly` (heute bis jetzt) und einmal nachts `mode=nightly` (die letzten drei Tage, für Nachlieferungen nach einem Funkunterbruch) auf. Vergangene Zeiträume rechnet das Team einmalig mit `tools/backfill_daily.py` im API-Repo nach.

**Dokument** `/devices/{deviceId}/daily/{YYYY-MM-DD}`, Tag in Lokalzeit Europe/Zurich. Abweichungen vom Entwurf oben:

| Feld | Inhalt |
|---|---|
| `energy_kwh`, `hourly_kwh` | Strom pro Messpunkt, aus der Leistung aufsummiert. Ein Wert gilt bis zum nächsten, höchstens 3 mal der übliche Abstand; längere Lücken zählen nicht und senken `availability`. `hourly_kwh` hat 24 Werte nach Uhrzeit (an der Zeitumstellung zählt die doppelte Stunde zusammen). |
| `energy_sensor` | welcher Sensor gezählt wurde (Reihenfolge victron, shelly-3em-pro, pzem-017). Rückspeisung als negative Leistung an E1 erscheint als `E2`, wenn es keinen eigenen Messpunkt E2 gibt. |
| `climate` | Viertelstundenmittel der Studienquelle Netatmo (sonst Sensirion, `climate_source`): Median, 5. und 95. Perzentil, Höchstwert innen, Feuchte, CO2, Tagesmittel aussen, `hours_over_28`, dazu `t_in_mean_08_20` für die heisseste Woche. |
| `hourly_climate` | Median pro Stunde für Innentemperatur und CO2 (Heatmap). |
| `occupied`, `occupancy_source`, `co2_peak`, `co2_rise` | bewohnt aus dem CO2, Rohwerte, kein Mittel, wie in der Auswertung Langzeittest. Sensirion SCD4x: Höchstwert über 600 ppm. Netatmo (Ersatz): Höchstwert mehr als 150 ppm über dem 10. Perzentil des Tages (`co2_rise`), weil ihr Nullpunkt wandert. `null` bei zu wenig Daten. |
| `fire_events`, `fire_source` | erkannte Feuer mit Beginn, Ende, Anstieg und Gewicht (Brenndauer in Stunden). |
| `manual_alloc` | pro Energieträger: `quantity` und `unit` (Einheit des Formulars: kg, Ster, Liter), `method` (`ofensignatur`, `heizgradtage`, `bewohnte_tage`, `gleichmaessig`), `provisional`, `incomplete` (ein Messpunkt noch nicht schätzbar), `fires`, `by_metering_point`. `quantity: null` heisst: noch nicht schätzbar (es fehlt ein abgeschlossener Zeitraum). |
| `manual_kwh_estimated` | Menge mal Heizwert aus `/config/factors`; ohne Faktor fehlt der Wert. |
| `partial`, `data_until` | heute noch nicht vorbei; Zeitpunkt des letzten Messwerts. |

**Ofensignatur:** wie in `05_infotexte.md`, mit einer Schärfung: Die Sonne zählt ab 2 Stunden vor dem Anstieg (E3 nie über 300 W), weil der Victron mit voller Batterie die PV drosselt und E3 dann wenig zeigt, obwohl die Sonne scheint. Scheint nach dem Feuer die Sonne, endet dort die Brenndauer.

**Verteilung der Brennstoffe:** Die Reihen sind wie im Formular nach Messpunkt und Energieträger getrennt. Abgeschlossene Zeiträume werden nach der ersten Methode mit Gewicht verteilt; laufende Zeiträume mit der Menge pro Gewicht aus dem letzten abgeschlossenen Zeitraum, als vorläufig. Kommt ein Formulareintrag dazu, rechnet der nächste stündliche Lauf alle Tage seit dem vorherigen Zeitraum neu. Der Stand dafür liegt in `/devices/{deviceId}/aggregation/state` (nur Backend).

**Abgleich mit der Auswertung Langzeittest** (Beispielhaus, 1.4. bis 30.9.2026, aus den echten Rohdaten gerechnet, nichts geschrieben):

| Wert | Auswertung Langzeittest | Tageswerte |
|---|---|---|
| PV (E3) | 555.1 kWh | 555.0 kWh |
| Netzbezug (E1) | 0 kWh | 0 kWh |
| Bodenheizung (I2) | 79.8 kWh | 79.9 kWh |
| bewohnte Tage | 125 | 125 |
| Feuer | 21., 22., 24.4., 12., 14. bis 17.5. | dieselben 8 Tage |

Mit nur der Netatmo als CO2-Quelle ergibt die Anstiegsregel im selben Zeitraum 127 bewohnte Tage, an 167 von 183 Tagen gleich wie mit dem Sensirion. Ein fester Schwellwert für die Netatmo trifft höchstens 151 von 183 Tagen.

Winter: Im November erkennt die Ofensignatur fast jeden Morgen um 06:00 ein Feuer. Das stimmt: Der Pelletofen im Beispielhaus startet morgens automatisch. Lange Feuer erreichen im Winter oft die Obergrenze von 12 Stunden (prüfen mit Daten bis Februar 2027).

### Rules Etappe 2

| Pfad | Lesen | Schreiben |
|---|---|---|
| `/devices/{id}/daily/{tag}` | mit `monitor_read` | niemand aus der App |
| `/devices/{id}/aggregation/{doc}` | niemand | niemand aus der App |
| `/config/factors` | angemeldet | niemand aus der App |

`/config/factors` pflegt das Team in der Firebase Console: `{"heating_values": {"pellets": {"value": …, "unit": "kWh/kg", "source": "…"}}, "primary_energy_factors": {…}}`. Ohne Heizwert bleibt `manual_kwh_estimated` leer.

## Umsetzung Etappe 3: Übersicht und Auswertung

Die App liest die Tageswerte eines Zeitraums (`DailyRepository`, 10 Minuten im Speicher) und `/config/factors` (`FactorsRepository`, einmal pro Start) und fasst sie in `lib/daily/summary.dart` zusammen. Aus Rohdaten rechnet sie nichts.

| Grösse | Rechnung |
|---|---|
| Solarstrom selbst genutzt | pro Tag E3 minus E2, mindestens 0 |
| Endenergie Wohnen | Netz E1 + Solarstrom selbst genutzt + Brennstoffe in kWh (`manual_kwh_estimated`, sonst Menge mal Heizwert). Diesel und Benzin zählen nicht. |
| Eigenversorgung | Solarstrom selbst genutzt geteilt durch (Solarstrom selbst genutzt + E1) **(prüfen mit HSLU)** |
| Eigenverbrauch | Solarstrom selbst genutzt geteilt durch E3 |
| Personen-Stunden | pro Tag Personen aus "Haushalt" mal 24 h, heute bis `data_until`. Tage ohne Personen zählen für Werte pro Person nicht (weder Energie noch Stunden). |
| Minergie | Summe über Tage mit Personen: g_Strom × (E1 + selbst genutzt) − g_Strom × selbst genutzt × `pv_self_consumption_credit` − g_Strom × E2 × `pv_feed_in_credit` + Σ g_Träger × Brennstoff-kWh, mindestens 0 **(prüfen mit Label-Team)** |
| 2000 Watt | Summe über Tage mit Personen: E1 × PE_Strom + Σ PE_Träger × Brennstoff-kWh (`primary_energy_factors.*.total`) |
| Watt pro Person | kWh × 1000 / Personen-Stunden |
| Heizen | I2 + Brennstoff fürs Heizen (`by_metering_point.M2` × Heizwert); Solaranteil = I2 × Eigenversorgung des Tages |
| Klima | Median der Tagesmediane an bewohnten Tagen (sonst aller Tage); Bereich und Komfortstunden aus `hourly_climate.t_in` |
| Heatmap | Median von `hourly_climate.co2` pro Wochentag und Stunde, ab 28 Tagen |
| Lückenhaft | `availability` von E1 oder E3 unter 0.9; der Tag zählt, wird aber ausgewiesen |

Fehlt ein Faktor, fehlt der Wert, der ihn braucht. Es gibt keinen Ersatzwert im Code.

**Neues Feld `benchmarks` in `/config/factors`** (Vergleichswerte für Watt pro Person):

```json
"benchmarks": {
  "target_2000w": {"label": "2000-Watt-Ziel", "value": 420, "method": "2000watt", "source": "…"},
  "ch_today":     {"label": "Schweiz heute",  "value": 1300, "method": "2000watt", "source": "…"}
}
```

`method` sagt, mit welcher Rechnung der Wert vergleichbar ist (`minergie` oder `2000watt`). Ohne das Feld fehlen die Balken. Der Label-Wert kommt aus "Haushalt" (`label_w_per_person`).
