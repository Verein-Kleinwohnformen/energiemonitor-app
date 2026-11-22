// Tokens aus dem Design System "Verein Kleinwohnformen" (tokens.json, Version 2,
// Ergaenzung Energiemonitor-App vom 21.11.2026). Werte hier nicht neu mischen,
// sondern bei einer neuen Version des Design Systems gesamthaft nachfuehren.
import 'package:flutter/painting.dart';

abstract final class KwfColors {
  // Marke und Grundfarben
  static const gruen = Color(0xFF8ABB3D);
  static const limette = Color(0xFFC2D42E);
  static const blau = Color(0xFF008ABA);
  static const hellblau = Color(0xFFD0E5F9);
  static const anthrazit = Color(0xFF333333);
  static const schwarz = Color(0xFF111111);
  static const grau = Color(0xFF999999);
  static const grauHell = Color(0xFFDDDDDE);
  static const feldrand = Color(0xFFABB0B2);
  static const weiss = Color(0xFFFFFFFF);
  static const signalRot = Color(0xFFE85C41);
  static const gruenDunkel = Color(0xFF4F7A19);
  static const textSekundaer = Color(0xFF5C5C5C);

  /// Seitengrund hinter den Karten, wie in den Mockups der App.
  /// TODO(prüfen): nicht in tokens.json, aus den Mockups uebernommen.
  static const seitengrund = Color(0xFFF7F7F7);

  // Energietraeger, feste Reihenfolge
  static const dataSolar = Color(0xFF6F9E2A);
  static const dataNetz = Color(0xFF008ABA);
  static const dataGas = Color(0xFFD9822B);
  static const dataBatterie = Color(0xFF7A6BBF);
  static const dataHolz = Color(0xFFA8662F);
  static const dataVerbrauch = anthrazit;

  // Klima
  static const klimaInnen = Color(0xFFD9822B);
  static const klimaAussen = Color(0xFF008ABA);
  static const klimaFeuchte = Color(0xFF7A6BBF);

  // Status, nur mit Wort oder Icon verwenden
  static const komfortGut = gruenDunkel;
  static const komfortMittel = Color(0xFFE0A400);
  static const komfortSchlecht = signalRot;

  // Sequenzielle Skala (Heatmaps)
  static const seq100 = Color(0xFFE6F2F9);
  static const seq200 = Color(0xFFBFDFF0);
  static const seq300 = Color(0xFF8AC5E3);
  static const seq400 = Color(0xFF4EA7D3);
  static const seq500 = Color(0xFF008ABA);
  static const seq600 = Color(0xFF006A91);
  static const seq700 = Color(0xFF00445E);
}

abstract final class KwfSpace {
  static const buttonY = 9.0;
  static const buttonX = 20.0;
  static const card = 20.0;
  static const gutter = 40.0;
  static const section = 80.0;
  static const markGap = 2.0;
  static const chart = 16.0;

  /// Seitenrand auf dem Handy, wie in den Mockups.
  static const page = 16.0;
}

abstract final class KwfRadius {
  static const none = 0.0;
  static const sm = 3.0;
  static const md = 4.0;
  static const pill = 30.0;
  static const bar = 4.0;
}

abstract final class KwfShadows {
  /// shadow-card: 1px 1px 30px 0 rgba(0,0,0,0.06)
  static const card = [
    BoxShadow(offset: Offset(1, 1), blurRadius: 30, color: Color(0x0F000000)),
  ];

  /// shadow-soft: 0 0 35px -5px grau-hell
  static const soft = [
    BoxShadow(blurRadius: 35, spreadRadius: -5, color: KwfColors.grauHell),
  ];

  /// shadow-tight: 3px 3px 10px 0 grau-hell
  static const tight = [
    BoxShadow(offset: Offset(3, 3), blurRadius: 10, color: KwfColors.grauHell),
  ];
}
