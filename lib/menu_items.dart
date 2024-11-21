import 'package:flutter/material.dart';
import 'package:kwf_energiemonitor/energy_list.dart';
import 'package:kwf_energiemonitor/home.dart';

// Defining the pages of the main screen
List<MainScreenPage> mainScreenPages = [
  MainScreenPage(
    title: 'Home',
    label: 'Home',
    menuIcon: Icons.house,
    widget: const Center(child: SizedBox(width: 600, child: HomePage())),
  ),
  MainScreenPage(
      title: 'Eintragen',
      label: 'Eintragen',
      menuIcon: Icons.add_circle,
      widget: const Center(child: SizedBox(width: 600, child: EnergyList()))),
  MainScreenPage(
      title: 'Download',
      label: 'Download',
      menuIcon: Icons.cloud_download,
      widget: const Center(
          child: Text("Hier kannst du später deine Daten herunterladen"))),
];

// Main screen page model
class MainScreenPage {
  MainScreenPage(
      {required this.title,
      required this.label,
      required this.menuIcon,
      required this.widget});

  final Widget widget;
  final String title;
  final String label;
  final IconData menuIcon;
}
