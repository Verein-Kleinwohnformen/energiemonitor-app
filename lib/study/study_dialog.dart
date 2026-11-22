import 'package:flutter/material.dart';

import '../theme/kwf_theme.dart';

/// Text zur Energiestudie. Erscheint einmal als Dialog beim ersten Oeffnen
/// eines Studienmonitors und dauerhaft unter "Mehr > Über die Energiestudie".
const kStudyText =
    'Damit die Messung unverfälscht bleibt, zeigt die App während der Studie keine '
    'Auswertungen. Deinen persönlichen Bericht bekommst du nach dem Messjahr.';

const kStudyWhatYouDo =
    'Trag weiterhin ein, was du an Holz, Pellets, Gas oder Heizöl nachfüllst, am besten '
    'mit dem Rest. Unter "Mehr" siehst du, ob dein Monitor Daten schickt.';

Future<void> showStudyDialog(BuildContext context, {String? note}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (c) => AlertDialog(
      title: const Text('Dein Haus ist Teil der Energiestudie'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(kStudyText),
          if (note != null) ...[
            const SizedBox(height: 10),
            Text(note, style: kwfText(14, weight: FontWeight.w600)),
          ],
          const SizedBox(height: 10),
          const Text(kStudyWhatYouDo),
        ],
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(c).pop(),
          child: const Text('VERSTANDEN'),
        ),
      ],
    ),
  );
}
