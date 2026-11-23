# Navigation und Benutzerführung


Stand: 21.11.2026

## 1. Was heute nicht gut funktioniert

Aus dem Code (`lib/`, Stand 03/2026) und den Screenshots vom März 2026:

- **Fünf gleichwertige Menüpunkte** (Home, Liste, Ansicht, Download, Info). Info und Download sind selten gebraucht und nehmen gleich viel Platz ein wie das Formular.
- **Die Startseite ist eine Technik-Übersicht.** Messpunkt-Karten mit Kürzeln (E1, I2, M0), Sensor-IDs (`shelly-3em-pro`, `app_form`) und Online-Status. Für Bewohnende sagt das wenig, für uns ist es ein Systemcheck.
- **Rohdaten sind schwer zu lesen.** Erst Messpunkt, dann Sensor, dann Feldnamen wie `outdoor_module_reachable` oder `rf_signal_strength` auswählen, dann "Daten laden". Automatische Messpunkte maximal 10 Tage.
- **Das Formular heisst "Liste"** und ist hinter einem Plus versteckt. Dabei ist es das Wichtigste, was Bewohnende in der App tun.
- **Keine Antwort auf "Wie stehen wir da?"** Energiebilanz, Verbrauchsstatistik und Vergleiche fehlen (in der README als "noch nicht umgesetzt" aufgeführt).

## 2. Für wen die App ist

| Rolle | Was sie will | Häufigkeit |
|---|---|---|
| Bewohnende, normaler Modus | Verstehen, wie viel Energie das Haus braucht und woher sie kommt. Holz, Gas, Pellets eintragen. | Eintrag alle paar Wochen, Blick in die Übersicht wöchentlich |
| Bewohnende in der Energiestudie | Einträge machen, sehen, dass der Monitor läuft. Sonst in Ruhe gelassen werden. | Eintrag bei Kauf oder Flaschenwechsel |
| Team Energiemonitor (Admin) | Systemcheck über alle Monitore, Rohdaten zur Fehlersuche, Export für Auswertungen | bei Bedarf |
| Forschung (HSLU) | Exporte über längere Zeiträume | selten, eher über API |

## 3. Grundsätze

1. **Antwort zuerst, Werkzeug dahinter.** Jede Ansicht beginnt mit einem Satz, der eine Frage beantwortet ("Diese Woche kam 92 % deines Stroms von der Sonne").
2. **Pro Person, nicht pro Fläche.** Die Kennzahl des Vereins ist Watt Dauerleistung pro Person (Design System, Abschnitt Energiemonitor-App).
3. **Ehrlich über Herkunft und Aktualität.** Jede Zahl sagt, ob sie gemessen, berechnet, aus dem Formular geschätzt oder ein Vergleichswert ist. Oben steht immer "Stand 14:00", weil der Monitor stündlich hochlädt.
4. **Messpunkt-Kürzel als Zweitinformation.** In der Bedienung steht "Bodenheizung", das Kürzel I2 steht klein daneben, damit App, Export und Studie dieselbe Sprache sprechen.
5. **Ein Zeitraum-Umschalter pro Ansicht**, alle Diagramme folgen ihm (Komponente `RangeSwitch`).
6. **Das Formular ist überall einen Tipp entfernt.** Eigener Tab, ausserdem ein Hinweis auf der Übersicht, wenn ein Eintrag fällig sein könnte.
7. **Jede Zahl erklärt sich selbst.** Jede Kachel, jedes Diagramm und jede Kennzahl hat ein kleines Info-Symbol. Antippen öffnet ein Overlay mit fünf Teilen: was du siehst, woher die Daten kommen, wie wir rechnen, wie sicher das ist, Stand. Die Texte stehen in `05_Datenherkunft_und_Infotexte.md`, Abschnitt 4.
8. **Nur zeigen, was es für dieses Haus gibt.** Fehlt eine Datenquelle (z.B. kein Klimasensor), erscheint statt eines leeren Diagramms eine Zeile, was fehlt.

## 4. Navigation

### Normaler Modus: vier Tabs

```
┌──────────────────────────────────────────────┐
│  Beispielhaus ▾            ● Alles läuft · 14:00│  Kopfzeile: Hausname, Status-Pille
├──────────────────────────────────────────────┤
│                                              │
│                 Inhalt                       │
│                                              │
├───────────┬───────────┬───────────┬──────────┤
│ Übersicht │ Auswertung│ Erfassen  │ Mehr     │
└───────────┴───────────┴───────────┴──────────┘
```

