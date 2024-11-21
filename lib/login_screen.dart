import 'package:flutter/material.dart';
import 'package:kwf_energiemonitor/user.dart';

enum ScreenType { signup, login, forgotten }

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  ScreenType _screenType = ScreenType.login;
  final _form = GlobalKey<FormState>();
  var _enteredEmail = '';
  var _enteredPassword = '';
  bool _isSending = false;

  _showMessage(String message) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  // Pass a function to perform an action in the user class
  _userAction(Function(String, String) action, String successMsg) async {
    if (_form.currentState!.validate()) {
      _form.currentState!.save();
      setState(() {
        _isSending = true;
      });
      String? e = await action(_enteredEmail, _enteredPassword);
      setState(() {
        _isSending = false;
      });
      if (e == null) {
        _showMessage(successMsg);
        if (context.mounted) {
          Navigator.of(context).pop();
        }
      } else {
        _showMessage(e!);
      }
    }
  }

  Widget _emailField() {
    return TextFormField(
        decoration: const InputDecoration(labelText: 'Email'),
        keyboardType: TextInputType.emailAddress,
        autocorrect: false,
        textCapitalization: TextCapitalization.none,
        validator: (value) {
          if (value == null || value.trim().isEmpty || !value.contains('@')) {
            return 'Bitte gültige Email-Adresse eingeben';
          }
          return null;
        },
        onSaved: (value) {
          _enteredEmail = value!;
        });
  }

  Widget _passwordField() {
    return TextFormField(
        decoration: const InputDecoration(labelText: 'Passwort'),
        obscureText: true,
        autocorrect: false,
        textCapitalization: TextCapitalization.none,
        validator: (value) {
          if (value == null || value.trim().length < 8) {
            return 'Muss mindestens 8 Zeichen haben';
          }
          return null;
        },
        onSaved: (value) {
          _enteredPassword = value!;
        });
  }

  List<Widget> _conditionalLoginScreen() {
    if (_screenType == ScreenType.signup) {
      return [
        const Text('Neues Konto erstellen'),
        _emailField(),
        _passwordField(),
        const SizedBox(height: 12),
        Center(
            child: Row(children: [
          FilledButton(
              onPressed: _isSending
                  ? null
                  : () async {
                      _userAction(
                          AppUser().createUser, "Neues Konto wurde erstellt");
                    },
              child: _isSending
                  ? const SizedBox(
                      height: 20, width: 20, child: CircularProgressIndicator())
                  : const Text("Konto erstellen")),
          const SizedBox(width: 10),
          FilledButton.tonal(
              onPressed: _isSending
                  ? null
                  : () {
                      setState(() {
                        _screenType = ScreenType.login;
                      });
                    },
              child: const Text("Ich habe schon ein Konto")),
          const SizedBox(width: 10),
          IconButton(
              icon: const Icon(Icons.undo),
              onPressed: () {
                Navigator.of(context).pop(true);
              })
        ]))
      ];
    } else if (_screenType == ScreenType.login) {
      return [
        const Text('Mit bestehendem Konto einloggen'),
        _emailField(),
        _passwordField(),
        InkWell(
            onTap: () {
              setState(() {
                _screenType = ScreenType.forgotten;
              });
            },
            child: Align(
                alignment: Alignment.bottomLeft,
                child: Text("Passwort vergessen",
                    style: TextStyle(
                        decoration: TextDecoration.underline,
                        color: Theme.of(context).colorScheme.primary)))),
        const SizedBox(height: 12),
        Center(
            child: Row(children: [
          FilledButton(
              onPressed: _isSending
                  ? null
                  : () async {
                      _userAction(AppUser().signIn, "Du bist eingeloggt");
                    },
              child: _isSending
                  ? const SizedBox(
                      height: 20, width: 20, child: CircularProgressIndicator())
                  : const Text("Einloggen")),
          const SizedBox(width: 10),
          FilledButton.tonal(
              onPressed: _isSending
                  ? null
                  : () {
                      setState(() {
                        _screenType = ScreenType.signup;
                      });
                    },
              child: const Text("Neues Konto erstellen")),
          const SizedBox(width: 10),
          IconButton(
              icon: const Icon(Icons.undo),
              onPressed: () {
                Navigator.of(context).pop(true);
              })
        ]))
      ];
    }
    // Password forgotten
    else {
      return [
        const Text('Passwort vergessen'),
        _emailField(),
        const SizedBox(height: 12),
        Center(
            child: Row(children: [
          FilledButton(
              onPressed: _isSending
                  ? null
                  : () async {
                      if (_form.currentState!.validate()) {
                        _form.currentState!.save();
                        setState(() {
                          _screenType = ScreenType.login;
                          _isSending = true;
                        });
                        await AppUser().passwordForgotten(_enteredEmail);
                        setState(() {
                          _isSending = false;
                        });
                        _showMessage("Email wurde versendet");
                      }
                    },
              child: _isSending
                  ? const SizedBox(
                      height: 20, width: 20, child: CircularProgressIndicator())
                  : const Text("Passwort zurücksetzen")),
          const SizedBox(width: 10),
          IconButton(
              icon: const Icon(Icons.undo),
              onPressed: () {
                Navigator.of(context).pop(true);
              })
        ]))
      ];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: Theme.of(context).colorScheme.primary,
        body: Center(
            child: Card(
                margin: const EdgeInsets.all(20),
                child: SingleChildScrollView(
                    child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Form(
                            key: _form,
                            child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: _conditionalLoginScreen())))))));
  }
}
