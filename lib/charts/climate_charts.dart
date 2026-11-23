// Klima-Diagramme nach dem Design System (Gruppe Klima und Auswertung):
// ClimateTile, ComfortZone, Co2Heatmap.
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../daily/summary.dart';
import '../theme/kwf_theme.dart';
import '../theme/kwf_tokens.dart';
import 'chart_basics.dart';

/// Klimawert mit Zahl, Status als Wort und Skala.
class ClimateTile extends StatelessWidget {
  const ClimateTile({
    super.key,
    required this.label,
    required this.value,
    required this.unit,
    required this.level,
    required this.word,
    required this.scale,
    this.range,
  });

  final String label;
  final double value;
  final String unit;
  final ComfortLevel level;
  final String word;

  /// Skala: (von, bis, Stufe) aufsteigend.
  final List<(double, double, ComfortLevel)> scale;

  /// "Bereich 19 bis 29 °C"
  final String? range;

  @override
  Widget build(BuildContext context) {
    final lo = scale.first.$1;
    final hi = scale.last.$2;
    final digits = unit == 'ppm' ? 0 : 1;
    return Semantics(
      label: '$label ${fmtNum(value, digits: digits)} $unit, $word',
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: kwfText(12, weight: FontWeight.w500)),
            const SizedBox(height: 2),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(fmtNum(value, digits: digits), style: kwfText(24, height: 1.1)),
                const SizedBox(width: 3),
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(unit, style: KwfText.meta),
                ),
              ],
            ),
            const SizedBox(height: 4),
            ComfortBadge(level, word),
            const SizedBox(height: 8),
            LayoutBuilder(builder: (context, c) {
              final w = c.maxWidth;
              final x = ((value - lo) / (hi - lo)).clamp(0.0, 1.0) * w;
              return SizedBox(
                height: 14,
                child: Stack(clipBehavior: Clip.none, children: [
                  Positioned(
                    top: 4,
                    left: 0,
                    right: 0,
                    child: Row(children: [
                      for (final (i, s) in scale.indexed) ...[
                        if (i > 0) const SizedBox(width: KwfSpace.markGap),
                        Expanded(
                          flex: math.max(1, ((s.$2 - s.$1) * 10).round()),
                          child: Container(height: 6, color: ComfortBadge.colorOf(s.$3)),
                        ),
                      ],
                    ]),
                  ),
                  Positioned(
                    left: x - 1,
                    top: 0,
                    child: Container(width: 2, height: 14, color: KwfColors.anthrazit),
                  ),
                ]),
              );
            }),
            if (range != null) ...[
              const SizedBox(height: 4),
              Text(range!, style: KwfText.meta),
            ],
          ],
        ),
      ),
    );
  }
}

/// Skalen fuer die Kacheln (Grenzen aus [Comfort]).
const kTempScale = [
  (14.0, Comfort.tMin, ComfortLevel.mid),
  (Comfort.tMin, Comfort.tMax, ComfortLevel.good),
  (Comfort.tMax, 32.0, ComfortLevel.mid),
];
const kRhScale = [
  (15.0, Comfort.rhMin, ComfortLevel.mid),
  (Comfort.rhMin, Comfort.rhMax, ComfortLevel.good),
  (Comfort.rhMax, Comfort.rhBad, ComfortLevel.mid),
  (Comfort.rhBad, 85.0, ComfortLevel.bad),
];
const kCo2Scale = [
  (400.0, Comfort.co2Good, ComfortLevel.good),
  (Comfort.co2Good, Comfort.co2Mid, ComfortLevel.mid),
  (Comfort.co2Mid, 2200.0, ComfortLevel.bad),
];

String temperatureWord(ComfortLevel l) => l == ComfortLevel.good ? 'Behaglich' : 'Ausserhalb';
String humidityWord(ComfortLevel l) => switch (l) {
      ComfortLevel.good => 'Gut',
      ComfortLevel.mid => 'Grenzwertig',
      ComfortLevel.bad => 'Zu feucht',
    };
String co2Word(ComfortLevel l) => switch (l) {
      ComfortLevel.good => 'Frisch',
      ComfortLevel.mid => 'Mittel',
      ComfortLevel.bad => 'Lüften',
    };