| Tab | Frage, die er beantwortet | Inhalt |
|---|---|---|
| **Übersicht** | Wie lief die letzte Woche? | Wochenbilanz als Satz, Kacheln Verbrauch / Eigenversorgung / Wohnklima, Tagesbalken der Woche, Hinweise (z.B. "Seit 64 Tagen kein Gas-Eintrag") |
| **Auswertung** | Wie stehen wir im Vergleich da? | Zeitraum Woche / Monat / Saison bis jetzt / Jahr. Watt pro Person gegen Label, 2000-Watt-Ziel und Schweiz heute, Energiequellen-Mix, Selbstversorgungsgrad, Monatsbalken, Heizenergie, Wohnklima mit Komfortzone, Belegung |
| **Erfassen** | Was habe ich eingetragen, was muss ich eintragen? | Formular (gross), darunter Liste der Einträge mit Vorrat pro Energieträger |
| **Mehr** | Alles andere | Monitor wechseln, Haushalt, Systemstatus, Messwerte (Rohdaten), Daten herunterladen, Konto, Über die App |

Die Status-Pille in der Kopfzeile ist der Kurz-Check: grün "Alles läuft", gelb "1 Messpunkt verzögert", rot "Keine Daten seit 6 h". Antippen öffnet "Mehr > Systemstatus". Damit ist der Check immer sichtbar, aber nimmt keinen Platz auf der Startseite.

Der Hausname in der Kopfzeile mit Pfeil ▾ ist eine Abkürzung zum Monitorwechsel, nur sichtbar, wenn jemand Zugriff auf mehr als einen Monitor hat. Der eigentliche Ort ist "Mehr > Monitor wechseln".

### Studienmodus: zwei Tabs

```
├──────────────────────┬───────────────────────┤
│ Erfassen             │ Mehr                  │
└──────────────────────┴───────────────────────┘
```

- **Erfassen** ist die Startseite und sieht **genau gleich aus wie im normalen Modus**: gleiches Formular, gleiche Vorrat-Karten, gleiche Liste, gleiche Erinnerungen. Kein Banner, keine andere Beschriftung. Wer zwischen zwei Monitoren wechselt, findet sich sofort zurecht, und die Daten für die Studie entstehen in beiden Fällen auf demselben Weg.
- **Mehr** enthält nur: Systemstatus (ohne Messwerte, nur online/offline und Zeitpunkt) mit dem Mess-Schema, Haushalt, Monitor wechseln, Konto, "Über die Energiestudie", Über die App.
- Der Hinweis zur Studie ("Damit die Messung unverfälscht bleibt, zeigt die App während der Studie keine Auswertungen. Deinen persönlichen Bericht bekommst du nach dem Messjahr.") erscheint einmal beim ersten Öffnen eines Studienmonitors als Dialog und danach dauerhaft unter "Mehr > Über die Energiestudie", nicht auf der Erfassen-Seite.
- Die Status-Pille bleibt, weil Bewohnende sehen sollen, dass ihr Monitor läuft, und uns melden können, wenn nicht.
- Ausgeblendet: Übersicht, Auswertung, Messwerte, Download, Hinweise mit Zahlen.

Regeln für den Studienmodus:

1. Das Flag gilt pro Monitor, nicht pro Person. Wer zwei Monitore sieht, sieht beim Studienmonitor die reduzierte App, beim anderen die volle.
2. Admins (Team Energiemonitor, neues Feld `role: admin` im User) sehen auch Studienmonitore vollständig, mit einem gelben Band "Studienmodus aktiv, Bewohnende sehen nur Erfassen".
3. Der Studienmodus wird in der Firebase Console gesetzt, nicht in der App. Bewohnende können ihn nicht abschalten.
4. Das ist ein Schutz gegen ungewollte Beeinflussung, keine Zugriffssperre. Technisch versierte Teilnehmende könnten Firestore direkt lesen. Wenn das ein Problem für die Studie wird: Telemetrie-Leserechte in den Firestore-Rules an `study_mode == false` knüpfen **(offen, mit HSLU klären)**.
5. Ausnahme Systemstatus: Er zeigt nur "online, letzte Daten 14:00", nie einen Wert.

## 5. Screens im Detail

### 5.1 Übersicht

Von oben nach unten:

