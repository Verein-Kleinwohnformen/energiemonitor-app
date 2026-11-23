// Energie-Diagramme nach dem Design System (Gruppe Energie und Auswertung):
// gestapelte Balken pro Tag oder Monat, Energiemix als Ring, Eigenversorgung,
// Watt pro Person im Vergleich.
import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../daily/summary.dart';
import '../theme/kwf_theme.dart';
import '../theme/kwf_tokens.dart';
import 'chart_basics.dart';

/// Ein Balken: Datum, kWh pro Traeger, geschaetzte Traeger.
class BarValue {
  const BarValue(this.date, this.kwh, {this.estimated = const {}, this.note});
  final DateTime date;
  final Map<Carrier, double> kwh;
  final Set<Carrier> estimated;

  /// Zusatz im Tooltip, z.B. "Daten lückenhaft".
  final String? note;

  double get total => kwh.values.fold(0.0, (a, b) => a + b);
}

/// Gestapelte Balken nach Traeger. Geschaetzte Brennstoffe als aufgehellte
/// Flaeche mit Rand. Antippen zeigt alle Werte der Spalte.
class StackedBars extends StatelessWidget {
  const StackedBars({
    super.key,
    required this.bars,
    required this.labelOf,
    required this.tooltipDate,
    this.carriers = Carrier.values,
    this.height = 180,
    this.labelEvery = 1,
    this.unit = 'kWh',
  });

  final List<BarValue> bars;
  final String Function(DateTime) labelOf;
  final String Function(DateTime) tooltipDate;
  final List<Carrier> carriers;
  final double height;
  final int labelEvery;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final maxY = bars.fold(0.0, (a, b) => math.max(a, b.total));
    final top = _niceMax(maxY);
    return LayoutBuilder(builder: (context, c) {
      final slot = (c.maxWidth - 36) / math.max(1, bars.length);
      final width = math.min(18.0, math.max(3.0, slot - KwfSpace.markGap * 2));
      return Semantics(
        label: 'Balkendiagramm, höchster Wert ${fmtKwh(maxY)} $unit',
        child: SizedBox(
          height: height,
          child: BarChart(
            BarChartData(
              maxY: top,
              minY: 0,
              alignment: BarChartAlignment.spaceAround,
              barGroups: [
                for (var i = 0; i < bars.length; i++)
                  BarChartGroupData(x: i, barRods: [_rod(bars[i], width)]),
              ],
              gridData: FlGridData(
                drawVerticalLine: false,
                horizontalInterval: top / 4,
                getDrawingHorizontalLine: (_) =>
                    const FlLine(color: KwfColors.grauHell, strokeWidth: 1),
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
                    reservedSize: 32,
                    interval: top / 4,
                    getTitlesWidget: (v, meta) => v == meta.max && v != 0
                        ? Text(unit, style: kAxisStyle)
                        : Text(fmtNum(v, digits: (top / 4) % 1 == 0 ? 0 : 1), style: kAxisStyle),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 22,
                    getTitlesWidget: (v, meta) {
                      final i = v.toInt();
                      if (i < 0 || i >= bars.length || i % labelEvery != 0) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(labelOf(bars[i].date), style: kAxisStyle),
                      );
                    },
                  ),
                ),
              ),
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (_) => KwfColors.anthrazit,
                  fitInsideHorizontally: true,
                  fitInsideVertically: true,
                  getTooltipItem: (group, _, __, ___) {
                    final b = bars[group.x];
                    final lines = [
                      tooltipDate(b.date),
                      for (final c in carriers)
                        if (b.kwh[c] != null)
                          '${c.label}: ${fmtKwh(b.kwh[c]!)} $unit'
                              '${b.estimated.contains(c) ? ' (geschätzt)' : ''}',
                      'Total: ${fmtKwh(b.total)} $unit',
                      if (b.note != null) b.note!,
                    ];
                    return BarTooltipItem(lines.join('\n'), kTipStyle,
                        textAlign: TextAlign.left);
                  },
                ),
              ),
            ),
          ),
        ),
      );
    });
  }

  BarChartRodData _rod(BarValue b, double width) {
    var from = 0.0;
    final items = <BarChartRodStackItem>[];
    for (final c in carriers) {
      final v = b.kwh[c];
      if (v == null || v <= 0) continue;
      final est = b.estimated.contains(c);
      items.add(BarChartRodStackItem(
        from,
        from + v,
        est ? estimatedColor(c.color) : c.color,
        est ? BorderSide(color: c.color, width: 1.2) : const BorderSide(color: KwfColors.weiss, width: 0.5),
      ));
      from += v;
    }
    return BarChartRodData(
      toY: from,
      width: width,
      color: Colors.transparent,
      rodStackItems: items,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(KwfRadius.bar)),
    );
  }
}