/// Temperatur gegen Feuchte, ein Punkt pro Tag, mit Behaglichkeitsfeld.
class ComfortZone extends StatelessWidget {
  const ComfortZone({super.key, required this.points});
  final List<(double, double)> points;

  static const tLo = 12.0, tHi = 34.0, rhLo = 20.0, rhHi = 80.0;

  @override
  Widget build(BuildContext context) {
    final inField = points
        .where((p) =>
            p.$1 >= Comfort.tMin &&
            p.$1 <= Comfort.tMax &&
            p.$2 >= Comfort.rhMin &&
            p.$2 <= Comfort.rhMax)
        .length;
    final share = points.isEmpty ? 0.0 : inField / points.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          label: 'Streudiagramm Temperatur gegen Feuchte, ${fmtPct(share)} der Tage im Feld',
          child: AspectRatio(
            aspectRatio: 1.5,
            child: CustomPaint(painter: _ComfortPainter(points)),
          ),
        ),
        const SizedBox(height: 8),
        Text(
            '${fmtPct(share)} der Tage im Feld '
            '(${fmtNum(Comfort.tMin, digits: 0)} bis ${fmtNum(Comfort.tMax, digits: 0)} °C, '
            '${fmtNum(Comfort.rhMin, digits: 0)} bis ${fmtNum(Comfort.rhMax, digits: 0)} % Feuchte).',
            style: KwfText.small),
      ],
    );
  }
}

class _ComfortPainter extends CustomPainter {
  _ComfortPainter(this.points);
  final List<(double, double)> points;

  @override
  void paint(Canvas canvas, Size size) {
    const left = 30.0, bottom = 20.0;
    final w = size.width - left, h = size.height - bottom;
    Offset at(double t, double rh) => Offset(
          left + (t - ComfortZone.tLo) / (ComfortZone.tHi - ComfortZone.tLo) * w,
          h - (rh - ComfortZone.rhLo) / (ComfortZone.rhHi - ComfortZone.rhLo) * h,
        );
    final grid = Paint()
      ..color = KwfColors.grauHell
      ..strokeWidth = 1;
    void label(String s, Offset o, {bool right = false}) {
      final tp = TextPainter(
          text: TextSpan(text: s, style: kAxisStyle), textDirection: TextDirection.ltr)
        ..layout();
      tp.paint(canvas, right ? o - Offset(tp.width, tp.height / 2) : o - Offset(tp.width / 2, 0));
    }

    for (var rh = 20.0; rh <= 80; rh += 20) {
      final y = at(ComfortZone.tLo, rh).dy;
      canvas.drawLine(Offset(left, y), Offset(size.width, y), grid);
      label('${rh.toInt()} %', Offset(left - 4, y), right: true);
    }
    for (var t = 15.0; t <= 33; t += 5) {
      label('${t.toInt()} °C', Offset(at(t, 20).dx, h + 4));
    }
    canvas.drawLine(Offset(left, h), Offset(size.width, h), Paint()..color = KwfColors.anthrazit);

    final field = Rect.fromPoints(at(Comfort.tMin, Comfort.rhMax), at(Comfort.tMax, Comfort.rhMin));
    canvas.drawRect(field, Paint()..color = KwfColors.gruen.withValues(alpha: 0.16));
    final dash = Paint()
      ..color = KwfColors.gruenDunkel
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    _dashedRect(canvas, field, dash);
    final tp = TextPainter(
        text: TextSpan(text: 'behaglich', style: kwfText(11, weight: FontWeight.w600, color: KwfColors.gruenDunkel)),
        textDirection: TextDirection.ltr)
      ..layout();
    tp.paint(canvas, field.topLeft + const Offset(4, 3));

    final dot = Paint()..color = KwfColors.klimaInnen.withValues(alpha: 0.55);
    for (final p in points) {
      final o = at(p.$1.clamp(ComfortZone.tLo, ComfortZone.tHi), p.$2.clamp(ComfortZone.rhLo, ComfortZone.rhHi));
      canvas.drawCircle(o, 3.5, dot);
    }
  }

