import 'package:flutter/material.dart';

import 'kwf_theme.dart';
import 'kwf_tokens.dart';

/// Eckige Karte mit shadow-card, wie die Beitragskarten der Website.
class KwfCard extends StatelessWidget {
  const KwfCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.onTap,
    this.semanticLabel,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final content = Padding(padding: padding, child: child);
    return DecoratedBox(
      decoration: const BoxDecoration(color: KwfColors.weiss, boxShadow: KwfShadows.card),
      child: onTap == null
          ? content
          : Semantics(
              button: true,
              label: semanticLabel,
              child: InkWell(onTap: onTap, child: content),
            ),
    );
  }
}

/// Kleiner Zwischentitel in Grossbuchstaben ("DEIN VORRAT").
class KwfKicker extends StatelessWidget {
  const KwfKicker(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) =>
      Text(text.toUpperCase(), style: KwfText.kicker);
}

/// Seitentitel mit optionaler Einleitung.
class KwfPageHeading extends StatelessWidget {
  const KwfPageHeading(this.title, {super.key, this.intro});
  final String title;
  final String? intro;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(header: true, child: Text(title, style: KwfText.pageTitle)),
        if (intro != null) ...[
          const SizedBox(height: 4),
          Text(intro!, style: KwfText.body),
        ],
      ],
    );
  }
}

/// Ruhige Hinweisbox auf hellblau, Icon links.
class KwfHint extends StatelessWidget {
  const KwfHint(this.text, {super.key, this.icon = Icons.info_outline});
  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: KwfColors.hellblau,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: KwfColors.anthrazit),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: KwfText.small)),
        ],
      ),
    );
  }
}

/// Statuspunkt mit Wort. Die Farbe traegt nie allein die Aussage.
class KwfStatusDot extends StatelessWidget {
  const KwfStatusDot(this.color, {super.key, this.size = 8});
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );
}

/// Pille mit Kuerzel eines Messpunkts (E1, K0, M2 ...), klein und dunkel.
class KwfCodeChip extends StatelessWidget {
  const KwfCodeChip(this.code, {super.key});
  final String code;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(
          color: KwfColors.anthrazit,
          borderRadius: BorderRadius.circular(KwfRadius.pill),
        ),
        child: Text(code,
            style: kwfText(11, weight: FontWeight.w600, color: KwfColors.weiss)),
      );
}

/// Abschnitt mit Titel in einer weissen Karte, Zeilen mit Trennlinie.
class KwfSection extends StatelessWidget {
  const KwfSection({super.key, this.title, required this.children, this.trailing});
  final String? title;
  final Widget? trailing;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(color: KwfColors.weiss, boxShadow: KwfShadows.card),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 8, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Semantics(
                        header: true, child: Text(title!, style: KwfText.sectionTitle)),
                  ),
                  if (trailing != null) trailing!,
                ],
              ),
            ),
          for (var i = 0; i < children.length; i++) ...[
            if (title != null || i > 0) const Divider(),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// Zeile in einer Liste der Einstellungen (Mehr).
class KwfNavRow extends StatelessWidget {
  const KwfNavRow({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Icon(icon, size: 22, color: KwfColors.anthrazit),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: kwfText(15, weight: FontWeight.w500)),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(subtitle!, style: KwfText.meta),
                    ],
                  ],
                ),
              ),
              if (onTap != null)
                const Icon(Icons.chevron_right, color: KwfColors.textSekundaer),
            ],
          ),
        ),
      ),
    );
  }
}

/// Breiter Hauptknopf (Pille, gruen).
class KwfPrimaryButton extends StatelessWidget {
  const KwfPrimaryButton(this.label, {super.key, required this.onPressed, this.busy = false});
  final String label;
  final VoidCallback? onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: busy ? null : onPressed,
        child: busy
            ? const SizedBox(
                width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
            : Text(label.toUpperCase()),
      ),
    );
  }
}

/// Inhalt einer Seite: Hintergrund, Rand, begrenzte Breite.
class KwfPage extends StatelessWidget {
  const KwfPage({super.key, required this.children, this.gap = 14});
  final List<Widget> children;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(KwfSpace.page, 16, KwfSpace.page, 24),
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) SizedBox(height: gap),
          children[i],
        ],
      ],
    );
  }
}
