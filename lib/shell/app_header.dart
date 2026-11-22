import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../app/routes.dart';
import '../app/services.dart';
import '../app/session_scope.dart';
import '../metering_point.dart';
import '../status/system_status.dart';
import '../theme/kwf_theme.dart';
import '../theme/kwf_tokens.dart';
import '../theme/kwf_widgets.dart';

/// Kopfzeile: Hausname (mit Pfeil bei mehreren Monitoren) und Status-Pille.
class AppHeader extends StatelessWidget {
  const AppHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    final monitor = session.active;
    final name = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(monitor?.tinyhouseName ?? 'Kein Monitor',
              overflow: TextOverflow.ellipsis, style: kwfText(18, weight: FontWeight.w600)),
        ),
        if (session.hasMultipleMonitors) ...[
          const SizedBox(width: 4),
          const Icon(Icons.expand_more, size: 18, color: KwfColors.anthrazit),
        ],
      ],
    );
    return Container(
      decoration: const BoxDecoration(
        color: KwfColors.weiss,
        border: Border(bottom: BorderSide(color: KwfColors.grauHell)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 14, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('ENERGIEMONITOR',
                    style: kwfText(11,
                        weight: FontWeight.w500,
                        color: KwfColors.textSekundaer,
                        letterSpacing: 0.6)),
                if (session.hasMultipleMonitors)
                  Semantics(
                    button: true,
                    label: 'Monitor wechseln',
                    child: InkWell(
                      onTap: () => context.push(Routes.monitorSwitch),
                      child: name,
                    ),
                  )
                else
                  name,
              ],
            ),
          ),
          const SizedBox(width: 12),
          if (monitor != null) StatusPill(monitorId: monitor.id),
        ],
      ),
    );
  }
}

/// Kurz-Check, ob Daten ankommen. Antippen fuehrt zu Mehr (Systemstatus).
class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.monitorId});
  final String monitorId;

  @override
  Widget build(BuildContext context) {
    final services = AppServices.of(context);
    return StreamBuilder<List<MeteringPoint>>(
      stream: services.status.watch(monitorId),
      builder: (context, snap) {
        final status = SystemStatus.fromPoints(snap.data ?? const [], services.clock.now());
        final text = snap.hasData ? status.pillText : 'Status wird geladen';
        return Semantics(
          button: true,
          label: 'Systemstatus: $text',
          excludeSemantics: true,
          child: InkWell(
            borderRadius: BorderRadius.circular(KwfRadius.pill),
            onTap: () => context.go(Routes.more),
            child: Container(
              constraints: const BoxConstraints(minHeight: 32),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                border: Border.all(color: KwfColors.grauHell),
                borderRadius: BorderRadius.circular(KwfRadius.pill),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  KwfStatusDot(snap.hasData ? stateColor(status.overall) : KwfColors.grau),
                  const SizedBox(width: 6),
                  Text(text, style: kwfText(12, weight: FontWeight.w500)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

Color stateColor(LinkState? s) => switch (s) {
      LinkState.online => KwfColors.komfortGut,
      LinkState.delayed => KwfColors.komfortMittel,
      LinkState.offline => KwfColors.komfortSchlecht,
      null => KwfColors.grau,
    };
