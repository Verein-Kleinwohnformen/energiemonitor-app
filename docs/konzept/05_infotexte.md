# Datenherkunft und Infotexte

Stand: 21.11.2026

Die Texte stehen im Code in `lib/info/info_texts.dart`. Diese Seite ist die Startfassung; bei Abweichungen gilt der Code.

## 4. Das Info-Feld bei jeder Anzeige

Jede Kachel, jedes Diagramm und jede Kennzahl bekommt oben rechts ein kleines Info-Symbol (ⓘ als Linien-Icon, Trefferfläche 44 px, `aria-label="So entsteht diese Zahl"`). Antippen öffnet ein Overlay von unten (Bottom Sheet) mit immer denselben fünf Teilen:

1. **Was du siehst** – ein Satz.
2. **Woher die Daten kommen** – Sensor und Messpunkt in Klartext, Kürzel klein.
3. **Wie wir rechnen** – ein bis drei Sätze, Faktoren mit Quelle.
4. **Wie sicher das ist** – eines von: gemessen · berechnet aus Messwerten · geschätzt aus deinen Einträgen · Vergleichswert. Mit Grund.
5. **Stand** – "Daten bis 14:00" und der Zeitraum.

Die Texte stehen nicht im Code verstreut, sondern in einer Datei `lib/info_texts.dart` (oder in `/config/info_texts`), damit sie gepflegt werden können. Platzhalter in geschweiften Klammern füllt die App ein.

### Infotexte

**Status-Pille / Systemstatus**
- Was: Ob dein Monitor Daten schickt.
- Woher: Zeitpunkt der letzten Werte pro Messpunkt.
- Rechnung: Der Monitor sammelt Messwerte und schickt sie einmal pro Stunde. Online heisst: letzte Daten jünger als 90 Minuten. Verzögert: bis 6 Stunden. Danach offline.
- Sicherheit: gemessen.
- Stand: letzte Daten {zeit}.

**Verbrauch pro Person (kWh pro Tag)**
- Was: Wie viel Energie ihr pro Person und Tag gebraucht habt.
- Woher: Strom vom Victron und Shelly ({messpunkte}), Pellets, Holz und Gas aus deinen Einträgen, Personen aus "Haushalt".
- Rechnung: Strom aus der gemessenen Leistung aufsummiert. Brennstoffe mit Heizwert umgerechnet (Pellets 4.8 kWh/kg, Propan 12.8 kWh/kg) und auf die Tage verteilt. Geteilt durch {personen} Personen.
- Sicherheit: Strom gemessen, Brennstoffe geschätzt.

**Eigenversorgung Strom**
- Was: Welcher Teil eures Stroms nicht aus dem Netz kam.
- Woher: Netzbezug E1, Solarstrom E3 und Einspeisung E2 vom Victron.
- Rechnung: Selbst genutzter Solarstrom (E3 minus Einspeisung E2) geteilt durch selbst genutzten Solarstrom plus Netzbezug. Batterieverluste zählen mit. Eigenverbrauch: selbst genutzter Teil des Solarstroms. (Geändert 23.11.2026: Rechnung über den Bezug, weil der Victron bei voller Batterie mehr aus dem Netz holen kann, als die Verbraucher brauchen. Prüfen mit HSLU.)
- Sicherheit: berechnet aus Messwerten.

**Wohnklima**
- Was: Temperatur, Feuchte und CO2 an eurem Lieblingsort.
- Woher: Netatmo-Station innen (für die Studie gültiger Sensor).
- Rechnung: Median an bewohnten Tagen. Bereich = 5. bis 95. Perzentil der Stundenwerte. Behaglich: 20 bis 26 °C (Entscheid 23.11.2026), 30 bis 60 % Feuchte, CO2 unter 1'000 ppm.
- Sicherheit: gemessen, alle 10 Minuten.

