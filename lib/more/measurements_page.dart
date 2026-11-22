// Messwerte: einfachere Rohdaten statt Messpunkt -> Sensor -> Feld -> Laden.
//
// Etappe 1: Liste aller Messpunkte und Sensoren, Antippen oeffnet ein
// Diagramm mit einem sinnvollen Standardwert, 24 h oder 7 Tage, ueber die
// bestehende Telemetrie-Abfrage. Mini-Kurven und 30 Tage kommen mit den
// Stundenwerten aus der Tages-Aggregation (Etappe 3).
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app/services.dart';
import '../app/session_scope.dart';
import '../info/info_overlay.dart';
import '../info/info_texts.dart';
import '../metering_point.dart';
import '../status/system_status.dart';
import '../telemetry.dart';
import '../telemetry_service.dart';
import '../theme/kwf_theme.dart';
import '../theme/kwf_tokens.dart';
import '../theme/kwf_widgets.dart';
import 'sub_page.dart';

/// Sensoren in Klartext.
const kSensorNames = <String, String>{
  'victron': 'Victron',
  'shelly-3em-pro': 'Shelly',
  'netatmo': 'Netatmo',
  'sensirion_scd4x': 'Sensirion CO2',
  'sensirion_voc': 'Sensirion',
  'apollon': 'Apollon',
};

String sensorName(String id) => kSensorNames[id] ?? id;

/// Standardwert pro Sensor (Konzept Navigation und UX, 5.6).
/// Klimawerte kommen alle unter K0, getrennt nur ueber sensor_id.
const kDefaultField = <String, String>{
  'shelly-3em-pro': 'act_power',
  'victron': 'power',
  'netatmo': 'temperature_indoor',
  'sensirion_scd4x': 'co2_indoor',
  'sensirion_voc': 'temperature_indoor',
};

/// Klartext und Einheit bekannter Felder.
const kFieldInfo = <String, (String, String)>{
  'act_power': ('Leistung', 'W'),
  'power': ('Leistung', 'W'),
  'aprt_power': ('Scheinleistung', 'VA'),
  'pf': ('Leistungsfaktor', ''),
  'voltage': ('Spannung', 'V'),
  'temperature_indoor': ('Innentemperatur', '°C'),
  'temperature_outdoor': ('Aussentemperatur', '°C'),
  'humidity_indoor': ('Luftfeuchte innen', '%'),
  'humidity_outdoor': ('Luftfeuchte aussen', '%'),
  'co2_indoor': ('CO2 innen', 'ppm'),
  'pressure': ('Luftdruck', 'hPa'),
  'noise': ('Lärm', 'dB'),
  'battery_level': ('Batterie', '%'),
  'rf_signal_strength': ('Funksignal', ''),
  'level_liter': ('Füllstand', 'L'),
};

String fieldLabel(String f) => kFieldInfo[f]?.$1 ?? f;
String fieldUnit(String f) => kFieldInfo[f]?.$2 ?? '';

String groupOf(String mp) {
  if (mp.startsWith('K')) return 'Wohnklima';
  if (mp.startsWith('D')) return 'Wasser';
  return 'Strom';
}

class MeasurementsPage extends StatelessWidget {
  const MeasurementsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final monitor = SessionScope.of(context).active;
    final services = AppServices.of(context);
    if (monitor == null) {
      return const SubPage(title: 'Messwerte', children: [Text('Kein Monitor aktiv.')]);
    }
    return StreamBuilder<List<MeteringPoint>>(
      stream: services.status.watch(monitor.id),
      builder: (context, snap) {
        final now = services.clock.now();
        final points = (snap.data ?? const <MeteringPoint>[])
            .where((p) => !p.meteringPointId.startsWith('M') && p.isActive)
            .toList()
          ..sort((a, b) => a.meteringPointId.compareTo(b.meteringPointId));
        final groups = <String, List<Widget>>{};
        for (final p in points) {
          final sensors = p.sensorTypes.isEmpty ? ['?'] : p.sensorTypes;
          for (final s in sensors) {
            groups.putIfAbsent(groupOf(p.meteringPointId), () => []).add(KwfNavRow(
                  icon: Icons.show_chart,
                  title: '${pointLabel(p.meteringPointId)} · ${sensorName(s)}',
                  subtitle: '${p.meteringPointId} · letzte Daten '
                      '${formatTime(DateTime.fromMillisecondsSinceEpoch(p.lastSeen), now)}',
                  onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                    builder: (_) => MeasurementDetailPage(
                      monitorId: monitor.id,
                      point: p,
                      sensorId: s,
                    ),
                  )),
                ));
          }
        }
        return SubPage(title: 'Messwerte', children: [
          Text('Rohwerte deiner Sensoren. Antippen zeigt den Verlauf.', style: KwfText.body),
          if (!snap.hasData) const Center(child: CircularProgressIndicator()),
          if (snap.hasData && points.isEmpty)
            const KwfHint('In den letzten 30 Tagen sind keine Messwerte angekommen.'),
          for (final entry in groups.entries) ...[
            KwfKicker(entry.key),
            KwfSection(children: entry.value),
          ],
        ]);
      },
    );
  }
}

