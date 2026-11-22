import 'package:flutter/material.dart';

import '../theme/kwf_theme.dart';
import '../theme/kwf_widgets.dart';
import 'sub_page.dart';

/// "So rechnen wir": Systemgrenze und Herkunft der Faktoren. Die Faktoren
/// selbst kommen mit den Auswertungen aus /config/factors und stehen nicht im
/// Code.
class MethodPage extends StatelessWidget {
  const MethodPage({super.key});

  @override
  Widget build(BuildContext context) {
    Widget card(String title, String body) => KwfCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: KwfText.sectionTitle),
              const SizedBox(height: 6),
              Text(body, style: KwfText.body),
            ],
          ),
        );
    return SubPage(title: 'So rechnen wir', children: [
      card('Pro Person, nicht pro Fläche',
          'Die Kennzahl des Vereins ist Watt Dauerleistung pro Person. Sie lässt sich mit '
          'dem KWF-Energielabel und dem 2000-Watt-Ziel vergleichen.'),
      card('Systemgrenze',
          'Wie bei Minergie und beim KWF-Energielabel zählt eigener Solarstrom nicht. '
          'Netzstrom und Brennstoffe zählen mit ihrem Primärenergiefaktor.'),
      card('Gemessen, berechnet, geschätzt',
          'Strom messen Victron und Shelly direkt. Holz, Pellets und Gas kennen wir nur aus '
          'deinen Einträgen. Wann du sie verbraucht hast, schätzen wir: Pellets und Holz '
          'über den Temperaturverlauf, Gas über die bewohnten Tage. Jede Zahl in der App '
          'sagt im Info-Symbol, wie sie entstanden ist.'),
      card('Faktoren',
          'Heizwerte und Primärenergiefaktoren erscheinen hier, sobald die Auswertungen '
          'freigeschaltet sind, jeweils mit Quelle und Datum.'),
    ]);
  }
}
