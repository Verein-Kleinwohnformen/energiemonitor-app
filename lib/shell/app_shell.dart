import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../app/routes.dart';
import '../app/services.dart';
import '../app/version.dart';
import '../app/session.dart';
import '../app/session_scope.dart';
import '../household/household.dart';
import '../household/household_onboarding.dart';
import '../study/study_dialog.dart';
import '../theme/kwf_theme.dart';
import '../theme/kwf_tokens.dart';
import 'app_header.dart';

/// Ein Tab der unteren Leiste. [branch] ist der Index im StatefulShellRoute.
class TabSpec {
  const TabSpec(this.branch, this.label, this.icon, this.path);
  final int branch;
  final String label;
  final IconData icon;
  final String path;
}

const kAllTabs = [
  TabSpec(0, 'Übersicht', Icons.home_outlined, Routes.overview),
  TabSpec(1, 'Auswertung', Icons.bar_chart, Routes.analysis),
  TabSpec(2, 'Erfassen', Icons.add_circle_outline, Routes.capture),
  TabSpec(3, 'Mehr', Icons.menu, Routes.more),
];

/// Sichtbare Tabs: im Studienmodus nur Erfassen und Mehr.
List<TabSpec> tabsFor(AppSession session) =>
    session.hideAnalysis ? [kAllTabs[2], kAllTabs[3]] : kAllTabs;

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.shell});
  final StatefulNavigationShell shell;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  /// Monitore, fuer die in dieser Sitzung schon nach dem Haushalt gefragt wurde.
  final _askedHousehold = <String>{};
  StreamSubscription<List<HouseholdEntry>>? _householdSub;
  String? _watchedMonitor;
  bool _dialogOpen = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _watchHousehold();
  }

  @override
  void dispose() {
    _householdSub?.cancel();
    super.dispose();
  }

  void _watchHousehold() {
    final session = SessionScope.of(context);
    final id = session.active?.id;
    if (id == _watchedMonitor) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowStudyDialog());
      return;
    }
    _watchedMonitor = id;
    _householdSub?.cancel();
    if (id == null) return;
    _householdSub = AppServices.of(context).household.watch(id).listen((entries) {
      if (!mounted) return;
      _maybeAskHousehold(entries);
    }, onError: (Object e) => debugPrint('Haushalt nicht lesbar: $e'));
  }

  Future<void> _maybeAskHousehold(List<HouseholdEntry> entries) async {
    final session = SessionScope.read(context);
    final id = session.active?.id;
    if (id == null || entries.isNotEmpty || !session.canEdit) {
      await _maybeShowStudyDialog();
      return;
    }
    if (_askedHousehold.contains(id) || _dialogOpen) return;
    _askedHousehold.add(id);
    _dialogOpen = true;
    await showHouseholdOnboarding(context, monitorId: id);
    _dialogOpen = false;
    await _maybeShowStudyDialog();
  }

  Future<void> _maybeShowStudyDialog() async {
    if (!mounted || _dialogOpen) return;
    final session = SessionScope.read(context);
    if (!session.needsStudyDialog) return;
    _dialogOpen = true;
    await showStudyDialog(context, note: session.active?.studyNote);
    _dialogOpen = false;
    await session.markStudyDialogSeen();
  }

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    final tabs = tabsFor(session);
    final current = widget.shell.currentIndex;
    return Scaffold(
      backgroundColor: KwfColors.seitengrund,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            if (kAppChannel.isNotEmpty) const _ChannelBand(),
            const AppHeader(),
            if (session.showAdminBand) const _AdminBand(),
            Expanded(child: widget.shell),
          ],
        ),
      ),
      bottomNavigationBar: KwfTabBar(
        tabs: tabs,
        currentBranch: current,
        onSelect: (t) => widget.shell.goBranch(t.branch, initialLocation: t.branch == current),
      ),
    );
  }
}

/// Hinweis in Testversionen (Build mit --dart-define=APP_CHANNEL=...).
class _ChannelBand extends StatelessWidget {
  const _ChannelBand();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: KwfColors.blau,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Text('Testversion $kAppChannel, Einträge landen in den echten Daten',
          style: kwfText(12, weight: FontWeight.w600, color: KwfColors.weiss)),
    );
  }
}

class _AdminBand extends StatelessWidget {
  const _AdminBand();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: KwfColors.komfortMittel,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Text('Studienmodus aktiv, Bewohnende sehen nur Erfassen',
          style: kwfText(12, weight: FontWeight.w600)),
    );
  }
}

/// Untere Leiste: Linien-Icons, aktiver Tab mit gruenem Strich oben.
class KwfTabBar extends StatelessWidget {
  const KwfTabBar({
    super.key,
    required this.tabs,
    required this.currentBranch,
    required this.onSelect,
  });

  final List<TabSpec> tabs;
  final int currentBranch;
  final ValueChanged<TabSpec> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: KwfColors.weiss,
        border: Border(top: BorderSide(color: KwfColors.grauHell)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            for (final t in tabs)
              Expanded(child: _TabItem(tab: t, active: t.branch == currentBranch, onTap: onSelect)),
          ],
        ),
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  const _TabItem({required this.tab, required this.active, required this.onTap});
  final TabSpec tab;
  final bool active;
  final ValueChanged<TabSpec> onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: active,
      button: true,
      label: tab.label,
      excludeSemantics: true,
      child: InkWell(
        onTap: () => onTap(tab),
        child: LayoutBuilder(builder: (context, c) {
          return Stack(
            children: [
              if (active)
                Positioned(
                  top: 0,
                  left: c.maxWidth * 0.22,
                  right: c.maxWidth * 0.22,
                  child: Container(height: 3, color: KwfColors.gruen),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(0, 10, 0, 14),
                // heightFactor 1: die Leiste ist nur so hoch wie ihr Inhalt.
                child: Center(
                  heightFactor: 1,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(tab.icon,
                          size: 22,
                          color: active ? KwfColors.gruenDunkel : KwfColors.textSekundaer),
                      const SizedBox(height: 4),
                      Text(
                        tab.label,
                        style: kwfText(11,
                            weight: active ? FontWeight.w600 : FontWeight.w400,
                            color: active ? KwfColors.anthrazit : KwfColors.textSekundaer),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}
