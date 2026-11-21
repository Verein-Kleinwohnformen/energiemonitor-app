// Formular "Energietraeger erfassen" im neuen Layout.
//
// Fachlich 1:1 wie das alte Formular (lib/legacy/energy_form_legacy.dart):
// gleiche Felder, gleiche Auswahlwerte, gleiche Pflichtfelder, gleiches
// Dokument ueber Energy.addToFirebase(). Neu sind nur Anordnung, Texte und
// Vorbelegung, und Mengen duerfen ein Komma haben (Entscheid 21.11.2026).
// Der Formular-Regressionstest (integration_test/) vergleicht beide.
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app/services.dart';
import '../app/session_scope.dart';
import '../theme/kwf_theme.dart';
import '../theme/kwf_tokens.dart';
import '../theme/kwf_widgets.dart';
import 'capture_logic.dart';
import 'energy_kinds.dart';

final _date = DateFormat('d.M.yyyy');

/// Womit das Formular startet (von einer Vorrat-Karte oder leer).
class FormStart {
  const FormStart({this.entries = const [], this.kind, this.meteringPoint});
  final List<ManualEntry> entries;
  final EnergyKind? kind;
  final String? meteringPoint;
}

/// Was gespeichert wurde, fuer die Bestaetigung auf der Seite Erfassen.
class FormResult {
  const FormResult(this.values);
  final FormValues values;

  String summary(List<ManualEntry> fresh) {
    final v = values;
    final type = v.kind.typeFor(v.unit);
    final unit = unitText(EnergyKind.unitOf(type));
    final head = '${v.kind.label}, ${formatQuantity(v.added)} $unit, '
        'Rest ${formatQuantity(v.leftover)} $unit.';
    final saved = fresh.where((e) =>
        e.energy.type == type &&
        e.energy.meteringPoint == v.meteringPoint &&
        e.energy.purchaseDate == v.purchase);
    if (saved.isEmpty) return '$head Gespeichert.';
    final entry = saved.first;
    if (!hasPredecessor(entry, fresh) || entry.storedConsumed == null) {
      return '$head Den Verbrauch rechnen wir ab dem nächsten Eintrag.';
    }
    return '$head Seit dem letzten Eintrag verbraucht: '
        '${formatQuantity(entry.storedConsumed!)} $unit.';
  }
}

class EnergyFormPage extends StatefulWidget {
  const EnergyFormPage({super.key, this.start});
  final FormStart? start;

  @override
  State<EnergyFormPage> createState() => _EnergyFormPageState();
}