/// Runde Obergrenze der Y-Achse (1, 2, 2.5, 5 mal 10^n).
double _niceMax(double v) {
  if (v <= 0) return 1;
  final exp = math.pow(10, (math.log(v) / math.ln10).floor()).toDouble();
  for (final m in [1.0, 2.0, 2.5, 5.0, 10.0]) {
    if (m * exp >= v) return m * exp;
  }
  return 10 * exp;
}

final kDayLabel = DateFormat('E', 'de');
final kDayDate = DateFormat('EEEE d.M.', 'de');
final kMonthLabel = DateFormat('MMM', 'de');
final kMonthDate = DateFormat('MMMM yyyy', 'de');

/// Energiemix als Ring mit der Summe in der Mitte, direkt beschriftet.
class EnergyMixDonut extends StatelessWidget {
  const EnergyMixDonut({super.key, required this.kwh, this.estimated = const {}});
  final Map<Carrier, double> kwh;
  final Set<Carrier> estimated;

  @override
  Widget build(BuildContext context) {
    final total = kwh.values.fold(0.0, (a, b) => a + b);
    if (total <= 0) return const ChartEmpty('Keine Energie im Zeitraum.');
    // Anteile unter 2 % als "Übrige" (bleiben in der Liste, ohne eigenes Stück).
    final big = {
      for (final e in kwh.entries)
        if (e.value / total >= 0.02) e.key: e.value,
    };
    final rest = total - big.values.fold(0.0, (a, b) => a + b);
    return LayoutBuilder(builder: (context, c) {
      final size = math.min(150.0, c.maxWidth * 0.42);
      return Row(
        children: [
          SizedBox(
            width: size,
            height: size,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(PieChartData(
                  startDegreeOffset: -90,
                  sectionsSpace: KwfSpace.markGap,
                  centerSpaceRadius: size / 2 * 2 / 3,
                  sections: [
                    for (final e in big.entries)
                      PieChartSectionData(
                        value: e.value,
                        color: estimated.contains(e.key) ? estimatedColor(e.key.color) : e.key.color,
                        borderSide: estimated.contains(e.key)
                            ? BorderSide(color: e.key.color, width: 1.2)
                            : BorderSide.none,
                        radius: size / 2 / 3,
                        showTitle: false,
                      ),
                    if (rest > 0)
                      PieChartSectionData(
                          value: rest, color: KwfColors.grau, radius: size / 2 / 3, showTitle: false),
                  ],
                )),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(fmtKwh(total), style: kwfText(20)),
                    Text('kWh', style: KwfText.meta),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final c in Carrier.values)
                  if (big[c] != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(children: [
                        CarrierSwatch(c, estimated: estimated.contains(c)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                              '${c.label}${estimated.contains(c) ? ', geschätzt' : ''}',
                              style: kwfText(13, weight: FontWeight.w400)),
                        ),
                        Text(fmtPct(big[c]! / total), style: kwfText(13, weight: FontWeight.w600)),
                      ]),
                    ),
                if (rest > 0)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(children: [
                      Container(width: 10, height: 10, color: KwfColors.grau),
                      const SizedBox(width: 8),
                      Expanded(child: Text('Übrige', style: kwfText(13, weight: FontWeight.w400))),
                      Text(fmtPct(rest / total), style: kwfText(13, weight: FontWeight.w600)),
                    ]),
                  ),
              ],
            ),
          ),
        ],
      );
    });
  }
}

