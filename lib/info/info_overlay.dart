import 'package:flutter/material.dart';

import '../theme/kwf_theme.dart';
import '../theme/kwf_tokens.dart';
import 'info_texts.dart';

/// Kleines Info-Symbol (Trefferflaeche 44 px). Oeffnet das Overlay von unten.
class InfoButton extends StatelessWidget {
  const InfoButton({super.key, required this.text, required this.stand});

  final InfoText text;

  /// Teil 5 "Stand", z.B. "Daten bis 21.11.2026, 14:00".
  final String stand;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44,
      height: 44,
      child: IconButton(
        tooltip: 'So entsteht diese Zahl',
        padding: EdgeInsets.zero,
        icon: const Icon(Icons.info_outline, size: 20, color: KwfColors.textSekundaer),
        onPressed: () => showInfoOverlay(context, text: text, stand: stand),
      ),
    );
  }
}

Future<void> showInfoOverlay(BuildContext context,
    {required InfoText text, required String stand}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => InfoOverlay(text: text, stand: stand),
  );
}

/// Das Overlay mit immer denselben fuenf Teilen.
class InfoOverlay extends StatelessWidget {
  const InfoOverlay({super.key, required this.text, required this.stand});

  final InfoText text;
  final String stand;

  @override
  Widget build(BuildContext context) {
    final parts = <(String, String)>[
      ('Was du siehst', text.what),
      ('Woher die Daten kommen', text.source),
      ('Wie wir rechnen', text.method),
      ('Wie sicher das ist', text.certainty),
      ('Stand', stand),
    ];
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.85),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(header: true, child: Text(text.title, style: KwfText.screenTitle)),
              if (text.note != null) ...[
                const SizedBox(height: 8),
                Text(text.note!, style: kwfText(14, weight: FontWeight.w600)),
              ],
              for (final (heading, body) in parts) ...[
                const SizedBox(height: 16),
                Text(heading.toUpperCase(), style: KwfText.kicker),
                const SizedBox(height: 4),
                Text(body, style: KwfText.body),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
