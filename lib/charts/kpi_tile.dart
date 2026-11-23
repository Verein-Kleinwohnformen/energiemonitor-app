// KpiTile und RangeSwitch nach dem Design System (Gruppe Basis).
import 'package:flutter/material.dart';

import '../daily/period.dart';
import '../info/info_overlay.dart';
import '../info/info_texts.dart';
import '../theme/kwf_theme.dart';
import '../theme/kwf_tokens.dart';

/// Kennzahl-Kachel: Zahl, Einheit, Verlauf der letzten Tage, ein Satz Kontext.
class KpiTile extends StatelessWidget {
  const KpiTile({
    super.key,
    required this.label,
    required this.value,
    this.unit,
    this.color = KwfColors.anthrazit,
    this.spark = const [],
    this.context,
    this.trailing,
    this.info,
    this.stand = '',
  });

  final String label;

  /// Zahl als Text, "–" ohne Wert.
  final String value;
  final String? unit;
  final Color color;
  final List<double?> spark;
  final String? context;
  final Widget? trailing;
  final InfoText? info;
  final String stand;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      child: DecoratedBox(
        decoration: const BoxDecoration(color: KwfColors.weiss, boxShadow: KwfShadows.card),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 6, 0, 14),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Info-Symbol oben rechts ueber dem Rand, damit der Titel Platz hat.
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 10, right: 30, bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                  color: color, borderRadius: BorderRadius.circular(2)),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(label,
                                style: kwfText(12, weight: FontWeight.w500),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis),
                          ),
                        ],
                      ),
                    ),
                    if (info != null)
                      Positioned(
                          top: -2, right: -4, child: InfoButton(text: info!, stand: stand)),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 14),
                  child: Text.rich(
                    TextSpan(children: [
                      TextSpan(text: value),
                      if (unit != null)
                        TextSpan(
                          text: ' $unit',
                          style: kwfText(14, weight: FontWeight.w400, color: KwfColors.textSekundaer),
                        ),
                    ]),
                    style: kwfText(34, height: 1.1)
                        .copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
                    maxLines: 1,
                  ),
                ),
                if (spark.whereType<double>().length >= 2) ...[
                  const SizedBox(height: 6),
                  SizedBox(
                    height: 28,
                    width: double.infinity,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 14),
                      child: CustomPaint(painter: _SparkPainter(spark, color)),
                    ),
                  ),
                ],
                if (trailing != null) ...[const SizedBox(height: 6), trailing!],
                if (this.context != null) ...[
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.only(right: 14),
                    child: Text(this.context!, style: KwfText.meta),
                  ),
                ],
              ],
            ),
        ),
      ),
    );
  }
}

class _SparkPainter extends CustomPainter {
  _SparkPainter(this.values, this.color);
  final List<double?> values;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final pts = <Offset>[];
    final known = values.whereType<double>();
    final lo = known.reduce((a, b) => a < b ? a : b);
    final hi = known.reduce((a, b) => a > b ? a : b);
    final span = hi - lo == 0 ? 1 : hi - lo;
    final step = values.length > 1 ? (size.width - 4) / (values.length - 1) : 0.0;
    for (var i = 0; i < values.length; i++) {
      final v = values[i];
      if (v == null) continue;
      pts.add(Offset(2 + i * step, 3 + (size.height - 6) * (1 - (v - lo) / span)));
    }
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (final p in pts.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round);
    canvas.drawCircle(pts.last, 4, Paint()..color = KwfColors.weiss);
    canvas.drawCircle(pts.last, 2.5, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_SparkPainter old) => old.values != values || old.color != color;
}

/// Zeitraum-Umschalter: Pillengruppe, darunter der Schritt vor und zurueck.
class RangeSwitch extends StatelessWidget {
  const RangeSwitch({super.key, required this.period, required this.onChanged});
  final Period period;
  final ValueChanged<Period> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<RangeKind>(
          key: const ValueKey('range-switch'),
          showSelectedIcon: false,
          segments: [
            for (final k in RangeKind.values)
              ButtonSegment(value: k, label: Text(k.label.toUpperCase())),
          ],
          selected: {period.kind},
          onSelectionChanged: (s) =>
              onChanged(Period.of(s.first, period.today, today: period.today)),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            IconButton(
              key: const ValueKey('range-prev'),
              tooltip: 'Vorheriger Zeitraum',
              onPressed: () => onChanged(period.previous()),
              icon: const Icon(Icons.chevron_left),
            ),
            Expanded(
              child: Text(
                period.label + (period.isCurrent ? ', bis heute' : ''),
                textAlign: TextAlign.center,
                style: kwfText(13, weight: FontWeight.w500),
              ),
            ),
            IconButton(
              key: const ValueKey('range-next'),
              tooltip: 'Nächster Zeitraum',
              onPressed: period.hasNext ? () => onChanged(period.next()) : null,
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
      ],
    );
  }
}
