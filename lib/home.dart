import 'package:flutter/material.dart';
import 'package:kwf_energiemonitor/user.dart';
import 'package:kwf_energiemonitor/monitor.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  _showMessage(String message) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        floatingActionButton: AppUser().hasMultipleMonitors
            ? FloatingActionButton(
                onPressed: () {
                  setState(() {
                    AppUser().changeActiveMonitorRead();
                  });
                },
                tooltip: "Monitor wechseln",
                child: const Icon(Icons.change_circle))
            : null,
        body: SingleChildScrollView(
            child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(children: [
                  const UserText(),
                  const SizedBox(height: 5),
                  MonitorDisplay(AppUser().activeMonitor)
                ]))));
  }
}

class MonitorDisplay extends StatefulWidget {
  const MonitorDisplay(this.activeMonitor, {super.key});

  final EnergieMonitor? activeMonitor;

  @override
  State<MonitorDisplay> createState() => _MonitorDisplayState();
}

class _MonitorDisplayState extends State<MonitorDisplay> {
  _infoBoxNoMonitors(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Card(
        color: Theme.of(context).colorScheme.primary,
        child: const ListTile(
          leading: Icon(Icons.info, color: Colors.white),
          title: Text(
            'Noch kein Energiemonitor zugeordnet',
            style: TextStyle(color: Colors.white),
          ),
          subtitle: Text(
            'Deinem Konto ist noch kein Energiemonitor zugeordnet. Melde '
            'dich bei energiemonitor@kleinwohnformen.ch, damit wir dein Konto'
            'mit deinem Energiemonitor verlinken können.',
            style: TextStyle(color: Colors.white70),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!AppUser().isLoggedIn) {
      // Return an empty container if user is logged out
      return Container();
    } else if (widget.activeMonitor == null) {
      return _infoBoxNoMonitors(context);
    } else if (widget.activeMonitor!.id == "sandbox_monitor") {
      return Align(
          alignment: Alignment.topLeft,
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _infoBoxNoMonitors(context),
            Text("Dein Energiemonitor",
                style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 5),
            Text(widget.activeMonitor!.tinyhouseName,
                style: Theme.of(context).textTheme.headlineSmall),
            Text(widget.activeMonitor!.tinyhouseLocation,
                style: Theme.of(context).textTheme.labelLarge),
          ]));
    } else {
      return Align(
          alignment: Alignment.topLeft,
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text("Dein Energiemonitor",
                style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 5),
            Text(widget.activeMonitor!.tinyhouseName,
                style: Theme.of(context).textTheme.headlineSmall),
            Text(widget.activeMonitor!.tinyhouseLocation,
                style: Theme.of(context).textTheme.labelLarge),
          ]));
    }
  }
}

class UserText extends StatefulWidget {
  const UserText({super.key});

  @override
  State<UserText> createState() => _UserTextState();
}

class _UserTextState extends State<UserText> {
  final form = GlobalKey<FormState>();
  String? enteredName = '';
  bool isEdit = false;
  bool isSending = false;

  _showMessage(String message) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  sendNewNickname() async {
    if (form.currentState!.validate()) {
      form.currentState!.save();
      setState(() {
        isSending = true;
      });
      final error = await AppUser().updateNickname(enteredName!);
      setState(() {
        isSending = false;
        isEdit = false;
      });
      if (error != null) {
        _showMessage(error);
      }
    }
  }

  Widget nameInputField() {
    return TextFormField(
        decoration: const InputDecoration(labelText: 'Neuer Nutzername'),
        keyboardType: TextInputType.name,
        maxLength: 20,
        autocorrect: false,
        textCapitalization: TextCapitalization.words,
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return 'Bitte einen Namen eingeben';
          }
          return null;
        },
        onSaved: (value) {
          enteredName = value!;
        });
  }

  @override
  Widget build(BuildContext context) {
    return Form(
        key: form,
        child: Row(children: [
          !AppUser().isLoggedIn
              ? const Text("Hallo, du bist ausgeloggt.")
              : !isEdit
                  ? AppUser().nickname == null
                      ? const Text("Hallo, Nutzer ohne Namen!")
                      : Text("Hallo ${AppUser().nickname}")
                  : SizedBox(width: 200, child: nameInputField()),
          const SizedBox(width: 5),
          if (AppUser().isLoggedIn)
            isSending
                ? const SizedBox(
                    width: 18, height: 18, child: CircularProgressIndicator())
                : isEdit
                    ? IconButton(
                        onPressed: (() {
                          sendNewNickname();
                        }),
                        tooltip: "Name ändern",
                        icon: const Icon(Icons.send),
                        iconSize: 18)
                    : IconButton(
                        onPressed: (() {
                          setState(() {
                            isEdit = true;
                          });
                        }),
                        tooltip: "Name ändern",
                        icon: const Icon(Icons.edit_sharp),
                        iconSize: 18)
        ]));
  }
}
