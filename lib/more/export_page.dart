import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../app/services.dart';
import '../app/session_scope.dart';
import '../platform/download.dart';
import '../theme/kwf_theme.dart';
import '../theme/kwf_tokens.dart';
import '../theme/kwf_widgets.dart';
import '../user.dart';
import 'export_logic.dart';
import 'sub_page.dart';

final _iso = DateFormat('yyyy-MM-dd');
final _date = DateFormat('d.M.yyyy');
const _monthNames = [
  'Januar', 'Februar', 'März', 'April', 'Mai', 'Juni',
  'Juli', 'August', 'September', 'Oktober', 'November', 'Dezember',
];

/// "Oktober 2026", ohne Abhaengigkeit von geladenen Locale-Daten.
String monthLabel(DateTime d) => '${_monthNames[d.month - 1]} ${d.year}';

enum _Preset { lastMonth, calendarMonth, custom }

class ExportPage extends StatefulWidget {
  const ExportPage({super.key});

  @override
  State<ExportPage> createState() => _ExportPageState();
}

class _ExportPageState extends State<ExportPage> {
  _Preset _preset = _Preset.lastMonth;
  late DateTime _now;
  late DateTime _month;
  late DateTime _from;
  late DateTime _to;
  bool _busy = false;
  String? _progress;
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _now = AppServices.of(context).clock.now();
    final lm = lastMonth(_now);
    _month = lm.start;
    _from = lm.start;
    _to = lm.end;
  }

  DayRange get _range => switch (_preset) {
        _Preset.lastMonth => lastMonth(_now),
        _Preset.calendarMonth => calendarMonth(_month.year, _month.month, _now),
        _Preset.custom => DayRange(_from, _to),
      };

  Future<void> _pickMonth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _month,
      firstDate: DateTime(2024),
      lastDate: _now,
      initialDatePickerMode: DatePickerMode.year,
      helpText: 'Monat wählen',
    );
    if (picked != null) setState(() => _month = DateTime(picked.year, picked.month));
  }

  Future<void> _pickDay({required bool from}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: from ? _from : _to,
      firstDate: DateTime(2024),
      lastDate: _now,
    );
    if (picked == null) return;
    setState(() {
      if (from) {
        _from = picked;
        if (_to.isBefore(_from)) _to = _from;
      } else {
        _to = picked;
        if (_from.isAfter(_to)) _from = _to;
      }
    });
  }

  Future<void> _download() async {
    final session = SessionScope.read(context);
    final monitor = session.active;
    // Der Download-Schluessel steht heute im User-Dokument (monitor_api_keys).
    final key = AppUser().monitorApiKeys[monitor?.id];
    if (monitor == null) return;
    if (key == null || key.isEmpty) {
      setState(() => _error = 'Für diesen Monitor ist kein Download freigeschaltet. '
          'Schreib uns, wenn du die Daten brauchst.');
      return;
    }
    final parts = splitIntoMonths(_range);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      for (var i = 0; i < parts.length; i++) {
        final p = parts[i];
        setState(() => _progress = 'Datei ${i + 1} von ${parts.length} wird geladen');
        final from = _iso.format(p.start);
        final to = _iso.format(p.end);
        final res = await http.get(
          Uri.parse('$kApiBaseUrl/export?start_date=$from&end_date=$to'),
          headers: {'KWF-Device-Key': key},
        );
        if (res.statusCode != 200) {
          throw _ExportError(switch (res.statusCode) {
            400 => 'Der Zeitraum wurde nicht akzeptiert.',
            401 => 'Der Download ist für diesen Monitor nicht freigeschaltet.',
            _ => 'Der Server hat nicht geantwortet (Code ${res.statusCode}). Versuch es später.',
          });
        }
        saveBytes(res.bodyBytes, 'energiemonitor_${monitor.id}_${from}_$to.xlsx',
            mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(parts.length == 1
              ? 'Datei heruntergeladen'
              : '${parts.length} Dateien heruntergeladen')));
    } on _ExportError catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Keine Verbindung zum Server. Prüfe das Internet.');
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _progress = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final monitor = SessionScope.of(context).active;
    final range = _range;
    final parts = splitIntoMonths(range);
    Widget option(_Preset p, String title, String subtitle, {VoidCallback? onEdit}) {
      final active = p == _preset;
      return InkWell(
        onTap: () {
          setState(() => _preset = p);
          if (onEdit != null) onEdit();
        },
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: KwfColors.weiss,
            border: Border.all(
                color: active ? KwfColors.gruenDunkel : KwfColors.feldrand, width: active ? 2 : 1),
          ),
          child: Row(
            children: [
              Icon(active ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                  color: active ? KwfColors.gruenDunkel : KwfColors.textSekundaer),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: kwfText(15, weight: FontWeight.w500)),
                    Text(subtitle, style: KwfText.meta),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SubPage(title: 'Daten herunterladen', gap: 10, children: [
      Text('Alle Messwerte von ${monitor?.tinyhouseName ?? 'deinem Monitor'} als Excel, '
          'ein Blatt pro Sensor.', style: KwfText.body),
      const SizedBox(height: 4),
      option(_Preset.lastMonth, 'Letzter Monat', monthLabel(lastMonth(_now).start)),
      option(_Preset.calendarMonth, 'Kalendermonat wählen',
          _preset == _Preset.calendarMonth ? monthLabel(_month) : 'z.B. ${monthLabel(_month)}',
          onEdit: _pickMonth),
      option(_Preset.custom, 'Eigener Zeitraum', 'Von und bis frei wählbar'),
      if (_preset == _Preset.custom)
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => _pickDay(from: true),
                child: Text('VON ${_date.format(_from)}'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton(
                onPressed: () => _pickDay(from: false),
                child: Text('BIS ${_date.format(_to)}'),
              ),
            ),
          ],
        ),
      const SizedBox(height: 4),
      KwfCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                '${_date.format(range.start)} bis ${_date.format(range.end)} · '
                '${parts.length == 1 ? '1 Datei' : '${parts.length} Dateien, je ein Monat'}',
                style: kwfText(14, weight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(
                'Länger als 31 Tage teilt die App selbst auf und lädt die Dateien nacheinander. '
                'Rund 30 MB pro Monat.',
                style: KwfText.meta),
          ],
        ),
      ),
      if (_error != null) KwfHint(_error!, icon: Icons.error_outline),
      if (_progress != null) Text(_progress!, style: KwfText.meta),
      KwfPrimaryButton('Herunterladen',
          busy: _busy, onPressed: parts.isEmpty ? null : _download),
      Text(
          'Die Dateien schneiden nach UTC-Tagen. Ein Tag beginnt in der Schweiz um 01:00 '
          '(Winter) oder 02:00 (Sommer).',
          style: KwfText.help),
    ]);
  }
}

class _ExportError implements Exception {
  _ExportError(this.message);
  final String message;
}