**Wofür ging die Energie drauf? (Tagesbalken)**
- Was: Energie pro Tag nach Energieträger.
- Woher: Sonne E3 und Netz E1 vom Victron, Pellets und Gas aus deinen Einträgen.
- Rechnung: Sonne und Netz gemessen. Pellets verteilen wir auf die Abende, an denen die Innentemperatur schnell stieg und keine elektrische Heizung lief (Ofensignatur). Gas verteilen wir gleichmässig auf die Tage, an denen jemand zu Hause war.
- Sicherheit: Strom gemessen, Pellets und Gas geschätzt (hellere Fläche mit Rand). Die Schätzung wird genauer, sobald du den nächsten Eintrag machst.

**Pellets / Holz, geschätzt**
- Was: Wann ihr wie viel verbrannt habt.
- Woher: Deine Einträge (Kauf und Rest) und die Innentemperatur der Netatmo.
- Rechnung: Zwischen zwei Einträgen kennen wir die verbrannte Menge. Wir verteilen sie auf die Feuer, die wir am Temperaturverlauf erkennen: Die Temperatur steigt um mehr als 3 °C pro Stunde, ohne dass die Bodenheizung läuft. Längere Feuer bekommen mehr. Seit deinem letzten Eintrag rechnen wir mit {kg_pro_feuer} kg pro Feuer.
- Sicherheit: geschätzt. {anzahl_feuer} Feuer erkannt.

**Gas, geschätzt**
- Was: Wie viel Propan ihr gebraucht habt.
- Woher: Deine Einträge (Kauf und Rest), bewohnte Tage aus dem CO2.
- Rechnung: Die Menge zwischen zwei Einträgen verteilen wir gleichmässig auf die bewohnten Tage. Ohne Wägen der alten Flasche ist der Rest oft eine Schätzung, das macht auch diese Zahl unsicher.
- Sicherheit: geschätzt.

**Watt pro Person**
- Was: Eure Energie als Dauerleistung pro Person, zweimal gerechnet: nach Minergie (vergleichbar mit dem Energielabel) und nach der 2000-Watt-Methodik (vergleichbar mit dem 2000-Watt-Ziel und der Schweiz heute).
- Woher: Strom vom Victron (Netz E1, Sonne E3, Einspeisung E2), Brennstoffe aus deinen Einträgen, Personen aus "Haushalt".
- Rechnung: Minergie: Strom und Brennstoffe mal Gewichtungsfaktor ({gewichtung}), selbst genutzter Solarstrom ganz und eingespeister zu {einspeisung} gutgeschrieben. 2000 Watt: Netzstrom und Brennstoffe mal Primärenergiefaktor nach KBOB ({faktoren}), eigener Solarstrom zählt nicht. Beides geteilt durch die Stunden im Zeitraum und die Personen.
- Sicherheit: berechnet, Brennstoffe geschätzt. Die beiden Methoden ergeben verschiedene Zahlen, darum steht jeder Wert neben den Vergleichswerten seiner Methode.

**Energiequellen-Mix**
- Was: Woher die verbrauchte Energie kam.
- Woher: Sonne E3 (ohne Einspeisung E2), Netz E1, Brennstoffe aus deinen Einträgen.
- Rechnung: Anteile an der Endenergie in kWh. {nicht_berechenbar} ist nicht enthalten, weil es dafür erst einen Eintrag gibt. Für einen Verbrauch braucht es zwei.
- Sicherheit: Strom gemessen, Brennstoffe geschätzt.

**Heizen**
- Was: Wie viel Energie ins Heizen ging und wie viel davon Solarstrom war.
- Woher: Bodenheizung I2 (Shelly), Pellets aus deinen Einträgen.
- Rechnung: I2 gemessen, Pellets über die Ofensignatur verteilt. Solaranteil = Strom der Bodenheizung mal Eigenversorgung des jeweiligen Tages.
- Sicherheit: Strom gemessen, Pellets geschätzt.

