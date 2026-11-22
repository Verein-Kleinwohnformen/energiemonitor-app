import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../app/routes.dart';
import '../app/services.dart';
import '../app/session_scope.dart';
import '../household/household.dart';
import '../info/info_overlay.dart';
import '../info/info_texts.dart';
import '../metering_point.dart';
import '../shell/app_header.dart';
import '../status/system_status.dart';
import '../theme/kwf_theme.dart';
import '../theme/kwf_tokens.dart';
import '../theme/kwf_widgets.dart';
import 'account_dialogs.dart';

final _date = DateFormat('d.M.yyyy');

class MorePage extends StatelessWidget {
  const MorePage({super.key});

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    final monitor = session.active;
    final services = AppServices.of(context);
    final hide = session.hideAnalysis;

    return KwfPage(children: [
      const KwfPageHeading('Mehr'),
      if (monitor != null) SystemStatusSection(monitorId: monitor.id),
      _Group('Dieses Haus', [
        if (session.hasMultipleMonitors)
          KwfNavRow(
            icon: Icons.swap_horiz,
            title: 'Monitor wechseln',
            subtitle: '${monitor?.tinyhouseName}, ${monitor?.tinyhouseLocation} · '
                '${session.monitors.length} Monitore',
            onTap: () => context.push(Routes.monitorSwitch),
          ),
        if (monitor != null)
          StreamBuilder<List<HouseholdEntry>>(
            stream: services.household.watch(monitor.id),
            builder: (context, snap) {
              final current = householdAt(snap.data ?? const [], services.clock.now());
              return KwfNavRow(
                icon: Icons.people_outline,
                title: 'Haushalt',
                subtitle: current == null
                    ? 'Personen und Wohnfläche noch nicht erfasst'
                    : '${current.summary} · seit ${_date.format(current.validFrom)}',
                onTap: () => context.push(Routes.household),
              );
            },
          ),
      ]),
      if (!hide)
        _Group('Daten', [
          KwfNavRow(
            icon: Icons.show_chart,
            title: 'Messwerte',
            subtitle: 'Alle Messpunkte, einfach dargestellt',
            onTap: () => context.push(Routes.measurements),
          ),
          KwfNavRow(
            icon: Icons.download_outlined,
            title: 'Daten herunterladen',
            subtitle: 'Excel, Zeitraum frei wählbar',
            onTap: () => context.push(Routes.export),
          ),
        ]),
      _Group('Konto', [
        KwfNavRow(
          icon: Icons.person_outline,
          title: 'Name ändern',
          subtitle: session.displayName?.isNotEmpty == true ? session.displayName : session.email,
          onTap: () => showChangeNameDialog(context),
        ),
        KwfNavRow(
          icon: Icons.logout,
          title: 'Abmelden',
          onTap: () => confirmSignOut(context),
        ),
      ]),
      if (session.studyModeActive)
        _Group('Energiestudie', [
          KwfNavRow(
            icon: Icons.science_outlined,
            title: 'Über die Energiestudie',
            subtitle: 'Warum die App während der Studie keine Auswertungen zeigt',
            onTap: () => context.push(Routes.study),
          ),
        ]),
      if (session.isSuperadmin)
        _Group('Verwaltung', [
          KwfNavRow(
            icon: Icons.admin_panel_settings_outlined,
            title: 'Zugänge verwalten',
            subtitle: 'Konten den Häusern zuordnen, lesen oder bearbeiten',
            onTap: () => context.push(Routes.admin),
          ),
        ]),
      _Group('Über die App', [
        if (!hide)
          KwfNavRow(
            icon: Icons.calculate_outlined,
            title: 'So rechnen wir',
            subtitle: 'Faktoren und Systemgrenze',
            onTap: () => context.push(Routes.method),
          ),
        KwfNavRow(
          icon: Icons.info_outline,
          title: 'Impressum und Version',
          onTap: () => context.push(Routes.about),
        ),
      ]),
    ]);
  }
}

class _Group extends StatelessWidget {
  const _Group(this.title, this.rows);
  final String title;
  final List<Widget> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        KwfKicker(title),
        const SizedBox(height: 8),
        KwfSection(children: rows),
      ],
    );
  }
}

/// Systemstatus: Satz oben, darunter jeder automatische Messpunkt mit
/// Klartext, Kuerzel, Zeit und Ampel mit Wort. Nie ein Messwert, darum
/// auch im Studienmodus gleich.
class SystemStatusSection extends StatelessWidget {
  const SystemStatusSection({super.key, required this.monitorId});
  final String monitorId;

  @override
  Widget build(BuildContext context) {
    final services = AppServices.of(context);
    return StreamBuilder<List<MeteringPoint>>(
      stream: services.status.watch(monitorId),
      builder: (context, snap) {
        final now = services.clock.now();
        final status = SystemStatus.fromPoints(snap.data ?? const [], now);
        final latest = status.latest;
        return KwfSection(
          title: 'Systemstatus',
          trailing: InfoButton(
            text: InfoTexts.systemStatus,
            stand: latest == null ? 'Noch keine Daten' : 'Letzte Daten ${formatTime(latest, now)}',
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: KwfStatusDot(stateColor(status.overall), size: 10),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(snap.hasData ? status.headline : 'Status wird geladen',
                            style: KwfText.sectionTitle),
                        if (snap.hasData) ...[
                          const SizedBox(height: 2),
                          Text(status.explanation, style: KwfText.small),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            for (final p in status.automatic) _PointRow(point: p, now: now),
            if (status.manual.isNotEmpty) _ManualRow(points: status.manual),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              child: Text(
                  'Fehlt etwas? Schreib uns: energiemonitor@kleinwohnformen.ch',
                  style: KwfText.meta),
            ),
          ],
        );
      },
    );
  }
}

class _PointRow extends StatelessWidget {
  const _PointRow({required this.point, required this.now});
  final PointStatus point;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final state = point.state!;
    final quality = point.quality;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 6,
                  children: [
                    Text(point.label, style: kwfText(14, weight: FontWeight.w500)),
                    KwfCodeChip(point.id),
                  ],
                ),
              ),
              Text(formatTime(point.lastSeen, now), style: KwfText.meta),
              const SizedBox(width: 10),
              KwfStatusDot(stateColor(state)),
              const SizedBox(width: 6),
              SizedBox(
                width: 64,
                child: Text(linkStateWord(state), style: kwfText(12, weight: FontWeight.w500)),
              ),
            ],
          ),
          // Warnung zur Datenqualitaet (z.B. Wassertank D1), nur wenn aktuell.
          if (quality != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 1),
                    child: Icon(Icons.warning_amber_rounded, size: 16, color: KwfColors.komfortMittel),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text('Datenqualität: ${quality.describe()}', style: KwfText.meta),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ManualRow extends StatelessWidget {
  const _ManualRow({required this.points});
  final List<PointStatus> points;

  @override
  Widget build(BuildContext context) {
    final latest = points.map((p) => p.lastSeen).reduce((a, b) => a.isAfter(b) ? a : b);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 6,
              children: [
                Text('Deine Einträge', style: kwfText(14, weight: FontWeight.w500)),
                for (final p in points) KwfCodeChip(p.id),
              ],
            ),
          ),
          Text('letzter Eintrag ${DateFormat('d.M.').format(latest)}',
              style: kwfText(12, weight: FontWeight.w400, color: KwfColors.textSekundaer)),
        ],
      ),
    );
  }
}
