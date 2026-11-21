import 'package:flutter/material.dart';

import '../overview/overview_page.dart';

/// Auswertung mit Zeitraum Woche, Monat, Saison bis jetzt und Jahr (Etappe 3).
class AnalysisPage extends StatelessWidget {
  const AnalysisPage({super.key});

  @override
  Widget build(BuildContext context) => const PlaceholderPage(
        title: 'Auswertung',
        text: 'Auswertungen folgen. Hier vergleichst du bald euren Verbrauch pro Person '
            'mit dem Energielabel und dem 2000-Watt-Ziel.',
      );
}
