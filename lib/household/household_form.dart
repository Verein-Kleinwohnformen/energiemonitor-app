import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app/services.dart';
import '../capture/capture_logic.dart';
import '../theme/kwf_theme.dart';
import '../theme/kwf_tokens.dart';
import 'household.dart';

final _date = DateFormat('d.M.yyyy');

/// Personen, Wohnflaeche und Label-Wert erfassen. Wird beim ersten Start und
/// unter "Mehr > Haushalt" verwendet. Speichert immer einen neuen Eintrag.
class HouseholdForm extends StatefulWidget {
  const HouseholdForm({
    super.key,
    required this.monitorId,
    this.current,
    this.askValidFrom = true,
    required this.onSaved,
    this.submitLabel = 'Speichern',
  });

  final String monitorId;
  final HouseholdEntry? current;

  /// Beim ersten Start gilt der Eintrag ab heute, ohne Rueckfrage.
  final bool askValidFrom;
  final VoidCallback onSaved;
  final String submitLabel;

  @override
  State<HouseholdForm> createState() => _HouseholdFormState();
}

class _HouseholdFormState extends State<HouseholdForm> {
  final _key = GlobalKey<FormState>();
  late final _persons = TextEditingController(text: widget.current?.persons.toString() ?? '');
  late final _area = TextEditingController(
      text: widget.current?.livingAreaM2 == null ? '' : formatQuantity(widget.current!.livingAreaM2!));
  late final _label = TextEditingController(
      text: widget.current?.labelWPerPerson == null
          ? ''
          : formatQuantity(widget.current!.labelWPerPerson!));
  DateTime? _validFrom;
  bool _saving = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final now = AppServices.of(context).clock.now();
    _validFrom ??= DateTime(now.year, now.month, now.day);
  }

  @override
  void dispose() {
    _persons.dispose();
    _area.dispose();
    _label.dispose();
    super.dispose();
  }

  String? _validatePersons(String? v) {
    final n = int.tryParse(v?.trim() ?? '');
    if (n == null) return 'Bitte eine ganze Zahl eingeben';
    if (n < 1 || n > 20) return 'Bitte zwischen 1 und 20';
    return null;
  }

  String? _validateOptional(String? v, {required double max}) {
    if (v == null || v.trim().isEmpty) return null;
    final d = parseQuantity(v);
    if (d == null) return 'Bitte eine gültige Zahl eingeben';
    if (d <= 0 || d > max) return 'Bitte eine Zahl zwischen 0 und ${max.toInt()}';
    return null;
  }

  Future<void> _save() async {
    if (!_key.currentState!.validate()) return;
    setState(() => _saving = true);
    final entry = HouseholdEntry(
      validFrom: _validFrom!,
      persons: int.parse(_persons.text.trim()),
      livingAreaM2: parseQuantity(_area.text),
      labelWPerPerson: parseQuantity(_label.text),
    );
    try {
      await AppServices.of(context).household.add(widget.monitorId, entry);
      if (mounted) widget.onSaved();
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Speichern hat nicht geklappt. Prüfe die Verbindung.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    InputDecoration deco(String suffix) => InputDecoration(suffixText: suffix);
    return Form(
      key: _key,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Wie viele Personen wohnen hier?', style: KwfText.label),
          const SizedBox(height: 6),
          TextFormField(
            key: const ValueKey('household-persons'),
            controller: _persons,
            keyboardType: TextInputType.number,
            decoration: deco('Personen'),
            validator: _validatePersons,
          ),
          const SizedBox(height: 14),
          Text('Wie gross ist die Wohnfläche?', style: KwfText.label),
          const SizedBox(height: 6),
          TextFormField(
            key: const ValueKey('household-area'),
            controller: _area,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: deco('m²'),
            validator: (v) => _validateOptional(v, max: 1000),
          ),
          const SizedBox(height: 14),
          Text('Wert aus dem KWF-Energielabel (falls vorhanden)', style: KwfText.label),
          const SizedBox(height: 6),
          TextFormField(
            key: const ValueKey('household-label'),
            controller: _label,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: deco('W pro Person'),
            validator: (v) => _validateOptional(v, max: 10000),
          ),
          if (widget.askValidFrom) ...[
            const SizedBox(height: 14),
            Text('Gilt ab', style: KwfText.label),
            const SizedBox(height: 6),
            OutlinedButton.icon(
              icon: const Icon(Icons.calendar_today_outlined, size: 18),
              label: Text(_date.format(_validFrom!)),
              style: OutlinedButton.styleFrom(
                textStyle: kwfText(14, weight: FontWeight.w500),
                shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(Radius.circular(KwfRadius.md))),
                alignment: Alignment.centerLeft,
              ),
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _validFrom!,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2100),
                );
                if (picked != null) setState(() => _validFrom = picked);
              },
            ),
          ],
          const SizedBox(height: 8),
          Text(
              'Die Wohnfläche und der Label-Wert sind freiwillig. Du kannst alles später '
              'unter "Mehr > Haushalt" ändern.',
              style: KwfText.help),
          const SizedBox(height: 16),
          FilledButton(
            key: const ValueKey('household-save'),
            onPressed: _saving ? null : _save,
            child: Text(widget.submitLabel.toUpperCase()),
          ),
        ],
      ),
    );
  }
}
