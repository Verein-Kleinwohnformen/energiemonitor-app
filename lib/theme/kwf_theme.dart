import 'package:flutter/material.dart';

import 'kwf_tokens.dart';

const kFontFamily = 'Inter';

/// Textstil in Inter. Inter liegt als variable Schrift vor, darum wird das
/// Gewicht zusaetzlich als Variation gesetzt.
TextStyle kwfText(
  double size, {
  FontWeight weight = FontWeight.w300,
  Color color = KwfColors.anthrazit,
  double? height,
  double? letterSpacing,
}) {
  return TextStyle(
    fontFamily: kFontFamily,
    fontSize: size,
    fontWeight: weight,
    fontVariations: [FontVariation.weight(weight.value.toDouble())],
    color: color,
    height: height,
    letterSpacing: letterSpacing,
  );
}

/// Stile, die in der App immer wieder vorkommen (aus den Mockups).
abstract final class KwfText {
  static TextStyle pageTitle = kwfText(24, weight: FontWeight.w600, height: 30 / 24);
  static TextStyle screenTitle = kwfText(22, weight: FontWeight.w600);
  static TextStyle sectionTitle = kwfText(16, weight: FontWeight.w600);
  static TextStyle cardTitle = kwfText(14, weight: FontWeight.w600);
  static TextStyle body = kwfText(14, weight: FontWeight.w400, height: 20 / 14);
  static TextStyle bodyLight = kwfText(14, height: 20 / 14);
  static TextStyle small = kwfText(13, weight: FontWeight.w400, height: 19 / 13);
  static TextStyle label = kwfText(13, weight: FontWeight.w500);
  static TextStyle meta = kwfText(12, weight: FontWeight.w400, color: KwfColors.textSekundaer);
  static TextStyle help =
      kwfText(11, weight: FontWeight.w400, color: KwfColors.textSekundaer, height: 16 / 11);
  static TextStyle kicker = kwfText(11,
      weight: FontWeight.w600, color: KwfColors.textSekundaer, letterSpacing: 0.8);
  static TextStyle button =
      kwfText(12, weight: FontWeight.w600, letterSpacing: 0.96, height: 14 / 12);
  static TextStyle number = kwfText(26);
  static TextStyle link = kwfText(12, weight: FontWeight.w600, color: KwfColors.gruenDunkel);
}

ThemeData buildKwfTheme() {
  const scheme = ColorScheme(
    brightness: Brightness.light,
    primary: KwfColors.gruen,
    onPrimary: KwfColors.anthrazit,
    secondary: KwfColors.gruenDunkel,
    onSecondary: KwfColors.weiss,
    tertiary: KwfColors.blau,
    onTertiary: KwfColors.weiss,
    error: KwfColors.signalRot,
    onError: KwfColors.weiss,
    surface: KwfColors.weiss,
    onSurface: KwfColors.anthrazit,
    onSurfaceVariant: KwfColors.textSekundaer,
    outline: KwfColors.feldrand,
    outlineVariant: KwfColors.grauHell,
  );

  final textTheme = TextTheme(
    headlineSmall: KwfText.pageTitle,
    titleLarge: KwfText.screenTitle,
    titleMedium: KwfText.sectionTitle,
    titleSmall: KwfText.cardTitle,
    bodyLarge: kwfText(16, weight: FontWeight.w400),
    bodyMedium: KwfText.body,
    bodySmall: KwfText.meta,
    labelLarge: KwfText.button,
    labelMedium: KwfText.label,
    labelSmall: KwfText.help,
  );

  final pillShape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(KwfRadius.pill));
  const fieldBorder = OutlineInputBorder(
    borderRadius: BorderRadius.all(Radius.circular(KwfRadius.md)),
    borderSide: BorderSide(color: KwfColors.feldrand),
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: kFontFamily,
    textTheme: textTheme,
    scaffoldBackgroundColor: KwfColors.seitengrund,
    canvasColor: KwfColors.weiss,
    dividerColor: KwfColors.grauHell,
    dividerTheme: const DividerThemeData(color: KwfColors.grauHell, thickness: 1, space: 1),
    splashFactory: NoSplash.splashFactory,
    appBarTheme: AppBarTheme(
      backgroundColor: KwfColors.weiss,
      foregroundColor: KwfColors.anthrazit,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: KwfText.screenTitle,
      shape: const Border(bottom: BorderSide(color: KwfColors.grauHell)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: KwfColors.gruen,
        foregroundColor: KwfColors.anthrazit,
        disabledBackgroundColor: KwfColors.grauHell,
        minimumSize: const Size(64, 44),
        padding: const EdgeInsets.symmetric(
            horizontal: KwfSpace.buttonX, vertical: KwfSpace.buttonY),
        textStyle: KwfText.button,
        shape: pillShape,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: KwfColors.anthrazit,
        minimumSize: const Size(64, 44),
        padding: const EdgeInsets.symmetric(
            horizontal: KwfSpace.buttonX, vertical: KwfSpace.buttonY),
        textStyle: KwfText.button,
        side: const BorderSide(color: KwfColors.feldrand),
        shape: pillShape,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: KwfColors.anthrazit,
        minimumSize: const Size(44, 44),
        textStyle: kwfText(14, weight: FontWeight.w500),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: KwfColors.weiss,
      isDense: false,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
      border: fieldBorder,
      enabledBorder: fieldBorder,
      focusedBorder: fieldBorder.copyWith(
          borderSide: const BorderSide(color: KwfColors.gruenDunkel, width: 2)),
      errorBorder: fieldBorder.copyWith(borderSide: const BorderSide(color: KwfColors.signalRot)),
      focusedErrorBorder: fieldBorder.copyWith(
          borderSide: const BorderSide(color: KwfColors.signalRot, width: 2)),
      errorStyle: kwfText(12, weight: FontWeight.w400, color: KwfColors.signalRot),
      hintStyle: kwfText(16, weight: FontWeight.w400, color: KwfColors.grau),
      suffixStyle: kwfText(14, weight: FontWeight.w400, color: KwfColors.textSekundaer),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: KwfColors.weiss,
      shape: const RoundedRectangleBorder(),
      titleTextStyle: KwfText.sectionTitle,
      contentTextStyle: KwfText.body,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: KwfColors.weiss,
      shape: RoundedRectangleBorder(),
      showDragHandle: true,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: KwfColors.anthrazit,
      contentTextStyle: kwfText(14, weight: FontWeight.w400, color: KwfColors.weiss),
      behavior: SnackBarBehavior.floating,
      shape: const RoundedRectangleBorder(),
    ),
    listTileTheme: ListTileThemeData(
      titleTextStyle: kwfText(15, weight: FontWeight.w500),
      subtitleTextStyle: KwfText.meta,
      iconColor: KwfColors.anthrazit,
      minVerticalPadding: 12,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? KwfColors.weiss : KwfColors.feldrand),
      trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? KwfColors.gruenDunkel : KwfColors.weiss),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: KwfColors.gruenDunkel,
      linearTrackColor: KwfColors.grauHell,
    ),
    datePickerTheme: const DatePickerThemeData(
      backgroundColor: KwfColors.weiss,
      shape: RoundedRectangleBorder(),
    ),
  );
}
