// Mess-Schema nach Messkonzept v1.0 (Minergie-Modul Monitoring): welche
// Messpunkte das Haus hat, ob Daten ankommen und was noch fehlt. Zeigt nie
// einen Messwert, darum auch im Studienmodus sichtbar (wie der Systemstatus).
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app/services.dart';
import '../app/session_scope.dart';
import '../info/info_overlay.dart';
import '../info/info_texts.dart';
import '../metering_point.dart';
import '../status/measurement_schema.dart';
import '../status/system_status.dart';
import '../theme/kwf_theme.dart';
import '../theme/kwf_tokens.dart';
import '../theme/kwf_widgets.dart';
import 'sub_page.dart';

final _dmy = DateFormat('d.M.yyyy');

class SchemaPage extends StatefulWidget {
  const SchemaPage({super.key});

  @override
  State<SchemaPage> createState() => _SchemaPageState();
}

class _SchemaPageState extends State<SchemaPage> {
  Future<List<ManualEntry>>? _entries;
  String? _loadedFor;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final id = SessionScope.of(context).active?.id;
    if (id != _loadedFor) {
      _loadedFor = id;
      final services = AppServices.of(context);
      _entries = id == null
          ? Future.value(const [])
          : services.entries.load(id, currentYear: services.clock.now().year);
    }
  }

  @override
  Widget build(BuildContext context) {
    final services = AppServices.of(context);
    final id = _loadedFor;
    if (id == null) {
      return const SubPage(title: 'Mess-Schema', children: [KwfHint('Kein Monitor gewählt.')]);
    }
    return FutureBuilder<List<ManualEntry>>(
      future: _entries,
      builder: (context, entriesSnap) => StreamBuilder<List<MeteringPoint>>(
        stream: services.status.watch(id),
        builder: (context, pointsSnap) {
          final loading = !pointsSnap.hasData ||
              entriesSnap.connectionState != ConnectionState.done;
          if (loading) {
            return const SubPage(
                title: 'Mess-Schema',
                children: [Center(child: CircularProgressIndicator())]);
          }
          final now = services.clock.now();
          final schema = evaluateSchema(
            points: pointsSnap.data!,
            entries: entriesSnap.data ?? const [],
            now: now,
          );
          return SchemaView(schema: schema, now: now);
        },
      ),
    );
  }
}

/// Inhalt der Seite, ohne Laden. Fuer Tests direkt renderbar.
class SchemaView extends StatelessWidget {
  const SchemaView({super.key, required this.schema, required this.now});
  final MeasurementSchema schema;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final warnings = schema.warnings;
    final other = schema.inGroup(SchemaGroup.other);
    return SubPage(
      title: 'Mess-Schema',
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Expanded(
              child: KwfPageHeading('Dein Mess-Schema',
                  intro: 'Welche Messpunkte dein Haus nach dem Messkonzept hat und ob Daten '
                      'ankommen. Es zeigt keine Messwerte.'),
            ),
            InfoButton(text: InfoTexts.schema, stand: 'Stand ${formatTime(now, now)}'),
          ],
        ),
        if (warnings.isEmpty)
          const KwfHint('Heizwärme, Warmwasser und Wohnklima sind abgedeckt.',
              icon: Icons.check_circle_outline)
        else
          for (final w in warnings) _Warning(w.warning!),
        if (warnings.isNotEmpty)
          const KwfHint(
              'Die Prüfung kennt nur, was dein Monitor und deine Einträge zeigen. Misst ein '
              'anderes Gerät mit, das nicht angeschlossen ist, sehen wir das nicht. Fehlt '
              'etwas, schreib uns: energiemonitor@kleinwohnformen.ch'),
        const _Legend(),
        _GroupCard(
          group: SchemaGroup.boundary,
          points: schema.inGroup(SchemaGroup.boundary),
          now: now,
        ),
        _House(children: [
          for (final g in const [SchemaGroup.consumers, SchemaGroup.comfort, SchemaGroup.water])
            _GroupBlock(group: g, points: schema.inGroup(g), now: now),
        ]),
        if (other.isNotEmpty) _GroupCard(group: SchemaGroup.other, points: other, now: now),
        Text(
            'Messkonzept v1.0 des Vereins Kleinwohnformen nach dem Minergie-Modul Monitoring. '
            'Pro Haus gibt es ein eigenes Schema mit den Punkten, die es braucht.',
            style: KwfText.meta),
      ],
    );
  }
}

class _Warning extends StatelessWidget {
  const _Warning(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: KwfColors.weiss,
        border: Border(left: BorderSide(color: KwfColors.komfortMittel, width: 4)),
        boxShadow: KwfShadows.card,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded, size: 20, color: KwfColors.komfortMittel),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: KwfText.small)),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    Widget item(Color c, String t) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [KwfStatusDot(c), const SizedBox(width: 5), Text(t, style: KwfText.meta)],
        );
    return Wrap(
      spacing: 14,
      runSpacing: 4,
      children: [
        item(coverageColor(PointCoverage.online), 'online'),
        item(coverageColor(PointCoverage.delayed), 'verzögert'),
        item(coverageColor(PointCoverage.offline), 'offline'),
        item(coverageColor(PointCoverage.entries), 'deine Einträge'),
        item(coverageColor(PointCoverage.missing), 'nicht gemessen'),
      ],
    );
  }
}

Color coverageColor(PointCoverage c) => switch (c) {
      PointCoverage.online || PointCoverage.entries => KwfColors.komfortGut,
      PointCoverage.delayed => KwfColors.komfortMittel,
      PointCoverage.offline || PointCoverage.stale => KwfColors.komfortSchlecht,
      PointCoverage.missing => KwfColors.grau,
    };

