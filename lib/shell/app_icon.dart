// App-Icon des Energiemonitors (Design System, Komponente AppIcon):
// weisses Haus unter der Dachlinie in limette, drei steigende Balken in
// gruen-dunkel, auf dem Verlauf gruen-dunkel zu gruen. Masse im 1024er-Raster
// wie in der Vorlage.
//
// Mit [animated] wachsen und sinken die Balken versetzt, wie im
// Startbildschirm im Browser (web/index.html): 1.6 s pro Zyklus, Hoehe
// zwischen 100 % und 45 %. Bei "Bewegung reduzieren" stehen sie still.
import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../theme/kwf_tokens.dart';

class KwfAppIcon extends StatefulWidget {
  const KwfAppIcon({super.key, this.size = 112, this.animated = false});

  final double size;
  final bool animated;

  @override
  State<KwfAppIcon> createState() => _KwfAppIconState();
}

class _KwfAppIconState extends State<KwfAppIcon> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(KwfAppIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    final move = widget.animated && !(MediaQuery.maybeDisableAnimationsOf(context) ?? false);
    if (move && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!move) {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Energiemonitor',
      image: true,
      child: SizedBox.square(
        dimension: widget.size,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => CustomPaint(
            painter: AppIconPainter(
              phase: _controller.value,
              animated: _controller.isAnimating,
            ),
          ),
        ),
      ),
    );
  }
}

/// Zeichnet das Icon. [phase] von 0 bis 1 entspricht einem Zyklus.
class AppIconPainter extends CustomPainter {
  AppIconPainter({this.phase = 0, this.animated = false});

  final double phase;
  final bool animated;

  /// Versatz der drei Balken wie die animation-delay im HTML
  /// (-0.9 s, -0.45 s, 0 s bei 1.6 s Zyklus).
  static const _offsets = [0.5625, 0.28125, 0.0];

  /// Hoehe eines Balkens als Anteil (1 = volle Hoehe) zur Phase.
  static double barFactor(double phase) {
    final p = phase % 1.0;
    final triangle = p < 0.5 ? p * 2 : (1 - p) * 2; // 0 -> 1 -> 0
    return 1 - 0.55 * Curves.easeInOut.transform(triangle);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 1024;
    canvas.save();
    canvas.scale(s);

    canvas.clipRRect(RRect.fromRectAndRadius(
        const Rect.fromLTWH(0, 0, 1024, 1024), const Radius.circular(229.1)));

    canvas.drawRect(
      const Rect.fromLTWH(0, 0, 1024, 1024),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.bottomLeft,
          end: Alignment.topRight,
          colors: [KwfColors.gruenDunkel, KwfColors.gruen],
        ).createShader(const Rect.fromLTWH(0, 0, 1024, 1024)),
    );

    final house = Path()
      ..moveTo(262, 780)
      ..lineTo(262, 520)
      ..lineTo(512, 300)
      ..lineTo(762, 520)
      ..lineTo(762, 780)
      ..close();
    canvas.drawPath(house, Paint()..color = KwfColors.weiss);

    final roof = Path()
      ..moveTo(196, 506)
      ..lineTo(512, 228)
      ..lineTo(828, 506);
    canvas.drawPath(
      roof,
      Paint()
        ..color = KwfColors.limette
        ..style = PaintingStyle.stroke
        ..strokeWidth = 56
        ..strokeJoin = StrokeJoin.miter,
    );

    final bar = Paint()..color = KwfColors.gruenDunkel;
    const lefts = [342.0, 472.0, 602.0];
    const tops = [606.0, 526.0, 446.0];
    const bottom = 716.0;
    for (var i = 0; i < 3; i++) {
      final full = bottom - tops[i];
      final f = animated ? barFactor(phase + _offsets[i]) : 1.0;
      final top = bottom - full * f;
      final r = math.min(18.0, full * f / 2);
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          Rect.fromLTRB(lefts[i], top, lefts[i] + 80, bottom),
          topLeft: Radius.circular(r),
          topRight: Radius.circular(r),
        ),
        bar,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(AppIconPainter old) => old.phase != phase || old.animated != animated;
}
