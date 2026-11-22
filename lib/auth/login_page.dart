import 'package:flutter/material.dart';

import '../app/session_scope.dart';
import '../theme/kwf_theme.dart';
import '../theme/kwf_tokens.dart';
import '../theme/kwf_widgets.dart';
import '../user.dart';

enum _Mode { signIn, register, reset }

/// Anmelden, Konto erstellen, Passwort zuruecksetzen. Gleiche Abläufe wie
/// bisher (AppUser), neues Layout.
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _key = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  _Mode _mode = _Mode.signIn;
  bool _busy = false;
  String? _message;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_key.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    final email = _email.text.trim();
    String? error;
    try {
      switch (_mode) {
        case _Mode.signIn:
          error = await AppUser().signIn(email, _password.text);
        case _Mode.register:
          error = await AppUser().createUser(email, _password.text);
        case _Mode.reset:
          await AppUser().passwordForgotten(email);
      }
    } catch (e) {
      error = '$e';
    }
    if (!mounted) return;
    if (_mode == _Mode.reset && error == null) {
      setState(() {
        _busy = false;
        _mode = _Mode.signIn;
        _message = 'Wir haben dir eine E-Mail zum Zurücksetzen geschickt.';
      });
      return;
    }
    if (error != null) {
      setState(() {
        _busy = false;
        _message = _friendly(error!);
      });
      return;
    }
    await SessionScope.read(context).load();
    if (mounted) setState(() => _busy = false);
  }

  String _friendly(String raw) {
    if (raw.contains('invalid-credential') ||
        raw.contains('wrong-password') ||
        raw.contains('user-not-found')) {
      return 'E-Mail oder Passwort stimmen nicht.';
    }
    if (raw.contains('email-already-in-use')) return 'Für diese E-Mail gibt es schon ein Konto.';
    if (raw.contains('weak-password')) return 'Das Passwort ist zu kurz, nimm mindestens 6 Zeichen.';
    if (raw.contains('network')) return 'Keine Verbindung. Prüfe das Internet.';
    return 'Das hat nicht geklappt. Versuch es nochmals.';
  }

  @override
  Widget build(BuildContext context) {
    final title = switch (_mode) {
      _Mode.signIn => 'Anmelden',
      _Mode.register => 'Konto erstellen',
      _Mode.reset => 'Passwort zurücksetzen',
    };
    return Scaffold(
      backgroundColor: KwfColors.weiss,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _key,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(child: Image.asset('assets/logo.png', width: 88, height: 88)),
                    const SizedBox(height: 12),
                    Center(child: Text('Energiemonitor', style: kwfText(26, weight: FontWeight.w600))),
                    const SizedBox(height: 24),
                    Text(title, style: KwfText.screenTitle),
                    const SizedBox(height: 16),
                    Text('E-Mail', style: KwfText.label),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      validator: (v) =>
                          (v == null || !v.contains('@')) ? 'Bitte eine E-Mail eingeben' : null,
                    ),
                    if (_mode != _Mode.reset) ...[
                      const SizedBox(height: 14),
                      Text('Passwort', style: KwfText.label),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _password,
                        obscureText: true,
                        autofillHints: [
                          _mode == _Mode.register ? AutofillHints.newPassword : AutofillHints.password
                        ],
                        onFieldSubmitted: (_) => _submit(),
                        validator: (v) =>
                            (v == null || v.isEmpty) ? 'Bitte ein Passwort eingeben' : null,
                      ),
                    ],
                    if (_message != null) ...[
                      const SizedBox(height: 14),
                      KwfHint(_message!),
                    ],
                    const SizedBox(height: 20),
                    KwfPrimaryButton(title, busy: _busy, onPressed: _submit),
                    const SizedBox(height: 8),
                    if (_mode == _Mode.signIn) ...[
                      TextButton(
                        onPressed: () => setState(() => _mode = _Mode.reset),
                        child: const Text('Passwort vergessen'),
                      ),
                      TextButton(
                        onPressed: () => setState(() => _mode = _Mode.register),
                        child: const Text('Neues Konto erstellen'),
                      ),
                    ] else
                      TextButton(
                        onPressed: () => setState(() => _mode = _Mode.signIn),
                        child: const Text('Ich habe schon ein Konto'),
                      ),
                    if (_mode == _Mode.register)
                      Text(
                          'Nach dem Erstellen siehst du einen Testmonitor. Deinen eigenen '
                          'Monitor schaltet das Team Energiemonitor frei.',
                          style: KwfText.help),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