1. **Satz der Woche.** "Diese Woche habt ihr 38 kWh gebraucht, 71 % davon von der Sonne." Darunter klein: "Montag bis heute 14:00 · 2 Personen".
2. **Drei Kacheln** (`KpiTile`): Verbrauch kWh pro Person und Tag · Eigenversorgung Strom in % · Wohnklima innen Ø °C mit Komfort-Status.
3. **Tagesbalken der Woche** (gestapelt nach Energieträger, `data-solar`, `data-netz`, `data-gas`, `data-holz`). Pellets und Holz pro Abend aus der Ofensignatur (Temperaturkurve), Gas auf bewohnte Tage verteilt, beides gestrichelt als Schätzung. Ohne Klimasensor erscheinen Brennstoffe nur als Wochensumme neben dem Diagramm (Methode in `05_Datenherkunft_und_Infotexte.md`, Abschnitt 2).
4. **Hinweise**, höchstens zwei, nur wenn etwas zu tun ist:
   - "Seit 64 Tagen kein Eintrag für Propangas. Flasche gewechselt?" → Erfassen
   - "Aussensensor meldet 41 °C. Steht er in der Sonne?" (Plausibilitätscheck aus dem Langzeittest)
   - "Heute Nacht CO2 bis 2'100 ppm. Lüften lohnt sich." (nur wenn K4 vorhanden)
5. Link "Zur Auswertung".

**Umsetzung (Etappe 3, 23.11.2026):** Der Satz rechnet mit der Endenergie (Netz, selbst genutzter Solarstrom, Brennstoffe mit Heizwert) von Montag bis zum letzten Messwert. Die Kacheln zeigen den Verlauf der letzten sieben Tage. Ohne Klimasensor fällt die Klima-Kachel weg. Brennstoffe, die ohne Klimasensor nur gleichmässig verteilt sind, stehen als Wochensumme unter den Balken. Hinweise: Vorrat seit über 60 Tagen ohne Eintrag (Schwelle prüfen), Aussensensor über 40 °C, CO2 letzte Nacht über 2'000 ppm. Ohne Tageswerte steht eine ruhige Karte.

### 5.2 Auswertung

Zeitraum-Umschalter oben (Komponente `RangeSwitch`): **Woche · Monat · Saison bis jetzt · Jahr**. Mit Pfeilen links und rechts blättert man zur vorherigen Woche, zum vorherigen Monat usw.

| Stufe | Zeitraum | Hinweis |
|---|---|---|
| Woche | Montag bis jetzt, zurückblättern in ganzen Wochen | Brennstoffe meist noch im laufenden Zeitraum, also geschätzt |
| Monat | 1. des Monats bis jetzt | |
| Saison bis jetzt | Heizsaison 1. Oktober bis jetzt, im Sommer Sommersaison 1. April bis jetzt | Grenzen wie im Langzeittest (April bis September) **(prüfen mit HSLU)** |
| Jahr | letzte 12 Monate gleitend | Standard, sobald 12 Monate Daten vorliegen, vorher "Saison bis jetzt" |

Nicht jede Kennzahl passt zu jeder Stufe. Watt pro Person zeigt bei Woche und Monat den Hinweis "Kurze Zeiträume schwanken stark, vergleichbar mit dem Label ist nur das Jahr". Bewohnte Tage und Heatmap brauchen mindestens eine Woche.

Abschnitte in dieser Reihenfolge:

1. **Wie viel pro Person?** `PerPersonBenchmark`: eigener Wert in `gruen`, darunter neutral Label (berechnet), 2000-Watt-Ziel 420 W, Schweiz heute 1'300 W. Unterzeile: "Primärenergie Wohnen, ohne eigenen Solarstrom (Minergie-Systemgrenze)". Ein Schalter "mit Solarstrom" zeigt den Wert mit Solarstrom zum Vergleich.
2. **Woher kommt die Energie?** `EnergyMixDonut` mit Direktbeschriftung: Sonne, Netz, Gas, Holz/Pellets. Daneben `AutarkyRing` Eigenversorgung Strom.
3. **Monat für Monat.** `MonthlyBars` gestapelt nach Energieträger, Linie Verbrauch.
4. **Heizen.** Heizenergie pro Monat (I2 und M2), Anteil Solarstrom an der Heizenergie.
5. **Wohnklima.** `ClimateTile` für Temperatur, Feuchte, CO2 (Median an bewohnten Tagen), `ComfortZone` Anteil der Zeit im Bereich 20 bis 26 °C (Entscheid 23.11.2026, gilt auch für die Kachel), Stunden über 28 °C, heisseste Woche.
6. **Belegung.** Titel "Wann wart ihr zu Hause?", direkt in der Unterzeile: "Berechnet aus den CO2-Werten, nicht gemessen". Bewohnte Tage, `Co2Heatmap` Wochentag × Stunde.
7. Fusszeile "So rechnen wir": Faktoren und Systemgrenze, verlinkt auf eine kurze Methoden-Seite in "Mehr > Über die App".

