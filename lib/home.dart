import 'package:flutter/material.dart';
import 'package:kwf_energiemonitor/user.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
        child: Padding(
            padding: EdgeInsets.all(18),
            child: Column(children: [
              UserText(),
              const SizedBox(height: 50),
            ])));
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

  sendNewNickname() async {
    if (form.currentState!.validate()) {
      form.currentState!.save();
      setState(() {
        isSending = true;
      });
      await AppUser().updateNickname(enteredName!);
      setState(() {
        isSending = false;
        isEdit = false;
      });
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
