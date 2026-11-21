import 'package:flutter/material.dart';

import '../theme/kwf_theme.dart';
import 'household_form.dart';

/// Kurzer Einstieg beim ersten Start mit einem Monitor ohne Haushalt.
/// "Später" schliesst ihn fuer diese Sitzung; die Angaben bleiben unter
/// "Mehr > Haushalt" jederzeit erfassbar.
Future<void> showHouseholdOnboarding(BuildContext context, {required String monitorId}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    isDismissible: false,
    enableDrag: false,
    builder: (c) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(c).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Wer wohnt hier?', style: KwfText.screenTitle),
              const SizedBox(height: 6),
              Text(
                  'Damit wir Energie pro Person rechnen können, brauchen wir zwei Angaben '
                  'zu deinem Haushalt.',
                  style: KwfText.body),
              const SizedBox(height: 16),
              HouseholdForm(
                monitorId: monitorId,
                askValidFrom: false,
                submitLabel: 'Weiter',
                onSaved: () => Navigator.of(c).pop(),
              ),
              TextButton(
                onPressed: () => Navigator.of(c).pop(),
                child: const Text('Später'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