**Zeit über 28 °C / heisseste Woche**
- Was: Wie oft es im Haus heiss war.
- Woher: Netatmo innen.
- Rechnung: Anteil der bewohnten Stunden über 28 °C. Heisseste Woche: höchstes Tagesmittel zwischen 8 und 20 Uhr über 7 Tage.
- Sicherheit: gemessen.

**Wann wart ihr zu Hause?**
- Was: An wie vielen Tagen jemand im Haus war.
- Woher: **Diese Zahl ist nicht gemessen, sondern aus den CO2-Werten berechnet** (Sensirion SCD4x, sonst Netatmo).
- Rechnung: Ein Tag gilt als bewohnt, wenn das CO2 irgendwann über 600 ppm steigt. Ein leeres Haus bleibt unter etwa 550 ppm. Wir nehmen den Höchstwert und nicht den Mittelwert, weil im Sommer bei offenen Fenstern der Mittelwert tief bleibt, auch wenn jemand da ist. Bei der Netatmo zählt der Anstieg: Der Höchstwert muss mehr als 150 ppm über dem 10. Perzentil des Tages liegen, weil ihr Nullpunkt wandert (leeres Haus 600 bis 800 ppm).
- Sicherheit: berechnet. Kurze Besuche oder offene Fenster den ganzen Tag können falsch erkannt werden. Gegenprobe mit dem Stromverbrauch der Kleinverbraucher.

**CO2 über den Tag (Heatmap)**
- Was: Zu welchen Stunden die Luft verbraucht ist.
- Woher: CO2 der Netatmo.
- Rechnung: Median pro Wochentag und Stunde.
- Sicherheit: gemessen.

**Messwerte**
- Was: Die Rohwerte deiner Sensoren.
- Woher: {sensor}, Messpunkt {mp}, Feld `{feld}`.
- Rechnung: 24 h zeigt jeden Wert, 7 und 30 Tage zeigen Stundenmittel.
- Sicherheit: gemessen.

**Mess-Schema**
- Was: Welche Messpunkte dein Haus nach dem Messkonzept hat und ob Daten ankommen.
- Woher: Liste der Messpunkte deines Monitors und deine Einträge (Messkonzept v1.0 nach dem Minergie-Modul Monitoring).
- Rechnung: Ein Messpunkt zählt, wenn in den letzten 30 Tagen Daten kamen. Heizwärme ist abgedeckt mit der Heizung I2 oder mit Einträgen für Heizen (M2), Warmwasser mit I1 oder mit Einträgen für Warmwasser (M1). Fürs Wohnklima braucht es Innentemperatur, Aussentemperatur, Luftfeuchte und CO2.
- Sicherheit: gemessen. Ein Gerät, das nicht am Monitor angeschlossen ist, sieht die Prüfung nicht.

**Vorrat und "verbraucht"**
- Was: Was beim letzten Eintrag noch da war und wie viel seit dem Eintrag davor weg ist.
- Woher: Nur aus deinen Einträgen.
- Rechnung: Vorrat = neu dazu + Rest. Verbraucht = Vorrat des vorherigen Eintrags minus Rest des neuen. Abgleich: ein Eintrag mit neu dazu 0 und dem aktuellen Rest. So siehst du den Verbrauch, auch wenn du nicht nachfüllst.
- Sicherheit: so genau wie deine Angaben. Gas am besten wägen.


## 2. Pellets, Holz und Gas auf Tage verteilen

Das Formular liefert pro Eintrag nur Kaufmenge, Rest und Datum. Daraus ergibt sich der Verbrauch **zwischen zwei Einträgen** (`consumed_quantity`), nicht wann er stattfand. Für Tages- und Wochenwerte muss die App diesen Verbrauch zeitlich verteilen.

### 2.1 Pellets und Holz: über die Temperaturkurve (Ofensignatur)

Im Langzeittest liessen sich die Feuer gut am Verlauf der Innentemperatur erkennen. Das wird die Standardmethode.

**Erkennung eines Feuers** (aus `temperature_indoor` von `netatmo`, Auflösung ca. 10 min):

