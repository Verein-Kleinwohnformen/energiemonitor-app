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
    final activeMonitor = AppUser().activeMonitor;

    return Scaffold(
        body: SingleChildScrollView(
            child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(children: [
                  // User Greeting Banner
                  const UserGreetingBanner(),
                  const SizedBox(height: 16),

                  // Monitor Info Card
                  if (AppUser().isLoggedIn)
                    Card(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      child: ListTile(
                        leading: Icon(
                          Icons.monitor_heart,
                          color:
                              Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                        title: Text(
                          'Aktueller Monitor',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context)
                                .colorScheme
                                .onPrimaryContainer,
                          ),
                        ),
                        subtitle: activeMonitor != null
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 4),
                                  Text(
                                    activeMonitor.tinyhouseName,
                                    style: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onPrimaryContainer,
                                    ),
                                  ),
                                  Text(
                                    activeMonitor.tinyhouseLocation,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onPrimaryContainer
                                          .withOpacity(0.8),
                                    ),
                                  ),
                                ],
                              )
                            : Text(
                                'Kein Monitor zugewiesen',
                                style: TextStyle(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onPrimaryContainer,
                                ),
                              ),
                        trailing: AppUser().hasMultipleMonitors
                            ? IconButton(
                                icon: Icon(
                                  Icons.swap_horiz,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onPrimaryContainer,
                                ),
                                tooltip: 'Monitor wechseln',
                                onPressed: () {
                                  setState(() {
                                    AppUser().changeActiveMonitorRead();
                                  });
                                },
                              )
                            : null,
                      ),
                    ),
                  if (AppUser().isLoggedIn) const SizedBox(height: 16),

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
            'dich bei energiemonitor@kleinwohnformen.ch, damit wir dein Konto '
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
    }

    // Check if user only has sandbox monitor (no real monitor assigned)
    final hasOnlySandbox = AppUser().monitorReadIdList.length == 1 &&
        AppUser().monitorReadIdList.contains("sandbox_monitor");

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Show warning only if user has ONLY sandbox monitor
      if (hasOnlySandbox) _infoBoxNoMonitors(context),
    ]);
  }
}

class UserGreetingBanner extends StatefulWidget {
  const UserGreetingBanner({super.key});

  @override
  State<UserGreetingBanner> createState() => _UserGreetingBannerState();
}

class _UserGreetingBannerState extends State<UserGreetingBanner> {
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
        decoration: const InputDecoration(
          labelText: 'Neuer Nutzername',
          filled: true,
          fillColor: Colors.white,
        ),
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
    if (!AppUser().isLoggedIn) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context)
              .colorScheme
              .surfaceContainerHighest
              .withOpacity(0.3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            const Text('👋', style: TextStyle(fontSize: 32)),
            const SizedBox(width: 12),
            Text(
              'Hallo! Bitte melde dich an.',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ],
        ),
      );
    }

    return Form(
      key: form,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context)
              .colorScheme
              .surfaceContainerHighest
              .withOpacity(0.3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            if (!isEdit) const Text('👋', style: TextStyle(fontSize: 32)),
            const SizedBox(width: 12),
            Expanded(
              child: !isEdit
                  ? Text(
                      'Hallo ${AppUser().nickname ?? "Gast"}!',
                      style: Theme.of(context).textTheme.headlineSmall,
                    )
                  : nameInputField(),
            ),
            const SizedBox(width: 8),
            isSending
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : isEdit
                    ? IconButton(
                        onPressed: sendNewNickname,
                        tooltip: "Name speichern",
                        icon: const Icon(Icons.check_circle),
                      )
                    : IconButton(
                        onPressed: () {
                          setState(() {
                            isEdit = true;
                          });
                        },
                        tooltip: "Name ändern",
                        icon: const Icon(Icons.edit),
                      ),
          ],
        ),
      ),
    );
  }
}
