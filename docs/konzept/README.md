# Konzept der Energiemonitor-App (öffentliche Fassung)

Diese Dokumente beschreiben, wie die App aufgebaut ist und warum. Sie sind die öffentliche Fassung des Konzepts vom November 2026. Zahlen darin sind Beispieldaten aus einem Langzeittest und als solche gemeint.

| Datei | Inhalt |
|---|---|
| [01_navigation_ux.md](01_navigation_ux.md) | Zielgruppen, Grundsätze, Navigation, Screens, Studienmodus |
| [03_formular.md](03_formular.md) | Das Formular für Energieträger: was fachlich gleich bleibt, was sich in der Bedienung ändert |
| [04_datenmodell.md](04_datenmodell.md) | Datenmodell-Ergänzungen, Firestore-Rules, Tests |
| [05_infotexte.md](05_infotexte.md) | Texte der Info-Overlays und wie Pellets, Holz und Gas auf Tage verteilt werden |

## Wichtigste Entscheide

- **Das Formular für Energieträger bleibt fachlich 1:1.** Gleiche Felder, Pflichtfelder, Prüfungen und gleiches Dokument in Firestore. Die Einträge sind Input-Daten für die Energiestudie mit der Hochschule Luzern (HSLU).
- **Studienmodus über ein Flag am Monitor** (`study_mode` in `/monitors/{id}`). Im Studienmodus sehen Bewohnende nur Erfassen und Mehr; alles, was Verbrauch zeigt, ist ausgeblendet. Die Seite Erfassen sieht in beiden Modi gleich aus.
- **Ehrlich über Daten.** Der Monitor lädt einmal pro Stunde hoch, nichts ist live. Jede Anzeige hat ein Info-Overlay mit Quelle, Rechnung und Sicherheit.
- **Pro Person, nicht pro Fläche.** Die Kennzahl des Vereins ist Watt Dauerleistung pro Person.

## Stand der Umsetzung

| Etappe | Inhalt | Stand |
|---|---|---|
| 1 | Neue Navigation, Theme, Studienmodus, Status, Erfassen, Mehr, Haushalt | umgesetzt |
| 1b | Superadmin mit Verwaltung der Zugänge, strengere Rules, keine Admin-Rolle | umgesetzt |
| 2 | Tageswerte in der API (Energie, Klima, Belegung, Verteilung der Brennstoffe) | umgesetzt, Betrieb mit Cloud Scheduler offen |
| 3 | Übersicht und Auswertung mit Diagrammen | geplant |