enum _Span { day, week }

class MeasurementDetailPage extends StatefulWidget {
  const MeasurementDetailPage({
    super.key,
    required this.monitorId,
    required this.point,
    required this.sensorId,
  });

  final String monitorId;
  final MeteringPoint point;
  final String sensorId;

  @override
  State<MeasurementDetailPage> createState() => _MeasurementDetailPageState();
}

class _MeasurementDetailPageState extends State<MeasurementDetailPage> {
  _Span _span = _Span.day;
  late String _field = _initialField();
  Future<List<TelemetryDataPoint>>? _future;
  bool _showMore = false;

  String _initialField() {
    final preferred = kDefaultField[widget.sensorId];
    if (preferred != null) return preferred;
    return widget.point.valueFields.isNotEmpty ? widget.point.valueFields.first : '';
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= _load();
  }

  Future<List<TelemetryDataPoint>> _load() {
    final now = AppServices.of(context).clock.now();
    final start = now.subtract(_span == _Span.day ? const Duration(hours: 24) : const Duration(days: 7));
    return TelemetryService().fetchTelemetryData(
      deviceId: widget.monitorId,
      meteringPoint: widget.point.meteringPointId,
      sensorId: widget.sensorId,
      startDate: start,
      endDate: now,
    );
  }

  void _setSpan(_Span s) => setState(() {
        _span = s;
        _future = _load();
      });

  @override
  Widget build(BuildContext context) {
    final mp = widget.point.meteringPointId;
    final unit = fieldUnit(_field);
    return SubPage(title: '${pointLabel(mp)} · ${sensorName(widget.sensorId)}', children: [
      FutureBuilder<List<TelemetryDataPoint>>(
        future: _future,
        builder: (context, snap) {
          final points = (snap.data ?? const <TelemetryDataPoint>[])
              .where((p) => p.values.containsKey(_field))
              .toList();
          final last = points.isEmpty ? null : points.last;
          return KwfCard(
            padding: const EdgeInsets.all(KwfSpace.chart),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(fieldLabel(_field), style: KwfText.sectionTitle),
                          Text(
                              '$mp · ${sensorName(widget.sensorId)} · '
                              '${unit.isEmpty ? _field : unit}',
                              style: KwfText.meta),
                        ],
                      ),
                    ),
                    InfoButton(
                      text: InfoTexts.measurements.fill({
                        'sensor': sensorName(widget.sensorId),
                        'mp': mp,
                        'feld': _field,
                      }),
                      stand: last == null
                          ? 'Keine Daten im Zeitraum'
                          : 'Daten bis ${DateFormat('d.M.yyyy, HH:mm').format(DateTime.fromMillisecondsSinceEpoch(last.timestamp))}',
                    ),
                  ],
                ),
                if (last != null)
                  Text('${_fmt(last.values[_field]!)} $unit', style: KwfText.number),
                const SizedBox(height: 12),
                Row(children: [
                  for (final s in _Span.values)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(s == _Span.day ? '24 H' : '7 TAGE'),
                        selected: _span == s,
                        showCheckmark: false,
                        onSelected: (_) => _setSpan(s),
                        labelStyle: KwfText.button.copyWith(
                            color: _span == s ? KwfColors.weiss : KwfColors.anthrazit),
                        selectedColor: KwfColors.gruenDunkel,
                        backgroundColor: KwfColors.weiss,
                        side: const BorderSide(color: KwfColors.feldrand),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(KwfRadius.pill)),
                      ),
                    ),
                ]),
                const SizedBox(height: 12),
                SizedBox(
                  height: 200,
                  child: snap.connectionState != ConnectionState.done
                      ? const Center(child: CircularProgressIndicator())
                      : snap.hasError
                          ? Center(child: Text('Daten konnten nicht geladen werden.', style: KwfText.body))
                          : points.isEmpty
                              ? Center(child: Text('Keine Werte in diesem Zeitraum.', style: KwfText.body))
                              : _Chart(points: points, field: _field, span: _span),
                ),
              ],
            ),
          );
        },
      ),
      if (widget.point.valueFields.length > 1)
        KwfSection(
          title: 'Weitere Werte dieses Sensors',
          trailing: IconButton(
            tooltip: _showMore ? 'Zuklappen' : 'Aufklappen',
            icon: Icon(_showMore ? Icons.expand_less : Icons.expand_more),
            onPressed: () => setState(() => _showMore = !_showMore),
          ),
          children: [
            if (_showMore)
              for (final f in widget.point.valueFields)
                InkWell(
                  onTap: () => setState(() => _field = f),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(fieldLabel(f), style: kwfText(14, weight: FontWeight.w500)),
                              Text(f, style: KwfText.meta),
                            ],
                          ),
                        ),
                        if (f == _field) const Icon(Icons.check, color: KwfColors.gruenDunkel),
                      ],
                    ),
                  ),
                ),
          ],
        ),
    ]);
  }
}

