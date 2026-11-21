import 'package:flutter/material.dart';

import '../app/session_scope.dart';
import '../theme/kwf_theme.dart';
import '../theme/kwf_tokens.dart';
import '../theme/kwf_widgets.dart';
import 'sub_page.dart';

class MonitorSwitchPage extends StatelessWidget {
  const MonitorSwitchPage({super.key});

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    return SubPage(title: 'Monitor wechseln', children: [
      Text('Du hast Zugriff auf ${session.monitors.length} Monitore.', style: KwfText.body),
      KwfSection(children: [
        for (final m in session.monitors)
          InkWell(
            onTap: () {
              session.selectMonitor(m.id);
              Navigator.of(context).maybePop();
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(m.tinyhouseName, style: kwfText(15, weight: FontWeight.w500)),
                        Text(
                            [
                              m.tinyhouseLocation,
                              if (m.studyMode) 'Energiestudie',
                              if (!session.data!.editableIds.contains(m.id)) 'nur lesen',
                            ].join(' · '),
                            style: KwfText.meta),
                      ],
                    ),
                  ),
                  if (m.id == session.active?.id)
                    const Icon(Icons.check, color: KwfColors.gruenDunkel),
                ],
              ),
            ),
          ),
      ]),
    ]);
  }
}
