// Seite Erfassen: Vorrat, Formular-Knopf, Erinnerungen, Liste der Eintraege.
//
// Grundregel: Diese Seite sieht im Studienmodus und im normalen Modus genau
// gleich aus. Sie haengt darum nicht vom Studienmodus ab (Golden-Test prueft
// das). Abhaengig ist sie nur von den Eintraegen und davon, ob die Person
// bearbeiten darf.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../app/routes.dart';
import '../app/services.dart';
import '../app/session_scope.dart';
import '../info/info_overlay.dart';
import '../info/info_texts.dart';
import '../theme/kwf_theme.dart';
import '../theme/kwf_tokens.dart';
import '../theme/kwf_widgets.dart';
import 'capture_logic.dart';
import 'energy_form_page.dart';
import 'energy_kinds.dart';

final _date = DateFormat('d.M.yyyy');

class CapturePage extends StatefulWidget {
  const CapturePage({super.key});

  @override
  State<CapturePage> createState() => _CapturePageState();
}

class _CapturePageState extends State<CapturePage> {
  Future<List<ManualEntry>>? _future;
  String? _loadedFor;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final id = SessionScope.of(context).active?.id;
    if (id != _loadedFor) {
      _loadedFor = id;
      _reload();
    }
  }

  void _reload() {
    final id = _loadedFor;
    final services = AppServices.of(context);
    setState(() {
      _future = id == null
          ? Future.value(const [])
          : services.entries.load(id, currentYear: services.clock.now().year);
    });
  }

  Future<void> _openForm(List<ManualEntry> entries, {Stock? from}) async {
    final result = await context.push<FormResult>(
      Routes.captureForm,
      extra: FormStart(
        entries: entries,
        kind: from?.kind,
        meteringPoint: from?.meteringPoint,
      ),
    );
    if (result == null || !mounted) return;
    _reload();
    final fresh = await _future!;
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result.summary(fresh))),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ManualEntry>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return KwfPage(children: [
            const KwfPageHeading('Erfassen'),
            const KwfHint('Die Einträge konnten nicht geladen werden. Prüfe die Verbindung '
                'und versuche es nochmals.'),
            OutlinedButton(onPressed: _reload, child: const Text('NOCHMALS LADEN')),
          ]);
        }
        return CaptureView(
          entries: snap.data ?? const [],
          canEdit: SessionScope.of(context).canEdit,
          now: AppServices.of(context).clock.now(),
          onAdd: (from) => _openForm(snap.data ?? const [], from: from),
          onDelete: (entry) async {
            await AppServices.of(context).entries.delete(entry);
            if (!context.mounted) return;
            ScaffoldMessenger.of(context)
                .showSnackBar(const SnackBar(content: Text('Eintrag gelöscht')));
            _reload();
          },
        );
      },
    );
  }
}

/// Der sichtbare Inhalt, ohne Laden. Wird im Golden-Test direkt gerendert.
class CaptureView extends StatelessWidget {
  const CaptureView({
    super.key,
    required this.entries,
    required this.canEdit,
    required this.now,
    required this.onAdd,
    required this.onDelete,
  });

  final List<ManualEntry> entries;
  final bool canEdit;
  final DateTime now;
  final void Function(Stock? from) onAdd;
  final Future<void> Function(ManualEntry entry) onDelete;

  @override
  Widget build(BuildContext context) {
    final stocks = stocksOf(entries);
    final reminders = remindersFor(stocks, now);
    return KwfPage(children: [
      const KwfPageHeading('Erfassen',
          intro: 'Was kein Zähler misst, trägst du hier ein: Holz, Pellets, Gas, Heizöl. '
              'Jeder Eintrag mit Rest hilft der Studie.'),
      if (canEdit)
        KwfPrimaryButton('Energieträger erfassen', onPressed: () => onAdd(null))
      else
        Text('Du kannst bei diesem Monitor keine Daten hinzufügen.',
            style: kwfText(13, weight: FontWeight.w600)),
      if (stocks.isNotEmpty) ...[
        const KwfKicker('Dein Vorrat'),
        _StockGrid(
            stocks: stocks, canEdit: canEdit, onTap: canEdit ? (s) => onAdd(s) : null),
      ],
      for (final r in reminders) KwfHint(r.text, icon: Icons.schedule),
      _EntryList(entries: entries, canEdit: canEdit, onDelete: onDelete),
    ]);
  }
}

class _StockGrid extends StatelessWidget {
  const _StockGrid({required this.stocks, required this.canEdit, required this.onTap});
  final List<Stock> stocks;
  final bool canEdit;
  final void Function(Stock)? onTap;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < stocks.length; i += 2) {
      rows.add(IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: StockCard(stock: stocks[i], canEdit: canEdit, onTap: onTap)),
            const SizedBox(width: 10),
            Expanded(
              child: i + 1 < stocks.length
                  ? StockCard(stock: stocks[i + 1], canEdit: canEdit, onTap: onTap)
                  : const SizedBox(),
            ),
          ],
        ),
      ));
    }
    return Column(
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          rows[i],
        ],
      ],
    );
  }
}

