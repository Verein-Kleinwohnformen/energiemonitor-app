import 'package:flutter/material.dart';

import '../theme/kwf_tokens.dart';
import '../theme/kwf_widgets.dart';

/// Unterseite von "Mehr": Titel mit Zurueck, Inhalt auf dem Seitengrund.
class SubPage extends StatelessWidget {
  const SubPage({super.key, required this.title, required this.children, this.gap = 14});
  final String title;
  final List<Widget> children;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KwfColors.seitengrund,
      appBar: AppBar(
        title: Text(title),
        leading: IconButton(
          tooltip: 'Zurück',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: KwfPage(gap: gap, children: children),
    );
  }
}
