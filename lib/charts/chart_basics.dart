// Gemeinsame Teile der Diagramme: Zahlen, Diagramm-Karte, Legende.
// Nach dem Design System des Vereins, Abschnitt Energiemonitor-App
// (Energiemonitor.md, ChartLegend).
import 'package:flutter/material.dart';

import '../daily/summary.dart';
import '../info/info_overlay.dart';
import '../info/info_texts.dart';
import '../theme/kwf_theme.dart';
import '../theme/kwf_tokens.dart';

/// Zahl in Schweizer Schreibweise: Punkt als Dezimalzeichen, Apostroph als
/// Tausendertrennung ("1'300", "4.2").
String fmtNum(double v, {int digits = 1}) {
  final neg = v < 0;
  var s = v.abs().toStringAsFixed(digits);
  if (s.contains('.')) s = s.replaceFirst(RegExp(r'\.?0+$'), '');
  final parts = s.split('.');
  final buf = StringBuffer();
  final whole = parts[0];
  for (var i = 0; i < whole.length; i++) {
    if (i > 0 && (whole.length - i) % 3 == 0) buf.write("'");
    buf.write(whole[i]);
  }
  if (parts.length > 1) buf.write('.${parts[1]}');
  return '${neg ? '-' : ''}$buf';
}

/// kWh mit sinnvoller Genauigkeit: unter 10 eine Stelle, sonst ganze.
String fmtKwh(double v) => fmtNum(v, digits: v.abs() < 10 ? 1 : 0);

String fmtPct(double share) => '${fmtNum(share * 100, digits: 0)} %';

final kAxisStyle = kwfText(11, weight: FontWeight.w400, color: KwfColors.textSekundaer);
final kTipStyle = kwfText(12, weight: FontWeight.w500, color: KwfColors.weiss);

/// Diagramm-Karte: Aussage als Satz im Titel, Einheit und Zeitraum in der
/// Unterzeile, Info-Symbol rechts.
class ChartCard extends StatelessWidget {
  const ChartCard({
    super.key,
    required this.title,
    this.subtitle,
    this.info,
    this.stand = '',
    required this.child,
  });

  final String title;
  final String? subtitle;
  final InfoText? info;
  final String stand;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(color: KwfColors.weiss, boxShadow: KwfShadows.card),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(KwfSpace.chart, 12, 4, KwfSpace.chart),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Semantics(header: true, child: Text(title, style: KwfText.sectionTitle)),
                        if (subtitle != null) ...[
                          const SizedBox(height: 2),
                          Text(subtitle!, style: KwfText.meta),
                        ],
                      ],
                    ),
                  ),
                ),
                if (info != null) InfoButton(text: info!, stand: stand),
              ],
            ),
            const SizedBox(height: 12),
            Padding(padding: const EdgeInsets.only(right: KwfSpace.chart - 4), child: child),
          ],
        ),
      ),
    );
  }
}

/// Legende in der festen Reihenfolge der Traeger. Geschaetzte Traeger
/// erscheinen als hellere Flaeche mit Rand und dem Wort "geschätzt".
class ChartLegend extends StatelessWidget {
  const ChartLegend({super.key, required this.carriers, this.estimated = const {}});
  final Iterable<Carrier> carriers;
  final Set<Carrier> estimated;

  @override
  Widget build(BuildContext context) {
    final list = [for (final c in Carrier.values) if (carriers.contains(c)) c];
    return Wrap(
      spacing: 14,
      runSpacing: 6,
      children: [
        for (final c in list)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CarrierSwatch(c, estimated: estimated.contains(c)),
              const SizedBox(width: 6),
              Text(estimated.contains(c) ? '${c.label}, geschätzt' : c.label,
                  style: kwfText(12, weight: FontWeight.w400)),
            ],
          ),
      ],
    );
  }
}

class CarrierSwatch extends StatelessWidget {
  const CarrierSwatch(this.carrier, {super.key, this.estimated = false, this.size = 10});
  final Carrier carrier;
  final bool estimated;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: estimated ? estimatedColor(carrier.color) : carrier.color,
          border: estimated ? Border.all(color: carrier.color, width: 1.5) : null,
          borderRadius: BorderRadius.circular(2),
        ),
      );
}

/// Flaeche fuer geschaetzte Werte: Traegerfarbe aufgehellt, mit Rand.
Color estimatedColor(Color c) => Color.lerp(c, KwfColors.weiss, 0.55)!;

/// Ruhiger Satz statt Diagramm, wenn Daten fehlen.
class ChartEmpty extends StatelessWidget {
  const ChartEmpty(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(text, style: KwfText.small.copyWith(color: KwfColors.textSekundaer)),
      );
}

/// Status als Punkt und Wort.
class ComfortBadge extends StatelessWidget {
  const ComfortBadge(this.level, this.word, {super.key});
  final ComfortLevel level;
  final String word;

  static Color colorOf(ComfortLevel l) => switch (l) {
        ComfortLevel.good => KwfColors.komfortGut,
        ComfortLevel.mid => KwfColors.komfortMittel,
        ComfortLevel.bad => KwfColors.komfortSchlecht,
      };

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            switch (level) {
              ComfortLevel.good => Icons.check_circle_outline,
              ComfortLevel.mid => Icons.remove_circle_outline,
              ComfortLevel.bad => Icons.error_outline,
            },
            size: 14,
            color: colorOf(level),
          ),
          const SizedBox(width: 4),
          Text(word, style: kwfText(12, weight: FontWeight.w500)),
        ],
      );
}