- Innentemperatur steigt über mindestens 30 min um mehr als 3 K pro Stunde (im Langzeittest 4 bis 8 K pro Stunde),
- gleichzeitig läuft keine elektrische Heizung (I2 unter 50 W),
- und kein starker Sonneneintrag (E3 unter 300 W oder nach Sonnenuntergang),
- Ereignisse mit weniger als 2 h Abstand zählen als ein Feuer.

Die Schwellen sind aus sechs Monaten Beispielhaus abgeleitet und **für den Winter noch nicht geprüft (prüfen mit Daten Nov. 2026 bis Feb. 2027)**. Die bekannte Schwäche: Brennt der Ofen den ganzen Tag, steigt die Temperatur nur am Anfang. Dann zählt das Feuer einmal, obwohl mehr verbrannt wurde. Deshalb wird nicht nur gezählt, sondern gewichtet (unten).

**Verteilung bei abgeschlossenem Zeitraum** (zwei Einträge vorhanden): Der Verbrauch zwischen den Einträgen wird auf die erkannten Feuer verteilt, gewichtet mit der Dauer, in der die Innentemperatur über dem Wert vor dem Feuer lag (Brenndauer als Näherung). Ein Ergebnis wie "Abend 14.5.: 1.6 kg" ist also berechnet, nicht gemessen.

**Laufender Zeitraum** (nach dem letzten Eintrag, Verbrauch noch unbekannt): Die App zählt die erkannten Feuer und schätzt die Menge mit dem Durchschnitt pro Feuer aus dem letzten abgeschlossenen Zeitraum. Diese Werte werden gestrichelt gezeigt und mit dem nächsten Eintrag ersetzt. Gibt es noch keinen abgeschlossenen Zeitraum, zeigt die App nur die Zahl der Feuer ("Pelletofen an 4 Abenden erkannt") und keine kWh.

**Fallbacks**, in dieser Reihenfolge, jeweils im Info-Overlay genannt:

1. Kein Netatmo, aber Sensirion-Temperatur vorhanden: gleiche Erkennung mit `sensirion_voc`, Hinweis "Sensor nicht am Lieblingsort, ungenauer".
2. Keine Innentemperatur, aber Aussentemperatur: proportional zu Heizgradtagen (20 °C minus Tagesmittel aussen, nur Tage unter 12 °C).
3. Gar keine Klimadaten (Beispielobjekt ohne Klimasensor heute): gleichmässig über die Tage zwischen den Einträgen. In Wochen- und Tagesansichten wird Holz dann nicht als Balken pro Tag gezeigt, sondern nur als Summe des Zeitraums mit dem Hinweis "Verteilung auf Tage nicht möglich".

Auf der Übersicht bedeutet das: "fast die Hälfte für den Pelletofen" darf nur stehen, wenn die Woche in einem abgeschlossenen Zeitraum liegt oder als Schätzung klar markiert ist.

### 2.2 Gas: über bewohnte Tage

Propan dient im Tiny House zum Kochen und für Warmwasser. Dafür gibt es keine Temperatursignatur. Der Verbrauch zwischen zwei Einträgen wird gleichmässig auf die **bewohnten Tage** verteilt (Belegung aus CO2, Abschnitt 3), ohne Belegungsdaten auf alle Tage. Die Auswertung Langzeittest zeigt, wie unsicher das ist: Das Vorratsdelta passt nicht zu der Schätzung der Bewohnenden fürs Warmwasser. Darum steht Gas überall als "geschätzt", bis Flaschen beim Wechsel gewogen werden.

### 2.3 Heizöl, Diesel, Benzin

Heizöl wie Pellets (Ofensignatur funktioniert bei einem Ölofen nur, wenn er den Raum direkt heizt, sonst Fallback Heizgradtage). Diesel und Benzin werden nicht auf Tage verteilt und in "Wohnen" nicht mitgerechnet, bis die Label-Gruppe entschieden hat.

