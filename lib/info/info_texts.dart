// Texte der Info-Overlays ("So entsteht diese Zahl").
//
// Startfassung aus dem Konzept, Datenherkunft und Infotexte, Abschnitt 4.
// Platzhalter in geschweiften Klammern fuellt die App mit [InfoText.fill].
// Spaeter koennen die Texte aus /config/info_texts kommen, damit sie sich
// ohne neuen Build anpassen lassen.

/// Wie sicher eine Zahl ist. Immer eines davon, mit Grund im Text.
enum Certainty {
  measured('gemessen'),
  calculated('berechnet aus Messwerten'),
  estimated('geschätzt aus deinen Einträgen'),
  reference('Vergleichswert');

  const Certainty(this.label);
  final String label;
}

class InfoText {
  const InfoText({
    required this.title,
    required this.what,
    required this.source,
    required this.method,
    required this.certainty,
    this.note,
  });

  /// Titel des Overlays, meist der Titel der Anzeige.
  final String title;

  /// 1. Was du siehst
  final String what;

  /// 2. Woher die Daten kommen
  final String source;

  /// 3. Wie wir rechnen
  final String method;

  /// 4. Wie sicher das ist
  final String certainty;

  /// Hinweis direkt unter dem Titel, z.B. "nicht gemessen, sondern berechnet".
  final String? note;

  /// Setzt Werte fuer Platzhalter wie {zeit} ein. Fehlende Werte bleiben
  /// sichtbar stehen, damit sie im Test auffallen.
  InfoText fill(Map<String, String> values) {
    String f(String s) => s.replaceAllMapped(
        RegExp(r'\{(\w+)\}'), (m) => values[m.group(1)] ?? m.group(0)!);
    return InfoText(
      title: f(title),
      what: f(what),
      source: f(source),
      method: f(method),
      certainty: f(certainty),
      note: note == null ? null : f(note!),
    );
  }

  /// Alle Platzhalter, die im Text vorkommen.
  Set<String> get placeholders {
    final all = [title, what, source, method, certainty, note ?? ''].join(' ');
    return RegExp(r'\{(\w+)\}').allMatches(all).map((m) => m.group(1)!).toSet();
  }
}

abstract final class InfoTexts {
  static const systemStatus = InfoText(
    title: 'Systemstatus',
    what: 'Ob dein Monitor Daten schickt.',
    source: 'Zeitpunkt der letzten Werte pro Messpunkt.',
    method: 'Der Monitor sammelt Messwerte und schickt sie einmal pro Stunde. '
        'Online heisst: letzte Daten jünger als 90 Minuten. Verzögert: bis 6 Stunden. '
        'Danach offline.',
    certainty: 'Gemessen.',
  );

  static const consumptionPerPerson = InfoText(
    title: 'Verbrauch pro Person',
    what: 'Wie viel Energie ihr pro Person und Tag gebraucht habt.',
    source: 'Strom vom Victron und Shelly ({messpunkte}), Pellets, Holz und Gas aus '
        'deinen Einträgen, Personen aus "Haushalt".',
    // Heizwerte kommen aus /config/factors, nicht aus dem Code.
    method: 'Strom aus der gemessenen Leistung aufsummiert. Brennstoffe mit Heizwert '
        'umgerechnet ({heizwerte}) und auf die Tage verteilt. Geteilt durch {personen} '
        'Personen.',
    certainty: 'Strom gemessen, Brennstoffe geschätzt.',
  );

  static const autarky = InfoText(
    title: 'Eigenversorgung Strom',
    what: 'Welcher Teil eures Stroms nicht aus dem Netz kam.',
    source: 'Netzbezug E1, Solarstrom E3 und Einspeisung E2 vom Victron.',
    // TODO(prüfen): Rechnung ueber den Bezug statt ueber den Verbrauch mit der HSLU.
    method: 'Selbst genutzter Solarstrom (E3 minus Einspeisung E2) geteilt durch selbst '
        'genutzten Solarstrom plus Netzbezug. Batterieverluste zählen mit. Eigenverbrauch: '
        'selbst genutzter Teil des Solarstroms.',
    certainty: 'Berechnet aus Messwerten.',
  );

  static const climate = InfoText(
    title: 'Wohnklima',
    what: 'Temperatur, Feuchte und CO2 an eurem Lieblingsort.',
    source: 'Netatmo-Station innen (für die Studie gültiger Sensor).',
    method: 'Median an bewohnten Tagen. Bereich = 5. bis 95. Perzentil der Stundenwerte. '
        'Behaglich: 20 bis 26 °C, 30 bis 60 % Feuchte, CO2 unter 1\'000 ppm.',
    certainty: 'Gemessen, alle 10 Minuten.',
  );

