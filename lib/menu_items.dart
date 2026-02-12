import 'package:flutter/material.dart';
import 'package:kwf_energiemonitor/energy_list.dart';
import 'package:kwf_energiemonitor/home.dart';
import 'package:kwf_energiemonitor/data_export.dart';
import 'package:kwf_energiemonitor/chart_view.dart';
import 'package:kwf_energiemonitor/impressum_screen.dart';

// Defining the pages of the main screen
List<MainScreenPage> mainScreenPages = [
  MainScreenPage(
    title: 'Home',
    label: 'Home',
    menuIcon: Icons.house,
    widget: const SizedBox(width: 600, child: HomePage()),
  ),
  MainScreenPage(
      title: 'Liste',
      label: 'Liste',
      menuIcon: Icons.add_circle,
      widget: const SizedBox(width: 600, child: EnergyList())),
  MainScreenPage(
      title: 'Ansicht',
      label: 'Ansicht',
      menuIcon: Icons.analytics,
      widget: const SizedBox(width: 600, child: ChartView())),
  MainScreenPage(
      title: 'Download',
      label: 'Download',
      menuIcon: Icons.cloud_download,
      widget: const SizedBox(width: 600, child: DataExportPage())),
  MainScreenPage(
      title: 'Impressum',
      label: 'Info',
      menuIcon: Icons.info,
      widget: const SizedBox(width: 600, child: ImpressumScreen())),
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
