# Formular Energieträger, Spezifikation

Stand: 21.11.2026 · Quelle Ist-Stand: `energiemonitor-app/lib/energy_form.dart`, `lib/energy.dart`, `lib/energy_card.dart`

**Grundregel 1:** Das Formular und die ganze Seite Erfassen sehen im Studienmodus und im normalen Modus genau gleich aus. Kein Banner, keine abweichenden Texte, keine fehlenden oder zusätzlichen Elemente. Der Studienmodus blendet nur andere Tabs aus.

**Grundregel 2:** Fachlich bleibt alles 1:1. Gleiche Felder, gleiche Auswahlwerte, gleiche Pflichtfelder, gleiche Prüfungen, gleiche Berechnung von `consumed_quantity`, gleiches Dokument in Firestore, gleiche Nachführung des Vorgänger-Eintrags. Ändern darf sich nur, wie das Formular aussieht und was vorausgefüllt wird. Jede Vorbelegung bleibt sichtbar und änderbar, nichts wird still gesetzt.

## 1. Felder (unverändert)

| # | Feld heute | Typ | Werte | Pflicht | Prüfung heute |
|---|---|---|---|---|---|
| 1 | Energieträger | Auswahl mit Bild | Benzin, Diesel, Heizöl, Holzpellets, Propangas, Holz | ja | Auswahl nötig |
| 2 | Messpunkt | Dropdown | M0 Gemischt, M1 Warmwasser, M2 Heizwärme | ja | "Bitte einen Messpunkt wählen" |
| 3 | Beschreibung | Text | frei | ja | "Bitte eine Beschreibung eingeben" |
| 4 | Hinzugefügte Menge | Zahl | Dezimal | ja | "Bitte eine Zahl eingeben", "Bitte eine gültige Zahl eingeben" |
| 5 | Übrige Menge | Zahl | Dezimal | ja | wie 4 |
| 6 | Einheit | Dropdown, gilt für 4 und 5 | Benzin, Diesel, Heizöl: Liter · Pellets, Propan: Kg · Holz: Kg oder Ster | ja | nicht "--" |
| 7 | Kaufdatum ("Wann hast du diese Menge hinzugefügt?") | Datum | 2000 bis 2100 | ja | gültiges Datum |
| 8 | Verbrauchsdatum ("Bis wann schätzt du, ist diese Menge aufgebraucht?") | Datum | 2000 bis 2100 | ja | nicht vor dem Kaufdatum |

Holz in Ster wird als `woodSter`, Holz in Kg als `woodKg` gespeichert (`_manageUnits`).

## 2. Gespeichertes Dokument (unverändert)

Pfad `/devices/{monitorId}/manual/{Jahr des Kaufdatums}/data/{id}`:

```json
{
  "sensor_id": "app_form",
  "device_id": "<monitorId>",
  "metering_point": "M0 | M1 | M2",
  "date": "YYYY-MM-DD",
  "day": 19, "year": 2026,
  "start_timestamp": <Kaufdatum ms>, "end_timestamp": <Kaufdatum ms>,
  "data_points": [{ "timestamp": <Kaufdatum ms>, "values": {
      "added_quantity": 11.5, "leftover_quantity": 12,
      "consumed_quantity": <berechnet>, "unit": "kg" } }],
  "count": 1,
  "created_at": "<ISO UTC>",
  "metadata": { "description": "...", "purchase_date": <ms>, "estimated_usage_date": <ms>,
                "usage_date_provisory": true, "user_id": "...", "energy_type": "propane" }
}
```

Dazu wie heute: `metering_points/{mp}` mit `last_seen` und `sensor_types: app_form` nachführen, beim letzten provisorischen Vorgänger mit gleichem Messpunkt und Energieträger `estimated_usage_date` auf das neue Kaufdatum setzen und `usage_date_provisory` auf `false`.

`consumed_quantity` = (hinzugefügt + Rest des letzten Eintrags davor, gleicher Messpunkt und Energieträger, gesucht im aktuellen und im Vorjahr) − Rest des neuen Eintrags, nicht kleiner als 0.

## 3. Was sich in der Bedienung ändert