/// Zwei Ringe: aussen Eigenversorgung, innen Eigenverbrauch, je mit Satz.
class AutarkyRing extends StatelessWidget {
  const AutarkyRing({super.key, required this.autarky, this.selfConsumption});
  final double autarky;
  final double? selfConsumption;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Semantics(
          label: 'Eigenversorgung ${fmtPct(autarky)}',
          child: SizedBox(
            width: 96,
            height: 96,
            child: CustomPaint(
              painter: _RingPainter(autarky, selfConsumption),
              child: Center(
                child: Text(fmtPct(autarky), style: kwfText(18, weight: FontWeight.w400)),
              ),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text.rich(TextSpan(children: [
                TextSpan(
                    text: 'Eigenversorgung ${fmtPct(autarky)}: ',
                    style: kwfText(13, weight: FontWeight.w600)),
                const TextSpan(text: 'so viel eures Stroms kam von der eigenen Sonne.'),
              ]), style: KwfText.small),
              if (selfConsumption != null) ...[
                const SizedBox(height: 8),
                Text.rich(TextSpan(children: [
                  TextSpan(
                      text: 'Eigenverbrauch ${fmtPct(selfConsumption!)}: ',
                      style: kwfText(13, weight: FontWeight.w600)),
                  const TextSpan(text: 'so viel des Solarstroms habt ihr selbst genutzt.'),
                ]), style: KwfText.small),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.outer, this.inner);
  final double outer;
  final double? inner;

  @override
  void paint(Canvas canvas, Size size) {
    void ring(double radius, double share, Color color) {
      final rect = Rect.fromCircle(center: size.center(Offset.zero), radius: radius);
      final track = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8
        ..color = KwfColors.grauHell;
      canvas.drawArc(rect, 0, 2 * math.pi, false, track);
      canvas.drawArc(
          rect,
          -math.pi / 2,
          2 * math.pi * share.clamp(0, 1),
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 8
            ..strokeCap = StrokeCap.round
            ..color = color);
    }

    ring(size.width / 2 - 4, outer, KwfColors.dataSolar);
    if (inner != null) ring(size.width / 2 - 15, inner!, KwfColors.limette);
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.outer != outer || old.inner != inner;
}

/// Eine Zeile im Vergleich Watt pro Person.
class BenchmarkRow {
  const BenchmarkRow(this.label, this.sub, this.watts, {this.own = false});
  final String label;
  final String sub;
  final double watts;
  final bool own;
}

/// Horizontale Balken in Watt Dauerleistung pro Person. Der eigene Wert in
/// gruen, Vergleichswerte neutral.
class PerPersonBenchmark extends StatelessWidget {
  const PerPersonBenchmark({super.key, required this.rows, this.scaleMax});
  final List<BenchmarkRow> rows;

  /// Gemeinsame Skala fuer mehrere Bloecke.
  final double? scaleMax;

  @override
  Widget build(BuildContext context) {
    final double max = scaleMax ?? rows.fold<double>(1.0, (a, r) => math.max(a, r.watts));
    return Column(
      children: [
        for (final r in rows)
          Semantics(
            label: '${r.label}: ${fmtNum(r.watts, digits: 0)} Watt pro Person, ${r.sub}',
            child: ExcludeSemantics(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(r.label, style: kwfText(13, weight: FontWeight.w600)),
                    Text(r.sub, style: KwfText.meta),
                    const SizedBox(height: 4),
                    LayoutBuilder(builder: (context, c) {
                      final w = (c.maxWidth - 70) * (r.watts / max).clamp(0.0, 1.0);
                      return Row(children: [
                        Container(
                          width: math.max(2, w),
                          height: 18,
                          decoration: BoxDecoration(
                            color: r.own ? KwfColors.gruen : KwfColors.grau,
                            borderRadius: const BorderRadius.horizontal(
                                right: Radius.circular(KwfRadius.bar)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text('${fmtNum(r.watts, digits: 0)} W',
                            style: kwfText(13, weight: FontWeight.w600)),
                      ]);
                    }),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