**Umsetzung (Etappe 3, 23.11.2026):**

- Standard ist "Jahr", wenn Daten ab der ersten Woche des Jahreszeitraums und an mindestens 300 Tagen da sind, sonst "Saison". Das Jahr sind 12 ganze Monate bis und mit dem laufenden.
- **Watt pro Person zweimal** (Entscheid 23.11.2026): oben nach Minergie gegen den Label-Wert aus "Haushalt", darunter nach 2000 Watt (Primärenergie KBOB, ohne eigenen Solarstrom) gegen 2000-Watt-Ziel und Schweiz heute. Beide Blöcke auf derselben Skala. Der Schalter "mit Solarstrom" lässt bei Minergie die Gutschrift weg. Tage ohne Personen im Haushalt zählen nicht mit, ein Hinweis nennt sie.
- Bei Woche und Monat zeigt Abschnitt 3 Tagesbalken statt Monatsbalken. Abschnitt 4 erscheint nur mit Heizstrom (I2) oder Brennstoff fürs Heizen (M2).
- Ohne Klimasensor fallen Wohnklima und Belegung weg, an ihrer Stelle steht ein Hinweis mit Link aufs Mess-Schema.
- Die CO2-Heatmap erscheint ab 28 Tagen mit CO2-Werten. Sie zeigt nur den Wert, keinen abgeleiteten Zustand, weil die Schwelle der Netatmo vom Tag abhängt.

### 5.3 Erfassen

Details in `03_Formular_Spezifikation.md`. Aufbau der Seite:

1. **Vorrat-Karten** pro Energieträger, der schon einmal erfasst wurde: "Propangas · 12 kg Rest · letzter Eintrag 19.7.2026". Antippen oder "Nachfüllen" öffnet das Formular vorausgefüllt mit diesem Träger, "Abgleichen" öffnet es als Abgleich ohne Kauf ("Neu dazu" 0, aktueller Rest).
2. Knopf **"Energieträger erfassen"** (Pille, `gruen`).
3. **Liste der Einträge**, neueste zuerst, wie heute mit Löschen (Bestätigungsdialog bleibt). Der jüngste Eintrag jedes Vorrats lässt sich ändern (siehe `03_formular.md`, Abschnitt 4). Vorrat-Karten und Einträge zeigen den Messpunkt als farbiges Tag.

Wer nur Leserechte hat (`monitor_read` ohne `monitor_edit`), sieht Vorrat und Liste, aber keinen Knopf. Text wie heute: "Du kannst bei diesem Monitor keine Daten hinzufügen."

Die Seite ist im Studienmodus und im normalen Modus identisch. Vorrat, "verbraucht" und Erinnerungen stammen nur aus den eigenen Einträgen und zeigen keinen gemessenen Verbrauch, deshalb dürfen sie auch während der Studie sichtbar sein (Herkunft siehe `05_Datenherkunft_und_Infotexte.md`, 3.4).

### 5.4 Mehr

Liste mit Gruppen:

- **Dieses Haus:** Monitor wechseln (nur bei mehreren) · Haushalt (Personen, Wohnfläche, Label-Wert, je mit "gültig ab") · Systemstatus
- **Daten:** Messwerte · Daten herunterladen
- **Konto:** Name ändern (heute die Begrüssungskarte auf Home) · Abmelden
- **Über die App:** So rechnen wir · Impressum · Version

### 5.5 Systemstatus

- Oben der Gesamtstatus als Satz: "Alles läuft. Letzte Daten 14:00, nächste gegen 15:00."
- Liste der automatischen Messpunkte mit Klartext, Kürzel und Ampel mit Wort: ● online / ● verzögert / ● offline.
- Schwellen: online, wenn die letzten Daten jünger als 90 min sind (Upload stündlich plus Reserve), verzögert bis 6 h, danach offline.
- Manuelle Messpunkte (M0 bis M2) haben keine Ampel, sondern "letzter Eintrag".
- Darunter der Einstieg **Mess-Schema** (5.5a).
- Unten: "Fehlt etwas? Schreib uns: energiemonitor@kleinwohnformen.ch"

### 5.5a Mess-Schema

Eigener Bildschirm unter "Mehr > Systemstatus > Mess-Schema" (`/mehr/mess-schema`), umgesetzt 23.11.2026. Er zeigt, welche Messpunkte das Haus nach dem Messkonzept v1.0 (Minergie-Modul Monitoring) hat, ob Daten ankommen und was noch fehlt. Keine Messwerte, darum auch im Studienmodus sichtbar.

