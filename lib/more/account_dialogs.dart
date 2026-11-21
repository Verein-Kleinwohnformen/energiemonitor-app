import 'package:flutter/material.dart';

import '../app/session_scope.dart';

Future<void> showChangeNameDialog(BuildContext context) async {
  final session = SessionScope.read(context);
  final controller = TextEditingController(text: session.displayName ?? '');
  final name = await showDialog<String>(
    context: context,
    builder: (c) => AlertDialog(
      title: const Text('Name ändern'),
      content: TextField(
        controller: controller,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(hintText: 'Wie sollen wir dich nennen?'),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(c).pop(), child: const Text('Abbrechen')),
        FilledButton(
          onPressed: () => Navigator.of(c).pop(controller.text.trim()),
          child: const Text('SPEICHERN'),
        ),
      ],
    ),
  );
  controller.dispose();
  if (name == null || name.isEmpty || !context.mounted) return;
  try {
    await session.updateDisplayName(name);
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Der Name konnte nicht gespeichert werden.')));
    }
  }
}

Future<void> confirmSignOut(BuildContext context) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: const Text('Abmelden'),
      content: const Text('Willst du dich abmelden?'),
      actions: [
        TextButton(onPressed: () => Navigator.of(c).pop(false), child: const Text('Abbrechen')),
        FilledButton(
            onPressed: () => Navigator.of(c).pop(true), child: const Text('ABMELDEN')),
      ],
    ),
  );
  if (ok == true && context.mounted) await SessionScope.read(context).signOut();
}
