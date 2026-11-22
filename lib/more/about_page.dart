import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app/version.dart';
import '../theme/kwf_theme.dart';
import '../theme/kwf_tokens.dart';
import '../theme/kwf_widgets.dart';
import 'sub_page.dart';

Future<void> openLink(String url) async {
  try {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      await launchUrl(uri);
    }
  } catch (e) {
    debugPrint('Link nicht geoeffnet: $e');
  }
}

/// Impressum und Version (vorher eigener Tab "Info").
///
/// TODO(prüfen): Das alte Impressum nannte den Entwickler mit Namen und
/// LinkedIn-Profil. Hier steht neu das Team Energiemonitor. Klaeren, ob der
/// Name im Impressum stehen soll.
class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    Widget link(String text, String url) => Semantics(
          link: true,
          child: InkWell(
            onTap: () => openLink(url),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(text,
                  style: kwfText(14,
                          weight: FontWeight.w500, color: KwfColors.gruenDunkel)
                      .copyWith(decoration: TextDecoration.underline)),
            ),
          ),
        );

    return SubPage(title: 'Impressum und Version', children: [
      Center(
        child: Column(
          children: [
            Image.asset('assets/logo.png', height: 96),
            const SizedBox(height: 12),
            Text('KWF Energiemonitor', style: KwfText.screenTitle),
            Text('Version $kAppVersion', style: KwfText.meta),
          ],
        ),
      ),
      KwfCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Über diese App', style: KwfText.sectionTitle),
            const SizedBox(height: 6),
            Text(
                'Der KWF Energiemonitor zeigt, wie viel Energie eine Kleinwohnform braucht '
                'und woher sie kommt. Er ist ein offenes Messsystem des Vereins '
                'Kleinwohnformen und Teil der Energiestudie mit der Hochschule Luzern.',
                style: KwfText.body),
          ],
        ),
      ),
      KwfCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Was sind Kleinwohnformen?', style: KwfText.sectionTitle),
            const SizedBox(height: 6),
            Text(
                'Eine Kleinwohnform ist eine kompakte und ressourcenschonende Wohnlösung mit '
                'maximal 30 m² Wohnfläche für eine Person. Sie basiert auf Prinzipien der '
                'Kreislaufwirtschaft, ist modular, rückbaubar und nutzt bebaubare Flächen '
                'ohne zusätzliche Versiegelung.',
                style: KwfText.body),
            link('www.kleinwohnformen.ch', 'https://www.kleinwohnformen.ch'),
          ],
        ),
      ),
      KwfCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Urheberrecht und Lizenzen', style: KwfText.sectionTitle),
            const SizedBox(height: 6),
            Text(
                'Logo © Verein Kleinwohnformen Schweiz, verwendet mit freundlicher '
                'Genehmigung. Der Code der App steht unter der Apache License 2.0. Die '
                'Schrift Inter steht unter der SIL Open Font License 1.1.',
                style: KwfText.body),
            link('Quellcode auf GitHub',
                'https://github.com/Verein-Kleinwohnformen/energiemonitor-app'),
          ],
        ),
      ),
      KwfCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Kontakt', style: KwfText.sectionTitle),
            const SizedBox(height: 6),
            Text('Team Energiemonitor, Verein Kleinwohnformen', style: KwfText.body),
            link('energiemonitor@kleinwohnformen.ch', 'mailto:energiemonitor@kleinwohnformen.ch'),
          ],
        ),
      ),
    ]);
  }
}