  void _dashedRect(Canvas canvas, Rect r, Paint p) {
    void line(Offset a, Offset b) {
      final len = (b - a).distance;
      final dir = (b - a) / len;
      for (var d = 0.0; d < len; d += 7) {
        canvas.drawLine(a + dir * d, a + dir * math.min(d + 4, len), p);
      }
    }

    line(r.topLeft, r.topRight);
    line(r.topRight, r.bottomRight);
    line(r.bottomRight, r.bottomLeft);
    line(r.bottomLeft, r.topLeft);
  }

  @override
  bool shouldRepaint(_ComfortPainter old) => old.points != points;
}

/// Heatmap Wochentag x Stunde mit dem CO2-Median, blaue Skala in 7 Stufen.
class Co2Heatmap extends StatefulWidget {
  const Co2Heatmap({super.key, required this.cells});

  /// 7 Zeilen (Montag zuerst) mit 24 Werten in ppm, null ohne Daten.
  final List<List<double?>> cells;

  static const lo = 400.0, hi = 2000.0;
  static const steps = [
    KwfColors.seq100,
    KwfColors.seq200,
    KwfColors.seq300,
    KwfColors.seq400,
    KwfColors.seq500,
    KwfColors.seq600,
    KwfColors.seq700,
  ];

  static Color colorOf(double ppm) {
    final i = ((ppm - lo) / (hi - lo) * steps.length).floor().clamp(0, steps.length - 1);
    return steps[i];
  }

  @override
  State<Co2Heatmap> createState() => _Co2HeatmapState();
}

class _Co2HeatmapState extends State<Co2Heatmap> {
  (int, int)? _sel;
  static const _days = ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];

  @override
  Widget build(BuildContext context) {
    final sel = _sel;
    final selValue = sel == null ? null : widget.cells[sel.$1][sel.$2];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(builder: (context, c) {
          const labelW = 24.0;
          final cell = (c.maxWidth - labelW) / 24;
          return Column(children: [
            for (var d = 0; d < 7; d++)
              Row(children: [
                SizedBox(width: labelW, child: Text(_days[d], style: kAxisStyle)),
                for (var h = 0; h < 24; h++)
                  GestureDetector(
                    key: ValueKey('co2-cell-$d-$h'),
                    onTap: () => setState(() => _sel = (d, h)),
                    child: Container(
                      width: cell,
                      height: math.min(22, cell + 6),
                      padding: const EdgeInsets.all(1),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: widget.cells[d][h] == null
                              ? KwfColors.weiss
                              : Co2Heatmap.colorOf(widget.cells[d][h]!),
                          border: sel == (d, h)
                              ? Border.all(color: KwfColors.anthrazit, width: 2)
                              : (widget.cells[d][h] == null
                                  ? Border.all(color: KwfColors.grauHell)
                                  : null),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
              ]),
            Row(children: [
              const SizedBox(width: labelW),
              for (final h in [0, 6, 12, 18])
                SizedBox(
                    width: cell * 6, child: Text('$h Uhr', style: kAxisStyle)),
            ]),
          ]);
        }),
        const SizedBox(height: 8),
        Row(children: [
          Text('${Co2Heatmap.lo.toInt()} ppm', style: kAxisStyle),
          const SizedBox(width: 6),
          Expanded(
            child: Container(
              height: 8,
              decoration: const BoxDecoration(
                  gradient: LinearGradient(colors: Co2Heatmap.steps),
                  borderRadius: BorderRadius.all(Radius.circular(2))),
            ),
          ),
          const SizedBox(width: 6),
          Text("2'000 ppm", style: kAxisStyle),
        ]),
        if (sel != null) ...[
          const SizedBox(height: 8),
          Container(
            color: KwfColors.anthrazit,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Text(
              selValue == null
                  ? '${_days[sel.$1]}, ${sel.$2} bis ${sel.$2 + 1} Uhr: keine Daten'
                  : '${_days[sel.$1]}, ${sel.$2} bis ${sel.$2 + 1} Uhr: '
                      '${fmtNum(selValue, digits: 0)} ppm (Median)',
              style: kTipStyle,
            ),
          ),
        ],
      ],
    );
  }
}
