import 'package:flutter/material.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  Widget build(BuildContext context) {
    return const SingleChildScrollView(
        child: Column(children: [
      UserText(),
      SizedBox(height: 50),
    ]));
  }
}

class UserText extends StatefulWidget {
  const UserText({super.key});

  @override
  State<UserText> createState() => _UserTextState();
}

class _UserTextState extends State<UserText> {
  @override
  Widget build(BuildContext context) {
    return const Text("Hallo, user!");
  }
}