String _fmt(double v) => v.abs() >= 100 ? v.round().toString() : v.toStringAsFixed(1);

class _Chart extends StatelessWidget {
  const _Chart({required this.points, required this.field, required this.span});
  final List<TelemetryDataPoint> points;
  final String field;
  final _Span span;

  @override
  Widget build(BuildContext context) {
    // Bei 7 Tagen jeden n-ten Punkt, damit das Diagramm fluessig bleibt.
    final step = (points.length / 1500).ceil().clamp(1, 1000);
    final spots = <FlSpot>[
      for (var i = 0; i < points.length; i += step)
        FlSpot(points[i].timestamp.toDouble(), points[i].values[field]!),
    ];
    final fmt = DateFormat(span == _Span.day ? 'HH:mm' : 'E', 'de');
    final axis = kwfText(11, weight: FontWeight.w400, color: KwfColors.textSekundaer);
    final minX = spots.first.x;
    final maxX = spots.last.x;
    final interval = span == _Span.day ? 6 * 3600 * 1000.0 : 24 * 3600 * 1000.0;
    return LineChart(LineChartData(
      minX: minX,
      maxX: maxX,
      gridData: FlGridData(
        drawVerticalLine: false,
        getDrawingHorizontalLine: (_) => const FlLine(color: KwfColors.grauHell, strokeWidth: 1),
      ),
      borderData: FlBorderData(
        show: true,
        border: const Border(bottom: BorderSide(color: KwfColors.anthrazit)),
      ),
      titlesData: FlTitlesData(
        topTitles: const AxisTitles(),
        rightTitles: const AxisTitles(),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 40,
            getTitlesWidget: (v, meta) => Text(_fmt(v), style: axis),
          ),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            interval: interval,
            getTitlesWidget: (v, meta) {
              if (v == meta.min || v == meta.max) return const SizedBox.shrink();
              return Text(fmt.format(DateTime.fromMillisecondsSinceEpoch(v.toInt())), style: axis);
            },
          ),
        ),
      ),
      lineTouchData: LineTouchData(
        touchTooltipData: LineTouchTooltipData(
          getTooltipColor: (_) => KwfColors.anthrazit,
          getTooltipItems: (spots) => spots
              .map((s) => LineTooltipItem(
                    '${DateFormat('d.M. HH:mm').format(DateTime.fromMillisecondsSinceEpoch(s.x.toInt()))}\n'
                    '${_fmt(s.y)} ${fieldUnit(field)}',
                    kwfText(12, weight: FontWeight.w500, color: KwfColors.weiss),
                  ))
              .toList(),
        ),
      ),
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          isCurved: false,
          barWidth: 2,
          color: KwfColors.anthrazit,
          dotData: const FlDotData(show: false),
        ),
      ],
    ));
  }
}