| Heute | Neu | Warum |
|---|---|---|
| Sechs kleine Bildkacheln in einer Zeile, Text grau | Raster 3 × 2 mit grösseren Kacheln (mind. 48 px Trefferfläche), Name darunter in `anthrazit`, gewählte Kachel mit grünem Rand und Häkchen | Lesbarkeit am Handy, Status nicht nur über Farbe |
| Einheit als Dropdown neben jeder Menge, obwohl sie für beide gilt | Einheit einmal direkt unter dem Energieträger. Bei nur einer möglichen Einheit als Text ("in kg"), bei Holz als Umschalter kg / Ster | Ein Feld weniger, kein Widerspruch zwischen zwei Dropdowns |
| Messpunkt-Dropdown mit Kürzeln | Drei Auswahlknöpfe "Warmwasser", "Heizen", "Beides gemischt", Kürzel M1, M2, M0 klein darunter | Bewohnende denken in Nutzung, nicht in Kürzeln. Gespeichert wird das gleiche Kürzel. |
| Leeres Formular | Vorbelegung aus dem letzten Eintrag gleichen Typs: Messpunkt, Einheit, Beschreibung. Kaufdatum = heute. | Häufigster Fall ist "gleich wie letztes Mal" |
| Verbrauchsdatum leer | Vorschlag aus dem bisherigen Verbrauch ("bei deinem bisherigen Verbrauch etwa bis 14.3.2027"), sonst leer | Die Schätzung ist für Bewohnende schwer, der Vorschlag hilft und bleibt änderbar |
| "Übrige Menge" ohne Kontext | Hilfetext: "Was ist noch da, bevor du die neue Menge dazu tust? Bei Gas: Flasche wägen und Tara abziehen." | Die Auswertung Langzeittest zeigt: ohne sauberen Rest kein Verbrauch |
| Reihenfolge Menge, Rest, Kaufdatum, Ende | Gruppiert in drei Schritte auf einer Seite: **Was?** (Träger, Einheit, Messpunkt) · **Wie viel?** (hinzugefügt, Rest) · **Wann?** (Kaufdatum, Ende), Beschreibung am Schluss | Logischer Ablauf, gleiche Felder |
| Fehlermeldungen erst nach "Hinzufügen" | Gleiche Meldungen, zusätzlich direkt beim Verlassen eines Feldes | |
| Knopf "Hinzufügen" unten rechts | Knopf "Eintrag speichern" breit unten, fest im Bild | Erreichbar mit dem Daumen |
| Snackbar "Eintrag hinzugefügt!" | Bestätigung mit Zusammenfassung: "Propangas, 11.5 kg, Rest 0.5 kg. Seit dem letzten Eintrag verbraucht: 11.5 kg." | Rückmeldung, dass der Verbrauch berechnet wurde |
| Kein eigener Weg, den Vorrat ohne Kauf nachzuführen | Link **"Abgleichen"** auf jeder Vorrat-Karte (neben "Nachfüllen"). Er öffnet dasselbe Formular als "Vorrat abgleichen": Träger, Einheit und Messpunkt vom Vorrat, "Neu dazu" 0 und Beschreibung "Abgleich" sichtbar vorbelegt und änderbar, "Noch übrig" leer. Gespeichert wird ein normaler Eintrag ("Nullkauf"). Liegt das Datum nicht nach dem letzten Eintrag, erscheint ein Hinweis (siehe 5). | Bewohnende halten den Vorrat aktuell, ohne nachzufüllen; so ist der Verbrauch seit dem letzten Eintrag bekannt und die Tageswerte werden genauer (umgesetzt 23.11.2026) |

Ausdrücklich nicht geändert: keine neuen Pflichtfelder, keine neuen Energieträger, keine neuen Messpunkte, kein anderes Datenformat. Vorschläge dafür stehen unten und sind ein separater Entscheid.

## 4. Liste der Einträge

- Wie heute: neueste zuerst, Löschen mit Bestätigungsdialog ("Eintrag löschen", "Abbrechen", "Löschen").
- **Ändern** (umgesetzt 23.11.2026): Stift-Symbol beim jüngsten Eintrag jedes Vorrats (Träger und Messpunkt). Es öffnet dasselbe Formular als "Eintrag ändern", alle Felder mit den gespeicherten Werten. Beim Speichern wird der alte Eintrag gelöscht und der neue über `Energy.addToFirebase()` gespeichert, also mit derselben Berechnung von `consumed_quantity` und derselben Nachführung des Vorgängers wie ein neuer Eintrag. Der Integrationstest "Aendern ergibt dasselbe wie direkt erfassen" prüft, dass das Ergebnis genau einem direkt erfassten Eintrag entspricht. Ältere Einträge lassen sich nicht ändern, weil der Verbrauch ihres Nachfolgers sonst auf alten Zahlen stünde; sie lassen sich wie bisher löschen. Klappt das Speichern nicht, wird der alte Eintrag wieder angelegt.
- **Messpunkt als Tag** (umgesetzt 23.11.2026): Vorrat-Karten und Einträge zeigen den Messpunkt als farbiges Tag mit Symbol ("M1 Warmwasser" blau mit Tropfen, "M2 Heizwärme" orange mit Flamme, "M0 Gemischt" grau). So ist Gas für Warmwasser von Gas fürs Heizen auf einen Blick zu unterscheiden. Der Text bleibt anthrazit, die Farbe trägt nie allein.
- Neu oben die **Vorrat-Karten** pro Energieträger und Messpunkt: aktueller Rest (letzter `leftover_quantity` + `added_quantity`), Datum des letzten Eintrags, Verbrauch seit dem Vorletzten. Antippen oder "Nachfüllen" öffnet das Formular vorausgefüllt, "Abgleichen" öffnet es als Abgleich (siehe 3).
- Neu ein **Hinweis**, wenn ein Eintrag länger her ist als der bisherige Abstand zwischen zwei Einträgen dieses Trägers.
- Vorrat-Karten, Liste und Hinweis sind in beiden Modi gleich. Sie stammen nur aus den eigenen Einträgen und zeigen keinen gemessenen Verbrauch.
- Jede Vorrat-Karte und der Wert "verbraucht" haben das Info-Symbol mit dem Text "Vorrat und verbraucht" aus `05_Datenherkunft_und_Infotexte.md`, Abschnitt 4.

