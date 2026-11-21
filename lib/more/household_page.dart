import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app/services.dart';
import '../app/session_scope.dart';
import '../household/household.dart';
import '../household/household_form.dart';
import '../theme/kwf_theme.dart';
import '../theme/kwf_widgets.dart';
import 'sub_page.dart';

final _date = DateFormat('d.M.yyyy');

/// Haushalt anzeigen und aendern. Jede Aenderung ist ein neuer Eintrag mit
/// "gilt ab", alte Eintraege bleiben als Verlauf stehen.
class HouseholdPage extends StatefulWidget {
  const HouseholdPage({super.key});

  @override
  State<HouseholdPage> createState() => _HouseholdPageState();
}

class _HouseholdPageState extends State<HouseholdPage> {
  bool _editing = false;

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    final services = AppServices.of(context);
    final monitor = session.active;
    if (monitor == null) {
      return const SubPage(title: 'Haushalt', children: [Text('Kein Monitor aktiv.')]);
    }
    return StreamBuilder<List<HouseholdEntry>>(
      stream: services.household.watch(monitor.id),
      builder: (context, snap) {
        final entries = snap.data ?? const <HouseholdEntry>[];
        final current = householdAt(entries, services.clock.now());
        return SubPage(title: 'Haushalt', children: [
          Text(
              'Personen und Wohnfläche brauchen wir, um Energie pro Person zu rechnen. '
              'Ändert sich etwas, trag es mit dem Datum ein, ab dem es gilt.',
              style: KwfText.body),
          KwfCard(
            padding: const EdgeInsets.all(16),
            child: current == null
                ? Text('Noch nicht erfasst.', style: KwfText.body)
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(current.summary, style: KwfText.sectionTitle),
                      const SizedBox(height: 2),
                      Text('gilt seit ${_date.format(current.validFrom)}', style: KwfText.meta),
                    ],
                  ),
          ),
          if (session.canEdit && !_editing)
            OutlinedButton(
              key: const ValueKey('household-edit'),
              onPressed: () => setState(() => _editing = true),
              child: Text(current == null ? 'ERFASSEN' : 'ÄNDERN'),
            ),
          if (!session.canEdit)
            Text('Du kannst bei diesem Monitor keine Daten ändern.', style: KwfText.meta),
          if (_editing)
            KwfCard(
              padding: const EdgeInsets.all(16),
              child: HouseholdForm(
                monitorId: monitor.id,
                current: current,
                onSaved: () => setState(() => _editing = false),
              ),
            ),
          if (entries.length > 1)
            KwfSection(title: 'Verlauf', children: [
              for (final e in entries.reversed)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    children: [
                      Expanded(child: Text(e.summary, style: KwfText.body)),
                      Text('ab ${_date.format(e.validFrom)}', style: KwfText.meta),
                    ],
                  ),
                ),
            ]),
        ]);
      },
    );
  }
}
