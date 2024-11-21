import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:kwf_energiemonitor/firebase_options.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:kwf_energiemonitor/main_screen.dart';

final kColorScheme =
    ColorScheme.fromSeed(seedColor: const Color.fromARGB(255, 138, 187, 61));

final kTextTheme = GoogleFonts.latoTextTheme();

final kwfTheme = ThemeData(textTheme: kTextTheme)
    .copyWith(colorScheme: kColorScheme, textTheme: kTextTheme);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const App());
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        theme: kwfTheme,
        home: Container(
            constraints: const BoxConstraints(maxWidth: 600),
            child: const MainScreen()));
  }
}
