import 'package:flutter/widgets.dart';

import 'session.dart';

/// Stellt die Session im Widget-Baum bereit und baut bei Aenderungen neu.
class SessionScope extends InheritedNotifier<AppSession> {
  const SessionScope({super.key, required AppSession session, required super.child})
      : super(notifier: session);

  static AppSession of(BuildContext context) {
    final s = context.dependOnInheritedWidgetOfExactType<SessionScope>()?.notifier;
    assert(s != null, 'SessionScope fehlt im Widget-Baum');
    return s!;
  }

  /// Ohne Abhaengigkeit, z.B. in Callbacks.
  static AppSession read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<SessionScope>()!.notifier!;
}