class StockCard extends StatelessWidget {
  const StockCard({super.key, required this.stock, required this.canEdit, this.onTap});
  final Stock stock;
  final bool canEdit;
  final void Function(Stock)? onTap;

  @override
  Widget build(BuildContext context) {
    final kind = stock.kind;
    return KwfCard(
      padding: const EdgeInsets.fromLTRB(14, 14, 2, 14),
      onTap: onTap == null ? null : () => onTap!(stock),
      semanticLabel: '${kind.label}, ${formatQuantity(stock.amount)} ${stock.unit}. Nachfüllen',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  color: kind.color,
                  child: Icon(kind.icon, size: 18, color: KwfColors.weiss),
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(kind.label, style: KwfText.cardTitle)),
              ],
            ),
          ),
          // Zahl mit Info-Symbol daneben: der Name oben hat so die ganze Breite.
          Row(
            children: [
              Expanded(
                child: Text.rich(TextSpan(children: [
                  TextSpan(text: formatQuantity(stock.amount), style: KwfText.number),
                  TextSpan(
                      text: ' ${stock.unit}',
                      style: kwfText(13, weight: FontWeight.w400, color: KwfColors.textSekundaer)),
                ])),
              ),
              InfoButton(
                text: InfoTexts.stock,
                stand: 'Dein letzter Eintrag vom ${_date.format(stock.date)}',
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    'beim letzten Eintrag\n${meteringText(stock.meteringPoint)} · '
                    '${_date.format(stock.date)}',
                    style: kwfText(11,
                        weight: FontWeight.w400,
                        color: KwfColors.textSekundaer,
                        height: 15 / 11)),
                if (canEdit) ...[
                  const SizedBox(height: 6),
                  Text('Nachfüllen', style: KwfText.link),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EntryList extends StatelessWidget {
  const _EntryList({required this.entries, required this.canEdit, required this.onDelete});
  final List<ManualEntry> entries;
  final bool canEdit;
  final Future<void> Function(ManualEntry) onDelete;

  @override
  Widget build(BuildContext context) {
    return KwfSection(
      title: 'Deine Einträge',
      children: entries.isEmpty
          ? [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                    'Noch keine Einträge. Trag Holz, Pellets oder Gas am besten gleich '
                    'ein, wenn du nachfüllst.',
                    style: KwfText.body),
              )
            ]
          : [
              for (final e in entries)
                EntryTile(
                  entry: e,
                  hasPredecessor: hasPredecessor(e, entries),
                  canEdit: canEdit,
                  onDelete: () => onDelete(e),
                ),
            ],
    );
  }
}

class EntryTile extends StatelessWidget {
  const EntryTile({
    super.key,
    required this.entry,
    required this.hasPredecessor,
    required this.canEdit,
    required this.onDelete,
  });

  final ManualEntry entry;
  final bool hasPredecessor;
  final bool canEdit;
  final Future<void> Function() onDelete;

  @override
  Widget build(BuildContext context) {
    final e = entry.energy;
    final unit = e.displayUnit;
    final consumed = hasPredecessor && entry.storedConsumed != null
        ? '${formatQuantity(entry.storedConsumed!)} $unit'
        : '–';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 4, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(TextSpan(children: [
                  TextSpan(text: EnergyKind.of(e.type).label, style: KwfText.cardTitle),
                  TextSpan(
                      text: ' · ${_date.format(e.purchaseDate)}',
                      style: kwfText(14,
                          weight: FontWeight.w400, color: KwfColors.textSekundaer)),
                ])),
                const SizedBox(height: 2),
                Text(e.description, style: kwfText(13, weight: FontWeight.w400)),
                const SizedBox(height: 2),
                Text(
                    '+${formatQuantity(e.purchaseQuantity)} $unit, Rest '
                    '${formatQuantity(e.leftoverQuantity)} $unit, verbraucht $consumed · '
                    '${e.meteringPoint}',
                    style: KwfText.meta),
              ],
            ),
          ),
          if (canEdit)
            IconButton(
              tooltip: 'Eintrag löschen',
              icon: const Icon(Icons.delete_outline, color: KwfColors.anthrazit),
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (c) => AlertDialog(
                    title: const Text('Eintrag löschen'),
                    content: const Text('Willst du diesen Eintrag wirklich löschen?'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.of(c).pop(false),
                          child: const Text('Abbrechen')),
                      TextButton(
                          onPressed: () => Navigator.of(c).pop(true),
                          child: const Text('Löschen')),
                    ],
                  ),
                );
                if (ok == true) await onDelete();
              },
            ),
        ],
      ),
    );
  }
}