class _EnergyFormPageState extends State<EnergyFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _description = TextEditingController();
  final _added = TextEditingController();
  final _leftover = TextEditingController();

  EnergyKind? _kind;
  String? _unit;
  String? _mp;
  DateTime? _purchase;
  DateTime? _usage;

  bool _mpFromLast = false;
  bool _mpTouched = false;
  bool _descTouched = false;
  bool _unitTouched = false;
  bool _usageTouched = false;
  bool _usageSuggested = false;
  bool _saving = false;
  bool _initialized = false;

  List<ManualEntry> get _entries => widget.start?.entries ?? const [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    final now = AppServices.of(context).clock.now();
    // Kaufdatum heute, als Kalendertag um Mitternacht wie der Datumswaehler.
    _purchase = DateTime(now.year, now.month, now.day);
    final start = widget.start;
    if (start?.kind != null) _selectKind(start!.kind!, meteringPoint: start.meteringPoint);
    _added.addListener(_updateSuggestion);
    _leftover.addListener(_updateSuggestion);
  }

  @override
  void dispose() {
    _description.dispose();
    _added.dispose();
    _leftover.dispose();
    super.dispose();
  }

  void _selectKind(EnergyKind kind, {String? meteringPoint}) {
    final prefill = prefillFor(kind, _entries, meteringPoint: meteringPoint);
    setState(() {
      _kind = kind;
      if (!_unitTouched || !kind.units.contains(_unit)) {
        _unit = kind.units.contains(prefill.unit) ? prefill.unit : kind.units.first;
      }
      if (!_mpTouched) {
        _mp = prefill.meteringPoint;
        _mpFromLast = prefill.description != null && prefill.meteringPoint != null;
      }
      if (!_descTouched && prefill.description != null) {
        _description.text = prefill.description!;
      }
    });
    _updateSuggestion();
  }

  Stock? get _stock {
    final kind = _kind;
    if (kind == null || _mp == null) return null;
    final type = kind.typeFor(_unit);
    for (final s in stocksOf(_entries)) {
      if (s.energy.type == type && s.meteringPoint == _mp) return s;
    }
    return null;
  }

  void _updateSuggestion() {
    if (_usageTouched || _purchase == null) return;
    final suggestion = suggestUsageDate(
      perDay: dailyUsage(_stock),
      purchase: _purchase!,
      added: parseQuantity(_added.text),
      leftover: parseQuantity(_leftover.text),
    );
    if (suggestion == _usage && _usageSuggested == (suggestion != null)) return;
    setState(() {
      _usage = suggestion;
      _usageSuggested = suggestion != null;
    });
  }

  Future<void> _pickDate({required bool purchase}) async {
    final current = purchase ? _purchase : _usage;
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? _purchase ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: purchase ? 'Hinzugefügt am' : 'Aufgebraucht etwa',
    );
    if (picked == null) return;
    setState(() {
      if (purchase) {
        _purchase = picked;
      } else {
        _usage = picked;
        _usageTouched = true;
        _usageSuggested = false;
      }
    });
    if (purchase) _updateSuggestion();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final session = SessionScope.read(context);
    final values = FormValues(
      kind: _kind!,
      unit: _unit,
      meteringPoint: _mp!,
      description: _description.text,
      added: parseQuantity(_added.text)!,
      leftover: parseQuantity(_leftover.text)!,
      purchase: _purchase!,
      usage: _usage!,
    );
    setState(() => _saving = true);
    try {
      await AppServices.of(context)
          .entries
          .add(values.toEnergy(userId: session.uid, monitorId: session.active?.id));
      if (!mounted) return;
      Navigator.of(context).pop(FormResult(values));
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Speichern hat nicht geklappt. Prüfe die Verbindung.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final unitLabel = _unit == null ? '' : unitText(_unit!);
    return Scaffold(
      backgroundColor: KwfColors.weiss,
      appBar: AppBar(
        title: const Text('Energieträger erfassen'),
        leading: IconButton(
          tooltip: 'Zurück',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            const _Step(1, 'Was?'),
            const SizedBox(height: 12),
            FormField<EnergyKind>(
              validator: (_) => _kind == null ? 'Bitte einen Energieträger wählen' : null,
              builder: (field) => _withError(
                field,
                _TypeGrid(
                  selected: _kind,
                  onSelect: (k) {
                    _selectKind(k);
                    field.didChange(k);
                  },
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (_kind == null)
              Text('Einheit: je nach Energieträger kg, Liter oder Ster',
                  style: kwfText(13, weight: FontWeight.w400, color: KwfColors.textSekundaer))
            else if (_kind!.hasUnitChoice)
              _UnitToggle(
                units: _kind!.units,
                selected: _unit!,
                onChanged: (u) {
                  setState(() {
                    _unit = u;
                    _unitTouched = true;
                  });
                  _updateSuggestion();
                },
              )
            else
              Text.rich(TextSpan(
                style: kwfText(13, weight: FontWeight.w400),
                children: [
                  const TextSpan(text: 'Einheit: '),
                  TextSpan(text: unitLabel, style: kwfText(13, weight: FontWeight.w600)),
                ],
              )),
            const SizedBox(height: 14),
            _Label('Wofür brauchst du es?', extra: _mpFromLast ? '· vom letzten Mal' : null),
            const SizedBox(height: 6),
            FormField<String>(
              validator: (_) => _mp == null ? 'Bitte einen Messpunkt wählen' : null,
              builder: (field) => _withError(
                field,
                _MeteringChoice(
                  selected: _mp,
                  onSelect: (code) {
                    setState(() {
                      _mp = code;
                      _mpTouched = true;
                      _mpFromLast = false;
                    });
                    field.didChange(code);
                    _updateSuggestion();
                  },
                ),
              ),
            ),
            const SizedBox(height: 18),
            const _Step(2, 'Wie viel?'),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _QuantityField(
                    key: const ValueKey('form-added'),
                    label: 'Neu dazu',
                    controller: _added,
                    unit: unitLabel,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _QuantityField(
                    key: const ValueKey('form-leftover'),
                    label: 'Noch übrig',
                    controller: _leftover,
                    unit: unitLabel,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
                'Noch übrig: was vor dem Nachfüllen noch da ist. Bei Gas die alte Flasche '
                'wägen und die Tara abziehen (steht auf der Flasche).',
                style: KwfText.help),
            const SizedBox(height: 18),
            const _Step(3, 'Wann?'),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _DateField(
                    key: const ValueKey('form-purchase'),
                    label: 'Hinzugefügt am',
                    value: _purchase,
                    onTap: () => _pickDate(purchase: true),
                    validator: () => validatePurchaseDate(_purchase),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _DateField(
                    key: const ValueKey('form-usage'),
                    label: 'Aufgebraucht etwa',
                    value: _usage,
                    onTap: () => _pickDate(purchase: false),
                    validator: () => validateUsageDate(_usage, _purchase),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
                _usageSuggested
                    ? 'Vorschlag aus deinem bisherigen Verbrauch. Du kannst ihn ändern.'
                    : 'Schätze, bis wann diese Menge reicht. Mit dem nächsten Eintrag '
                        'ersetzen wir die Schätzung durch das echte Datum.',
                style: KwfText.help),
            const SizedBox(height: 18),
            const _Label('Beschreibung'),
            const SizedBox(height: 6),
            TextFormField(
              key: const ValueKey('form-description'),
              controller: _description,
              keyboardType: TextInputType.name,
              textCapitalization: TextCapitalization.sentences,
              autovalidateMode: AutovalidateMode.onUnfocus,
              style: kwfText(16, weight: FontWeight.w400),
              decoration: const InputDecoration(hintText: 'z.B. Flasche getauscht, alte gewogen'),
              onChanged: (_) => _descTouched = true,
              validator: validateDescription,
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          decoration: const BoxDecoration(
            color: KwfColors.weiss,
            border: Border(top: BorderSide(color: KwfColors.grauHell)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              KwfPrimaryButton('Eintrag speichern',
                  key: const ValueKey('form-save'), busy: _saving, onPressed: _save),
              TextButton(
                onPressed: _saving ? null : () => Navigator.of(context).maybePop(),
                child: const Text('Abbrechen'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _withError<T>(FormFieldState<T> field, Widget child) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        child,
        if (field.hasError) ...[
          const SizedBox(height: 6),
          Text(field.errorText!,
              style: kwfText(12, weight: FontWeight.w400, color: KwfColors.signalRot)),
        ],
      ],
    );
  }
}

class _Step extends StatelessWidget {
  const _Step(this.number, this.title);
  final int number;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration:
                const BoxDecoration(color: KwfColors.anthrazit, shape: BoxShape.circle),
            child: Text('$number',
                style: kwfText(12, weight: FontWeight.w600, color: KwfColors.weiss)),
          ),
          const SizedBox(width: 10),
          Semantics(header: true, child: Text(title, style: KwfText.sectionTitle)),
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text, {this.extra});
  final String text;
  final String? extra;

  @override
  Widget build(BuildContext context) {
    return Text.rich(TextSpan(
      style: KwfText.label,
      children: [
        TextSpan(text: text),
        TextSpan(text: ' *', style: kwfText(13, weight: FontWeight.w500, color: KwfColors.signalRot)),
        if (extra != null)
          TextSpan(
              text: ' $extra',
              style: kwfText(11, weight: FontWeight.w400, color: KwfColors.textSekundaer)),
      ],
    ));
  }
}

class _TypeGrid extends StatelessWidget {
  const _TypeGrid({required this.selected, required this.onSelect});
  final EnergyKind? selected;
  final ValueChanged<EnergyKind> onSelect;

  @override
  Widget build(BuildContext context) {
    const kinds = EnergyKind.values;
    Widget tile(EnergyKind k) {
      final active = k == selected;
      return Semantics(
        button: true,
        selected: active,
        label: k.label,
        excludeSemantics: true,
        child: InkWell(
          key: ValueKey('form-type-${k.name}'),
          onTap: () => onSelect(k),
          child: Container(
            constraints: const BoxConstraints(minHeight: 76),
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
            decoration: BoxDecoration(
              color: KwfColors.weiss,
              border: Border.all(
                  color: active ? KwfColors.gruenDunkel : KwfColors.feldrand,
                  width: active ? 2 : 1),
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(k.icon, size: 26, color: KwfColors.anthrazit),
                      const SizedBox(height: 6),
                      Text(k.label,
                          textAlign: TextAlign.center,
                          style: kwfText(13,
                              weight: active ? FontWeight.w600 : FontWeight.w400)),
                    ],
                  ),
                ),
                if (active)
                  Positioned(
                    top: -6,
                    right: 0,
                    child: Container(
                      width: 18,
                      height: 18,
                      color: KwfColors.gruenDunkel,
                      child: const Icon(Icons.check, size: 14, color: KwfColors.weiss),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        for (var row = 0; row < 2; row++) ...[
          if (row > 0) const SizedBox(height: 8),
          Row(
            children: [
              for (var col = 0; col < 3; col++) ...[
                if (col > 0) const SizedBox(width: 8),
                Expanded(child: tile(kinds[row * 3 + col])),
              ],
            ],
          ),
        ],
      ],
    );
  }
}

class _UnitToggle extends StatelessWidget {
  const _UnitToggle({required this.units, required this.selected, required this.onChanged});
  final List<String> units;
  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text('Einheit:', style: kwfText(13, weight: FontWeight.w400)),
        const SizedBox(width: 10),
        for (final u in units) ...[
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              key: ValueKey('form-unit-$u'),
              label: Text(unitText(u)),
              selected: u == selected,
              showCheckmark: false,
              onSelected: (_) => onChanged(u),
              labelStyle: kwfText(13,
                  weight: u == selected ? FontWeight.w600 : FontWeight.w400,
                  color: u == selected ? KwfColors.weiss : KwfColors.anthrazit),
              selectedColor: KwfColors.gruenDunkel,
              backgroundColor: KwfColors.weiss,
              side: const BorderSide(color: KwfColors.feldrand),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(KwfRadius.pill)),
            ),
          ),
        ],
      ],
    );
  }
}

class _MeteringChoice extends StatelessWidget {
  const _MeteringChoice({required this.selected, required this.onSelect});
  final String? selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < kMeteringChoices.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(child: _choice(kMeteringChoices[i])),
        ],
      ],
    );
  }

  Widget _choice(MeteringChoice c) {
    final active = c.code == selected;
    return Semantics(
      button: true,
      selected: active,
      label: '${c.label}, ${c.code}',
      excludeSemantics: true,
      child: InkWell(
        key: ValueKey('form-mp-${c.code}'),
        onTap: () => onSelect(c.code),
        child: Container(
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          decoration: BoxDecoration(
            color: KwfColors.weiss,
            border: Border.all(
                color: active ? KwfColors.gruenDunkel : KwfColors.feldrand,
                width: active ? 2 : 1),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(c.label,
                  style: kwfText(13, weight: active ? FontWeight.w600 : FontWeight.w400)),
              const SizedBox(height: 2),
              Text(c.code,
                  style: kwfText(11, weight: FontWeight.w400, color: KwfColors.textSekundaer)),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuantityField extends StatelessWidget {
  const _QuantityField({
    super.key,
    required this.label,
    required this.controller,
    required this.unit,
  });

  final String label;
  final TextEditingController controller;
  final String unit;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Label(label),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autovalidateMode: AutovalidateMode.onUnfocus,
          style: kwfText(16, weight: FontWeight.w400),
          decoration: InputDecoration(suffixText: unit, errorMaxLines: 2),
          validator: validateQuantity,
        ),
      ],
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    super.key,
    required this.label,
    required this.value,
    required this.onTap,
    required this.validator,
  });

  final String label;
  final DateTime? value;
  final VoidCallback onTap;
  final String? Function() validator;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Label(label),
        const SizedBox(height: 6),
        // Neu aufbauen, wenn sich der Wert aendert, damit der Text stimmt.
        TextFormField(
          key: ValueKey('$label-${value?.millisecondsSinceEpoch}'),
          initialValue: value == null ? '' : _date.format(value!),
          readOnly: true,
          onTap: onTap,
          style: kwfText(16, weight: FontWeight.w400),
          decoration: const InputDecoration(
            hintText: 'Datum wählen',
            errorMaxLines: 3,
            suffixIcon: Icon(Icons.calendar_today_outlined, size: 18),
          ),
          validator: (_) => validator(),
        ),
      ],
    );
  }
}
