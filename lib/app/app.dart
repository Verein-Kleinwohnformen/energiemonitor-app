import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';

import '../analysis/analysis_page.dart';
import '../auth/login_page.dart';
import '../capture/capture_page.dart';
import '../capture/energy_form_page.dart';
import '../more/about_page.dart';
import '../more/export_page.dart';
import '../more/household_page.dart';
import '../more/measurements_page.dart';
import '../more/method_page.dart';
import '../more/monitor_switch_page.dart';
import '../more/more_page.dart';
import '../more/study_info_page.dart';
import '../overview/overview_page.dart';
import '../shell/app_shell.dart';
import '../shell/splash_view.dart';
import '../theme/kwf_theme.dart';
import 'routes.dart';
import 'services.dart';
import 'session.dart';
import 'session_scope.dart';

final _rootKey = GlobalKey<NavigatorState>();

GoRouter buildRouter(AppSession session) {
  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: '/',
    refreshListenable: session,
    redirect: (context, state) => redirectFor(session, state.matchedLocation),
    routes: [
      GoRoute(path: '/', redirect: (_, __) => homeFor(session)),
      GoRoute(path: Routes.login, builder: (_, __) => const LoginPage()),
      GoRoute(
        path: Routes.captureForm,
        parentNavigatorKey: _rootKey,
        builder: (_, state) => EnergyFormPage(start: state.extra as FormStart?),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: Routes.overview, builder: (_, __) => const OverviewPage()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: Routes.analysis, builder: (_, __) => const AnalysisPage()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: Routes.capture, builder: (_, __) => const CapturePage()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: Routes.more, builder: (_, __) => const MorePage()),
          ]),
        ],
      ),
      // Unterseiten von "Mehr" ohne Tab-Leiste, mit Zurueck.
      GoRoute(
          path: Routes.systemStatus,
          redirect: (_, __) => Routes.more),
      GoRoute(
          path: Routes.monitorSwitch,
          parentNavigatorKey: _rootKey,
          builder: (_, __) => const MonitorSwitchPage()),
      GoRoute(
          path: Routes.household,
          parentNavigatorKey: _rootKey,
          builder: (_, __) => const HouseholdPage()),
      GoRoute(
          path: Routes.measurements,
          parentNavigatorKey: _rootKey,
          builder: (_, __) => const MeasurementsPage()),
      GoRoute(
          path: Routes.export,
          parentNavigatorKey: _rootKey,
          builder: (_, __) => const ExportPage()),
      GoRoute(
          path: Routes.study,
          parentNavigatorKey: _rootKey,
          builder: (_, __) => const StudyInfoPage()),
      GoRoute(
          path: Routes.about,
          parentNavigatorKey: _rootKey,
          builder: (_, __) => const AboutPage()),
      GoRoute(
          path: Routes.method,
          parentNavigatorKey: _rootKey,
          builder: (_, __) => const MethodPage()),
    ],
  );
}

/// Startseite: im Studienmodus Erfassen, sonst die Uebersicht.
String homeFor(AppSession s) => s.hideAnalysis ? Routes.capture : Routes.overview;

/// Weiterleitungen fuer Anmeldung und Studienmodus. Oeffentlich, damit sie
/// sich ohne Browser testen lassen.
String? redirectFor(AppSession session, String location) {
  switch (session.phase) {
    case SessionPhase.loading:
      return null;
    case SessionPhase.signedOut:
      return location == Routes.login ? null : Routes.login;
    case SessionPhase.ready:
      if (location == Routes.login) return homeFor(session);
      if (session.hideAnalysis && Routes.isHiddenInStudy(location)) return Routes.capture;
      return null;
  }
}

class EnergiemonitorApp extends StatefulWidget {
  const EnergiemonitorApp({super.key, required this.session, required this.services});

  final AppSession session;

  /// Baut die Dienste fuer die aktuelle Session.
  final AppServices Function(Widget child) services;

  @override
  State<EnergiemonitorApp> createState() => _EnergiemonitorAppState();
}

class _EnergiemonitorAppState extends State<EnergiemonitorApp> {
  late final GoRouter _router = buildRouter(widget.session);

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SessionScope(
      session: widget.session,
      child: widget.services(
        MaterialApp.router(
          title: 'Energiemonitor',
          debugShowCheckedModeBanner: false,
          theme: buildKwfTheme(),
          locale: const Locale('de', 'CH'),
          supportedLocales: const [Locale('de', 'CH'), Locale('de')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          routerConfig: _router,
          builder: (context, child) {
            final session = SessionScope.of(context);
            if (session.phase == SessionPhase.loading) return const SplashView();
            // Auf breiten Bildschirmen bleibt die App handybreit, mittig.
            return ColoredBox(
              color: const Color(0xFFE9E9E9),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: child!,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
