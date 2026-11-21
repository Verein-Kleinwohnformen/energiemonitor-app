import 'package:flutter/material.dart';

import '../app/session_scope.dart';
import '../study/study_dialog.dart';
import '../theme/kwf_theme.dart';
import '../theme/kwf_widgets.dart';
import 'sub_page.dart';

class StudyInfoPage extends StatelessWidget {
  const StudyInfoPage({super.key});

  @override
  Widget build(BuildContext context) {
    final note = SessionScope.of(context).active?.studyNote;
    return SubPage(title: 'Über die Energiestudie', children: [
      KwfCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Dein Haus ist Teil der Energiestudie', style: KwfText.sectionTitle),
            const SizedBox(height: 8),
            const Text(kStudyText),
            if (note != null) ...[
              const SizedBox(height: 10),
              Text(note, style: kwfText(14, weight: FontWeight.w600)),
            ],
            const SizedBox(height: 10),
            const Text(kStudyWhatYouDo),
          ],
        ),
      ),
      Text(
          'Die Energiestudie führt der Verein Kleinwohnformen mit der Hochschule Luzern '
          'durch. Fragen dazu: energiemonitor@kleinwohnformen.ch',
          style: KwfText.small),
    ]);
  }
}
