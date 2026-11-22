import 'package:flutter/material.dart';

import '../theme/kwf_theme.dart';
import '../theme/kwf_widgets.dart';

/// Uebersicht. Die Auswertungen kommen, sobald die Tageswerte berechnet
/// werden (Etappe 3). Bis dann eine ruhige Huelle.
class OverviewPage extends StatelessWidget {
  const OverviewPage({super.key});

  @override
  Widget build(BuildContext context) => const PlaceholderPage(
        title: 'Übersicht',
        text: 'Auswertungen folgen. Hier siehst du bald, wie viel Energie ihr diese Woche '
            'gebraucht habt und woher sie kam.',
      );
}

class PlaceholderPage extends StatelessWidget {
  const PlaceholderPage({super.key, required this.title, required this.text});
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return KwfPage(children: [
      KwfPageHeading(title),
      KwfCard(
        padding: const EdgeInsets.all(20),
        child: Text(text, style: KwfText.body),
      ),
    ]);
  }
}