  static const dailyBars = InfoText(
    title: 'Wofür ging die Energie drauf?',
    what: 'Energie pro Tag nach Energieträger.',
    source: 'Sonne E3 und Netz E1 vom Victron, Pellets und Gas aus deinen Einträgen.',
    method: 'Sonne und Netz gemessen. Pellets verteilen wir auf die Abende, an denen die '
        'Innentemperatur schnell stieg und keine elektrische Heizung lief (Ofensignatur). '
        'Gas verteilen wir gleichmässig auf die Tage, an denen jemand zu Hause war.',
    certainty: 'Strom gemessen, Pellets und Gas geschätzt (hellere Fläche mit Rand). Die '
        'Schätzung wird genauer, sobald du den nächsten Eintrag machst.',
  );

  static const woodEstimated = InfoText(
    title: 'Pellets und Holz, geschätzt',
    what: 'Wann ihr wie viel verbrannt habt.',
    source: 'Deine Einträge (Kauf und Rest) und die Innentemperatur der Netatmo.',
    method: 'Aus Kauf und Rest kennen wir die verbrannte Menge. Weil der Rest geschätzt ist, '
        'zählen wir alle Einträge einer Saison zusammen und verteilen diese Menge auf die Feuer '
        'der ganzen Saison, die wir am Temperaturverlauf erkennen: Die Temperatur steigt um '
        'mehr als 3 °C pro Stunde, ohne dass die Bodenheizung läuft. Längere Feuer '
        'bekommen mehr. Seit deinem letzten Eintrag rechnen wir mit {kg_pro_feuer} kg '
        'pro Feuer.',
    certainty: 'Geschätzt. {anzahl_feuer} Feuer erkannt.',
  );

  static const gasEstimated = InfoText(
    title: 'Gas, geschätzt',
    what: 'Wie viel Propan ihr gebraucht habt.',
    source: 'Deine Einträge (Kauf und Rest), bewohnte Tage aus dem CO2.',
    method: 'Die Menge aller Einträge einer Saison verteilen wir gleichmässig auf die bewohnten '
        'Tage der Saison. Ohne Wägen der alten Flasche ist der Rest oft eine Schätzung, das macht '
        'auch diese Zahl unsicher.',
    certainty: 'Geschätzt.',
  );

  static const wattPerPerson = InfoText(
    title: 'Watt pro Person',
    what: 'Eure Energie als Dauerleistung pro Person, zweimal gerechnet: nach Minergie '
        '(vergleichbar mit dem Energielabel) und nach der 2000-Watt-Methodik (vergleichbar '
        'mit dem 2000-Watt-Ziel und der Schweiz heute).',
    source: 'Strom vom Victron (Netz E1, Sonne E3, Einspeisung E2), Brennstoffe aus deinen '
        'Einträgen, Personen aus "Haushalt".',
    method: 'Minergie: Strom und Brennstoffe mal Gewichtungsfaktor ({gewichtung}), selbst '
        'genutzter Solarstrom ganz und eingespeister zu {einspeisung} gutgeschrieben. '
        '2000 Watt: Netzstrom und Brennstoffe mal Primärenergiefaktor nach KBOB ({faktoren}), '
        'eigener Solarstrom zählt nicht. Beides geteilt durch die Stunden im Zeitraum und '
        'die Personen.',
    certainty: 'Berechnet, Brennstoffe geschätzt. Die beiden Methoden ergeben '
        'verschiedene Zahlen, darum steht jeder Wert neben den Vergleichswerten seiner '
        'Methode.',
  );

  static const energyMix = InfoText(
    title: 'Energiequellen-Mix',
    what: 'Woher die verbrauchte Energie kam.',
    source: 'Sonne E3 (ohne Einspeisung E2), Netz E1, Brennstoffe aus deinen Einträgen.',
    method: 'Anteile an der Endenergie in kWh. {nicht_berechenbar} ist nicht enthalten, '
        'weil es dafür erst einen Eintrag gibt. Für einen Verbrauch braucht es zwei.',
    certainty: 'Strom gemessen, Brennstoffe geschätzt.',
  );

  static const heating = InfoText(
    title: 'Heizen',
    what: 'Wie viel Energie ins Heizen ging und wie viel davon Solarstrom war.',
    source: 'Bodenheizung I2 (Shelly), Pellets aus deinen Einträgen.',
    method: 'I2 gemessen, Pellets über die Ofensignatur verteilt. Solaranteil = Strom der '
        'Bodenheizung mal Eigenversorgung des jeweiligen Tages.',
    certainty: 'Strom gemessen, Pellets geschätzt.',
  );

