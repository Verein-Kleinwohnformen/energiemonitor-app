# CLAUDE.md

Hinweise für Claude Code in diesem Repo. Die App ist eine Flutter-Web-App (PWA) für den KWF Energiemonitor.

## Konzept

Das Konzept steht in [`docs/konzept/`](docs/konzept/README.md). Lies es, bevor du Navigation, Formular, Studienmodus oder Texte änderst.

## Regeln

- **Das Formular für Energieträger bleibt fachlich 1:1.** Felder, Auswahlwerte, Pflichtfelder, Prüfungen, Berechnung von `consumed_quantity`, Nachführung des Vorgänger-Eintrags und das Firestore-Dokument bleiben gleich. Die Einträge sind Studiendaten.
- **`lib/energy.dart` nicht ändern.** Das alte Formular in `lib/legacy/` bleibt unverändert, solange der Regressionstest es braucht.
- **Formular-Regressionstest zuerst.** Wer am Formular arbeitet, lässt `integration_test/form_regression_test.dart` vorher und nachher laufen.
- **Erfassen sieht im Studienmodus und im normalen Modus gleich aus.** Der Golden-Test `test/golden/erfassen_golden_test.dart` prüft das.
- **Kein Deploy** auf Firebase Hosting oder Cloud Run ohne ausdrückliches OK des Teams. Kein Schreiben in die produktive Firestore-Datenbank. Rules und Daten im Emulator testen.
- **Kein force-push**, kein Umschreiben der Git-History, nichts direkt auf `main`. Pro Etappe ein Branch `feature/neukonzept-etappe-<n>` und ein Pull Request.
- **Das Repo ist öffentlich:** keine Secrets, Device-Keys, Passwörter, persönlichen Daten, Namen von Bewohnenden oder lokalen Pfade.
- **Texte:** Deutsch, Du-Form, Schweizer Rechtschreibung (ss statt ß), keine Emojis.
- **Unsichere Annahmen** mit `TODO(prüfen):` im Code markieren und im Pull Request auflisten.
- **Faktoren** (Heizwerte, Primärenergiefaktoren) nie im Code, sondern aus `/config/factors`.
- **Zugriff nur über die Zuordnung.** Es gibt keine Rolle, die alle Häuser sieht. Superadmin ist ein Custom Claim, gesetzt nur mit `tool/admin/set_superadmin.mjs`; er verwaltet Zugriffe, sieht aber keine fremden Daten.
- **Keine Auswertung aus Rohdaten in der App.** Die App liest Tageswerte aus `daily` (ab Etappe 2).

## Befehle

```
flutter test                        # Unit-, Widget- und Golden-Tests
flutter test --update-goldens test/golden
node tool/run_integration.mjs       # Regressionstest und Rules-Tests (Chrome, Firebase-Emulator)
```

Lokal durchklicken mit Beispieldaten:

```
firebase emulators:start --only "firestore,auth" --project demo-energiemonitor
node tool/seed_emulator.mjs
flutter run -d chrome --dart-define=USE_EMULATOR=true
```

`USE_EMULATOR` verbindet die App mit dem Demo-Projekt, nie mit der produktiven Datenbank. Lokal meldet man sich nach jedem Neuladen neu an. In PowerShell `"firestore,auth"` in Anführungszeichen setzen. Die Tests nutzen eigene Emulator-Ports (`firebase.test.json`), ein laufender Dev-Emulator stört nicht.

Superadmin und E-Mails (Probelauf ohne `--apply`, mit `EMULATOR=1` gegen den Emulator):

```
node tool/admin/set_superadmin.mjs --project <projekt> --list
node tool/admin/set_superadmin.mjs --project <projekt> <uid> --apply
node tool/admin/backfill_emails.mjs --project <projekt> --apply
```

## Aufbau

| Ordner | Inhalt |
|---|---|
| `lib/app/` | Router, Session (Monitor, Rechte, Studienmodus), Dienste |
| `lib/shell/` | Kopfzeile mit Status-Pille, Tab-Leiste |
| `lib/capture/` | Seite Erfassen und Formular |
| `lib/more/` | Seiten unter "Mehr" |
| `lib/info/` | Info-Overlay und Texte (`info_texts.dart`) |
| `lib/admin/` | Verwaltung der Zugänge (Superadmin) |
| `lib/daily/` | Tageswerte aus `daily` lesen (gerechnet von der API) |
| `lib/theme/` | Tokens und Theme aus dem Design System des Vereins |
| `integration_test/` | Tests im Browser gegen den Emulator |
| `tool/` | Testlauf, Beispieldaten für den Emulator |
