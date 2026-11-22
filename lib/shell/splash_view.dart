import 'package:flutter/material.dart';

import '../theme/kwf_theme.dart';
import '../theme/kwf_tokens.dart';

/// Startbildschirm, solange die App den Monitor abfragt (Komponente
/// SplashScreen, Variante mit Ladezustand: schmaler Balken, kein Spinner).
class SplashView extends StatelessWidget {
  const SplashView({super.key});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: KwfColors.weiss,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/logo.png', width: 112, height: 112),
            const SizedBox(height: 16),
            Text('Energiemonitor', style: kwfText(26, weight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text('Verein Kleinwohnformen', style: kwfText(14)),
            const SizedBox(height: 24),
            const SizedBox(
              width: 160,
              child: LinearProgressIndicator(minHeight: 3),
            ),
            const SizedBox(height: 8),
            Text('Dein Monitor wird geladen',
                style: kwfText(12, weight: FontWeight.w400, color: KwfColors.textSekundaer)),
          ],
        ),
      ),
    );
  }
}
