import 'package:flutter/material.dart';

import '../theme/kwf_theme.dart';
import '../theme/kwf_tokens.dart';
import 'app_icon.dart';

/// Startbildschirm, solange die App den Monitor abfragt (Design System,
/// Komponente SplashScreen, Variante mit Ladezustand). Sieht aus wie der
/// Startbildschirm im Browser (web/index.html), damit der Uebergang vom
/// HTML zu Flutter nicht springt: Icon mit bewegten Balken, Name, Zeile,
/// schmaler Ladebalken, unten die gruene Dachkante mit dem Vereinslogo.
class SplashView extends StatelessWidget {
  const SplashView({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Energiemonitor wird geladen',
      liveRegion: true,
      // Material: liefert den Textstil. Die Ansicht liegt im builder von
      // MaterialApp ueber dem Navigator, ohne eigenes Scaffold.
      child: Material(
        color: KwfColors.weiss,
        child: Stack(
          children: [
            // Mitte des Blocks bei 34 % der Hoehe, wie im HTML
            // (top: 34 %; transform: translateY(-50 %)).
            LayoutBuilder(
              builder: (context, c) => Stack(
                children: [
                  Positioned(
                    left: 0,
                    right: 0,
                    top: c.maxHeight * 0.34,
                    child: FractionalTranslation(
                      translation: const Offset(0, -0.5),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 28),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const KwfAppIcon(size: 112, animated: true),
                            const SizedBox(height: 18),
                            Text(
                              'Energiemonitor',
                              textAlign: TextAlign.center,
                              style: kwfText(
                                26,
                                weight: FontWeight.w600,
                                height: 32 / 26,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Energie und Raumklima\ndeiner Kleinwohnform',
                              textAlign: TextAlign.center,
                              style: kwfText(14, height: 20 / 14),
                            ),
                            const SizedBox(height: 26),
                            const LoadingBar(),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Positioned(left: 0, right: 0, bottom: 0, child: _RoofBand()),
          ],
        ),
      ),
    );
  }
}

/// Ladebalken 120 x 3 px, ein Abschnitt in gruen-dunkel laeuft von links
/// nach rechts (1.4 s), wie im HTML. Kein Spinner.
class LoadingBar extends StatefulWidget {
  const LoadingBar({super.key});

  @override
  State<LoadingBar> createState() => _LoadingBarState();
}

class _LoadingBarState extends State<LoadingBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (still) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const width = 120.0;
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return SizedBox(
      width: width,
      height: 3,
      child: ClipRect(
        child: ColoredBox(
          color: KwfColors.grauHell,
          child: AnimatedBuilder(
            animation: _c,
            builder: (context, _) {
              final t = Curves.easeInOut.transform(_c.value);
              final left = still ? 0.0 : -0.4 * width + t * 1.4 * width;
              return Stack(
                children: [
                  Positioned(
                    left: left,
                    top: 0,
                    bottom: 0,
                    width: still ? 0.45 * width : 0.4 * width,
                    child: const ColoredBox(color: KwfColors.gruenDunkel),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _RoofBand extends StatelessWidget {
  const _RoofBand();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(
          height: 70,
          width: double.infinity,
          child: CustomPaint(painter: _RoofPainter(), isComplex: false),
        ),
        Container(
          height: 96,
          width: double.infinity,
          color: KwfColors.gruen,
          alignment: Alignment.center,
          child: Image.asset(
            'assets/kwf-logo-negativ.png',
            height: 44,
            semanticLabel: 'Verein Kleinwohnformen',
          ),
        ),
      ],
    );
  }
}

/// Dachkante mit der Spitze bei 25 % der Breite (wie dachkante-links.svg).
class _RoofPainter extends CustomPainter {
  const _RoofPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 300;
    final sy = size.height / 70;
    final path = Path()
      // 1 px tiefer als die Flaeche, damit keine helle Kante zum Band bleibt.
      ..moveTo(0, 70 * sy + 1)
      ..lineTo(0, 36 * sy)
      ..lineTo(75 * sx, 0)
      ..lineTo(300 * sx, 50 * sy)
      ..lineTo(300 * sx, 70 * sy + 1)
      ..close();
    canvas.drawPath(path, Paint()..color = KwfColors.gruen);
  }

  @override
  bool shouldRepaint(_RoofPainter oldDelegate) => false;
}