  static const heat = InfoText(
    title: 'Zeit über 28 °C',
    what: 'Wie oft es im Haus heiss war.',
    source: 'Netatmo innen.',
    method: 'Anteil der bewohnten Stunden über 28 °C. Heisseste Woche: höchstes '
        'Tagesmittel zwischen 8 und 20 Uhr über 7 Tage.',
    certainty: 'Gemessen.',
  );

  static const occupancy = InfoText(
    title: 'Wann wart ihr zu Hause?',
    note: 'Diese Zahl ist nicht gemessen, sondern aus den CO2-Werten berechnet.',
    what: 'An wie vielen Tagen jemand im Haus war.',
    source: 'CO2-Sensor innen (Sensirion SCD4x, sonst Netatmo), Messpunkt K0, Feld co2_indoor.',
    method: 'Ein Tag gilt als bewohnt, wenn das CO2 irgendwann über 600 ppm steigt. Ein '
        'leeres Haus bleibt unter etwa 550 ppm. Wir nehmen den Höchstwert und nicht den '
        'Mittelwert, weil im Sommer bei offenen Fenstern der Mittelwert tief bleibt, auch '
        'wenn jemand da ist. Bei der Netatmo zählt der Anstieg: Der Höchstwert muss mehr als '
        '150 ppm über dem üblichen Wert des Tages liegen, weil ihr Nullpunkt mit der Zeit wandert.',
    certainty: 'Berechnet. Kurze Besuche oder offene Fenster den ganzen Tag können falsch '
        'erkannt werden. Gegenprobe mit dem Stromverbrauch der Kleinverbraucher.',
  );

  static const co2Heatmap = InfoText(
    title: 'CO2 über den Tag',
    what: 'Zu welchen Stunden die Luft verbraucht ist.',
    source: 'CO2 der Netatmo.',
    method: 'Median pro Wochentag und Stunde.',
    certainty: 'Gemessen.',
  );

  static const measurements = InfoText(
    title: 'Messwerte',
    what: 'Die Rohwerte deiner Sensoren.',
    source: '{sensor}, Messpunkt {mp}, Feld {feld}.',
    method: '24 h und 7 Tage zeigen jeden gespeicherten Wert. Längere Zeiträume folgen '
        'mit den Stundenwerten.',
    certainty: 'Gemessen.',
  );

  static const stock = InfoText(
    title: 'Vorrat und verbraucht',
    what: 'Was beim letzten Eintrag noch da war und wie viel seit dem Eintrag davor weg ist.',
    source: 'Nur aus deinen Einträgen.',
    method: 'Vorrat = neu dazu + Rest. Verbraucht = Vorrat des vorherigen Eintrags minus '
        'Rest des neuen. Abgleich: ein Eintrag mit neu dazu 0 und dem aktuellen Rest. So '
        'siehst du den Verbrauch, auch wenn du nicht nachfüllst.',
    certainty: 'So genau wie deine Angaben. Gas am besten wägen.',
  );

  static const schema = InfoText(
    title: 'Mess-Schema',
    what: 'Welche Messpunkte dein Haus nach dem Messkonzept hat und ob Daten ankommen.',
    source: 'Liste der Messpunkte deines Monitors und deine Einträge (Messkonzept v1.0 '
        'nach dem Minergie-Modul Monitoring).',
    method: 'Ein Messpunkt zählt, wenn in den letzten 30 Tagen Daten kamen. Heizwärme ist '
        'abgedeckt mit der Heizung I2 oder mit Einträgen für Heizen (M2), Warmwasser mit I1 '
        'oder mit Einträgen für Warmwasser (M1). Fürs Wohnklima braucht es Innentemperatur, '
        'Aussentemperatur, Luftfeuchte und CO2.',
    certainty: 'Gemessen. Ein Gerät, das nicht am Monitor angeschlossen ist, sieht die '
        'Prüfung nicht.',
  );

  /// Alle Texte, fuer Tests und eine spaetere Pflege-Ansicht.
  static const all = <InfoText>[
    systemStatus,
    consumptionPerPerson,
    autarky,
    climate,
    dailyBars,
    woodEstimated,
    gasEstimated,
    wattPerPerson,
    energyMix,
    heating,
    heat,
    occupancy,
    co2Heatmap,
    measurements,
    stock,
    schema,
  ];
}