## 5. Bekannte Unschärfen im heutigen Formular (nicht Teil dieses Konzepts)

Festgehalten, damit sie nicht verloren gehen. Jede Änderung hier ändert die Studiendaten und braucht einen Entscheid mit der HSLU.

- **Messpunkt-Bedeutung:** In der App heissen M1 "Warmwasser" und M2 "Heizwärme" (Nutzung). Im Messkonzept v1.0 heissen M1 "Gas in Flaschen" und M2 "Brennholz oder Pellets" (Träger). Die App speichert den Energieträger zusätzlich in `energy_type`, die Information geht also nicht verloren, aber die Kürzel bedeuten in App und Messkonzept nicht dasselbe **(offen)**.
- **Flaschenwechsel ohne Kauf:** Die Auswertung Langzeittest empfiehlt, jeden Flaschenwechsel mit gewogenem Rest zu erfassen. Das geht heute schon (Menge = volle Flasche, Rest = gewogener Rest der alten), ist aber nicht so beschriftet. Seit dem 23.11.2026 gibt es dafür den Abgleich (Abschnitt 3).
- **Abgleich am selben Tag:** Das Kaufdatum ist ein Kalendertag um Mitternacht. `energy.dart` sucht den Vorgänger nur mit einem früheren Datum; ein Abgleich am selben Tag wie der letzte Eintrag ergibt darum "verbraucht" 0. Das Formular zeigt dann einen Hinweis, blockiert aber nicht (fachlich 1:1). Der Regressionstest dokumentiert den Fall.
- **Abgleich setzt das "aufgebraucht"-Datum des Vorgängers:** Wie bei jedem Eintrag setzt `energy.dart` beim Vorgänger `estimated_usage_date` auf das Datum des Abgleichs und `usage_date_provisory` auf false, obwohl der Vorrat nicht aufgebraucht ist. **(offen, mit der HSLU klären)** Die Tageswerte der API nutzen nur `consumed_quantity` und sind nicht betroffen.
- **Benzin und Diesel** gehören meist zur Mobilität. Ob sie in der Studie gezählt werden, ist offen.
- **ID-Erzeugung:** `_generateUuid` ist Zeitstempel plus Messpunkt plus Typ, keine echte UUID. Unkritisch, aber bei der Umsetzung durch das `uuid`-Paket ersetzen, ohne bestehende Dokumente zu ändern.
- **Suche nach dem Vorgänger** liest alle Einträge des Jahres. Bei vielen Einträgen langsam, fachlich korrekt.

## 6. Vorrat verwerfen und umbuchen (geplant)

**Problem:** Heute gibt es nur zwei Wege, den Vorrat zu senken: einen Eintrag mit kleinerem Rest oder Löschen. Beides passt nicht, wenn Brennstoff das System verlässt, ohne verbrannt zu werden (Gasflasche zurückgegeben oder verkauft, Holz verschenkt, Pellets nass geworden) oder wenn er neu für einen anderen Zweck eingesetzt wird (Gasflasche vom Warmwasser zum Kochen, weil das Warmwasser jetzt elektrisch erzeugt wird). Ein kleinerer Rest zählt die Menge als Verbrauch, und die Tageswerte zeigen dann einen Verbrauch, den es nie gab. Löschen verfälscht die Vorgeschichte.

**Bedienung:** Auf jeder Vorrat-Karte ein dritter Link **"Verwerfen"** (neben "Nachfüllen" und "Abgleichen"). Er öffnet das Formular als "Vorrat verwerfen":