- **Gruppen** wie auf der Folie "Was gemessen wird": Energie über die Systemgrenze (E1, E2, E3, M1, M2, M0 nur mit Einträgen), im Haus mit gestrichelter Systemgrenze: Verbraucher (I1, I2, I3, A1), Wohnkomfort am Lieblingsort (K1 bis K4), Wasser (D1). Unbekannte Messpunkte unter "Weitere".
- **Kachel pro Messpunkt** in der Farbe des Messkonzepts mit Kürzel, Name und Zustand als Punkt und Wort: online, verzögert, offline (Schwellen wie 5.5), "keine Daten seit …" (über 30 Tage), "Einträge · letzter …" (M0 bis M2), "nicht gemessen" (weiss, gestrichelt). K1 bis K4 zählen auch, wenn sie als Feld unter K0 ankommen ("über K0").
- **Prüfung mit Warnung**, abgeleitet aus den Daten, ohne Angabe pro Haus: Heizwärme mit I2 oder Einträgen für Heizen (M2), Warmwasser mit I1 oder Einträgen für Warmwasser (M1), nur gemischte Einträge (M0) zählen als teilweise; Wohnklima braucht K1 bis K4. Ein Hinweis sagt, dass eine zweite, nicht angeschlossene Quelle nicht erkannt wird.

### 5.6 Messwerte (einfachere Rohdaten)

Statt Messpunkt → Sensor → Feld → Laden:

1. Liste aller Messpunkte mit Klartext, letztem Wert und einer Mini-Kurve der letzten 48 h.
2. Antippen öffnet **ein Diagramm** mit einem sinnvollen Standardwert pro Sensor (Shelly: Leistung `act_power`, Victron: `power`, Netatmo: Temperatur, Sensirion CO2: `co2`).
3. Zeitraum 24 h · 7 Tage · 30 Tage, lädt automatisch. Für 30 Tage werden Stundenmittel aus der Aggregation geladen statt Rohpunkte.
4. "Weitere Werte" klappt die technischen Felder auf (Spannung, Leistungsfaktor, Batterie, Funksignal), mit Feldnamen klein darunter für uns.

### 5.7 Daten herunterladen

- Zeitraum mit Voreinstellungen: Letzter Monat · Kalendermonat wählen · Eigener Zeitraum.
- Längere Zeiträume als 31 Tage teilt die App selbst in Monatsdateien und lädt sie nacheinander (das API-Limit bleibt).
- Hinweis klein: "Die Datei schneidet nach UTC-Tagen. Ein Tag beginnt in der Schweiz um 01:00 oder 02:00."
- Format heute XLSX, später CSV (siehe `04_Umsetzung.md`).

## 6. Wichtige Abläufe

**Gasflasche gewechselt (häufigster Fall):** Erfassen → Karte "Propangas" antippen → Formular mit Propangas, Messpunkt und Einheit vom letzten Mal → Menge 11.5, Rest 0.5, Kaufdatum heute vorgeschlagen → geschätztes Ende vorgeschlagen aus dem bisherigen Verbrauch → Speichern. Vier Eingaben statt neun.

**Erster Start mit neuem Monitor:** Login → wenn noch keine Personenzahl hinterlegt ist, ein kurzer Einstieg mit zwei Fragen (Wie viele Personen wohnen hier? Wie gross ist die Wohnfläche?) → Übersicht. Im Studienmodus dieselben Fragen, dann Erfassen.

**Etwas stimmt nicht:** Status-Pille gelb → Systemstatus → betroffener Messpunkt "verzögert seit 3 h" → Mail an das Team.

## 7. Gestaltung

Nach Design System "Verein Kleinwohnformen", Abschnitt Energiemonitor-App:

- Weiss als Grund, Karten eckig mit `shadow-card`, Inter 300 für Text, 600 für Titel.
- Einziges Grün als Fläche ist der aktive Tab-Indikator, der Haupt-Knopf und die Dachkante im Kopf der Übersicht.
- Energieträger-Farben fest: Sonne `data-solar`, Netz `data-netz`, Gas `data-gas`, Batterie `data-batterie`, Holz/Pellets `data-holz`.
- Status nur mit Punkt und Wort (`komfort-gut`, `komfort-mittel`, `komfort-schlecht`).
- Keine Emojis (auch die Begrüssung mit Winkehand fällt weg).
- Du-Form, Schweizer Rechtschreibung.