/// Farbe der Kachel wie im Messkonzept: E gruen, M rot, I gelb, A grau,
/// K violett, D blau.
Color slotColor(String id) {
  final category = switch (id.isEmpty ? '' : id[0]) {
    'E' => MeteringPointCategory.external,
    'I' => MeteringPointCategory.internal,
    'M' => MeteringPointCategory.material,
    'K' => MeteringPointCategory.comfort,
    'D' => MeteringPointCategory.water,
    'A' => MeteringPointCategory.other,
    _ => MeteringPointCategory.undefined,
  };
  return MeteringPointDefinitions.getCategoryColor(category);
}

/// Gruppe ausserhalb des Hauses (Systemgrenze, weitere Punkte).
class _GroupCard extends StatelessWidget {
  const _GroupCard({required this.group, required this.points, required this.now});
  final SchemaGroup group;
  final List<SchemaPoint> points;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    return KwfCard(child: _GroupBlock(group: group, points: points, now: now));
  }
}

class _GroupBlock extends StatelessWidget {
  const _GroupBlock({required this.group, required this.points, required this.now});
  final SchemaGroup group;
  final List<SchemaPoint> points;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(header: true, child: KwfKicker(group.title)),
        const SizedBox(height: 8),
        LayoutBuilder(builder: (context, c) {
          final w = c.maxWidth;
          final cols = w < 560 ? 2 : (w < 900 ? 3 : 4);
          const gap = 8.0;
          final tileW = (w - gap * (cols - 1)) / cols;
          return Wrap(
            spacing: gap,
            runSpacing: gap,
            children: [
              for (final p in points)
                SizedBox(width: tileW, child: SchemaTile(point: p, now: now)),
            ],
          );
        }),
      ],
    );
  }
}

/// Ein Messpunkt: Kuerzel, Name, Zustand mit Punkt und Wort.
class SchemaTile extends StatelessWidget {
  const SchemaTile({super.key, required this.point, required this.now});
  final SchemaPoint point;
  final DateTime now;

  String get stateText {
    final p = point;
    final last = p.lastSeen;
    final text = switch (p.coverage) {
      PointCoverage.online || PointCoverage.delayed || PointCoverage.offline =>
        '${p.coverage.word} · ${last == null ? '' : formatTime(last, now)}',
      PointCoverage.stale => 'keine Daten seit ${last == null ? '' : _dmy.format(last)}',
      PointCoverage.entries => 'Einträge · letzter ${last == null ? '' : _dmy.format(last)}',
      PointCoverage.missing => 'nicht gemessen',
    };
    return p.viaK0 ? '$text · über K0' : text;
  }

  @override
  Widget build(BuildContext context) {
    final missing = point.coverage == PointCoverage.missing;
    final tile = Container(
      constraints: const BoxConstraints(minHeight: 76),
      padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
      decoration: BoxDecoration(
        color: missing ? KwfColors.weiss : slotColor(point.id),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          KwfCodeChip(point.id),
          const SizedBox(height: 4),
          Text(point.label,
              style: kwfText(13,
                  weight: FontWeight.w600,
                  color: missing ? KwfColors.textSekundaer : KwfColors.anthrazit)),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: KwfStatusDot(coverageColor(point.coverage)),
              ),
              const SizedBox(width: 5),
              Expanded(child: Text(stateText, style: kwfText(11, weight: FontWeight.w400))),
            ],
          ),
        ],
      ),
    );
    return Semantics(
      container: true,
      label: '${point.label}, ${point.id}, $stateText',
      excludeSemantics: true,
      child: missing ? CustomPaint(foregroundPainter: _DashedRect(), child: tile) : tile,
    );
  }
}

/// Haus mit Dach und gestrichelter Systemgrenze. Der Painter zeichnet nur
/// den Rahmen, der Inhalt sind normale Widgets.
class _House extends StatelessWidget {
  const _House({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 44,
          child: CustomPaint(
            painter: _Roof(),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 18),
                child: Text('DEIN HAUS', style: KwfText.kicker),
              ),
            ),
          ),
        ),
        CustomPaint(
          foregroundPainter: _DashedRect(color: KwfColors.anthrazit, inset: 0),
          child: Container(
            color: KwfColors.weiss,
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Systemgrenze', style: KwfText.meta),
                const SizedBox(height: 8),
                for (var i = 0; i < children.length; i++) ...[
                  if (i > 0) const SizedBox(height: 16),
                  children[i],
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Roof extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, size.height)
      ..lineTo(size.width / 2, 0)
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = KwfColors.grauHell);
    canvas.drawPath(
        path,
        Paint()
          ..color = KwfColors.anthrazit
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _DashedRect extends CustomPainter {
  _DashedRect({this.color = KwfColors.grau, this.inset = 0.5});
  final Color color;
  final double inset;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    const dash = 5.0, gap = 4.0;
    void line(Offset a, Offset b) {
      final len = (b - a).distance;
      final dir = (b - a) / len;
      for (var t = 0.0; t < len; t += dash + gap) {
        canvas.drawLine(a + dir * t, a + dir * (t + dash).clamp(0, len), paint);
      }
    }

    final r = Rect.fromLTWH(inset, inset, size.width - 2 * inset, size.height - 2 * inset);
    line(r.topLeft, r.topRight);
    line(r.topRight, r.bottomRight);
    line(r.bottomRight, r.bottomLeft);
    line(r.bottomLeft, r.topLeft);
  }

  @override
  bool shouldRepaint(covariant _DashedRect old) => old.color != color || old.inset != inset;
}