| Feld | Inhalt |
|---|---|
| Was? | Träger, Einheit und Messpunkt vom Vorrat, nicht änderbar |
| Noch übrig vorher | Rest unmittelbar vor dem Verwerfen (gewogen, geschätzt). Pflicht, sonst ist der Verbrauch bis heute unbekannt. Vorbelegt mit dem Vorrat der Karte, Hinweis "Was ist noch da, bevor etwas weggeht?" |
| Verworfen | Menge, die das System verlässt. Knopf "Alles" setzt sie auf "Noch übrig vorher". Muss grösser als 0 und höchstens "Noch übrig vorher" sein |
| Grund | Auswahl "Zurückgegeben oder verkauft", "Weitergegeben", "Unbrauchbar", "Für anderen Zweck eingesetzt" |
| Neuer Zweck | Nur beim Grund "Für anderen Zweck eingesetzt": Messpunkt (Warmwasser, Heizen, Gemischt), ohne den bisherigen |
| Wann? | Datum, Standard heute |
| Beschreibung | Vorbelegt mit dem Grund, änderbar |

Bestätigung wie beim Speichern: "Propangas M1 Warmwasser: 8 kg verworfen, Rest 0 kg. Seit dem letzten Eintrag verbraucht: 2 kg."

**Gespeicherte Dokumente:** Das Formular bleibt fachlich 1:1, `lib/energy.dart` bleibt unverändert. Verwerfen speichert über einen eigenen Weg (neben `Energy.addToFirebase()`) ein Dokument im **gleichen Format** in `/devices/{id}/manual/{year}/data/{uuid}` mit:

- `added_quantity` 0, `leftover_quantity` = "Noch übrig vorher" minus "Verworfen";
- `consumed_quantity` = Vorrat des Vorgängers minus "Noch übrig vorher" (nicht minus Rest), mindestens 0, mit derselben Suche nach dem Vorgänger wie `energy.dart`;
- neu in `values`: `discarded_quantity`;
- neu in `metadata`: `entry_kind: "discard"`, `discard_reason`, beim Umbuchen `transferred_to` (Messpunkt);
- Nachführung des Vorgängers (`estimated_usage_date`, `usage_date_provisory`) wie bei jedem Eintrag.

Beim Grund "Für anderen Zweck eingesetzt" entsteht im selben Batch ein zweites Dokument beim neuen Messpunkt: ein normaler Eintrag mit `added_quantity` = verworfene Menge, `leftover_quantity` = bisheriger Rest dort (aus der Vorrat-Karte, 0 wenn es keinen gibt), `metadata.entry_kind: "transfer_in"` und `transferred_from`. So stimmen beide Vorräte, und die Vorgeschichte bleibt beim alten Zweck.

**Tageswerte (API):** Die Verteilung nutzt nur `consumed_quantity`, verworfene Mengen zählen also nie als Verbrauch. Zusätzlich nötig: Ist der Vorrat nach dem letzten Eintrag 0 (`added_quantity` + `leftover_quantity` = 0), gibt es keinen laufenden Zeitraum mehr; heute wird der Verbrauch nach dem letzten Eintrag mit dem Satz des letzten Zeitraums weitergeschätzt, auch wenn nichts mehr da ist.

**Anzeige:** Liste: Verwerfen-Einträge mit eigenem Symbol und Text "verworfen 8 kg (zurückgegeben)". Vorrat-Karte mit Rest 0 nach einem Verwerfen wird eingeklappt ("Vorrat aufgelöst am 14.11.2026"), "Nachfüllen" holt sie zurück. Der Export enthält `discarded_quantity` und `entry_kind` als eigene Spalten.

**Ändern und Löschen:** Ein Verwerfen-Eintrag ist der jüngste Eintrag seines Vorrats und lässt sich wie andere ändern (löschen und neu speichern). Beim Umbuchen werden beide Dokumente zusammen gelöscht oder geändert.

**Tests:** Unit-Test der Rechnung (Rest vorher, verworfen, Vorgänger, Vorrat 0); Integrationstest im Emulator: Verwerfen, Umbuchen, danach normaler Eintrag ergibt denselben Verbrauch wie ohne Verwerfen; Formular-Regressionstest unverändert grün; API-Test: kein laufender Zeitraum bei Vorrat 0.

**Offen:**

- Neue Felder (`discarded_quantity`, `entry_kind`) ändern das Studienformat. TODO(prüfen): mit der HSLU klären, ob das so in den Export und die Auswertung darf.
- TODO(prüfen): Soll "Noch übrig vorher" Pflicht sein, oder genügt beim Verwerfen von allem ein Häkchen "Verbrauch bis heute unbekannt"?
- TODO(prüfen): Umbuchen vergangener Zeiträume (alle Einträge eines Vorrats nachträglich einem anderen Zweck zuordnen) bleibt ein Admin-Schritt im Backend, kein App-Knopf.
