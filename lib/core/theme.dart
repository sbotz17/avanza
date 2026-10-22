import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'constants.dart';

ThemeData buildLightTheme() {
  final base = ThemeData.light(useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: kBgLight,
    colorScheme: const ColorScheme.light(
      primary: kActiveColor,
      secondary: kDoneColor,
      surface: kCardLight,
      onSurface: kFgLight,
      outline: kBorderLight,
    ),
    cardTheme: const CardThemeData(
      color: kCardLight,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(14)),
        side: BorderSide(color: kBorderLight),
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: kBgLight,
      foregroundColor: kFgLight,
      elevation: 0,
      titleTextStyle: GoogleFonts.inter(
        fontSize: 17,
        fontWeight: FontWeight.w700,
        color: kFgLight,
      ),
    ),
    textTheme: base.textTheme.apply(
      fontFamily: GoogleFonts.inter().fontFamily,
      bodyColor: kFgLight,
      displayColor: kFgLight,
    ).copyWith(
      bodyMedium: GoogleFonts.inter(color: kFgLight, fontSize: 14),
      bodySmall: GoogleFonts.inter(color: kFg2Light, fontSize: 12),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: kCardLight,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: kBorderLight),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: kBorderLight),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: kActiveColor, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    ),
    dividerColor: kBorderLight,
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: kActiveColor,
      foregroundColor: Colors.white,
    ),
  );
}

ThemeData buildDarkTheme() {
  final base = ThemeData.dark(useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: kBgDark,
    colorScheme: const ColorScheme.dark(
      primary: kActiveColorDark,
      secondary: kDoneColorDark,
      surface: kCardDark,
      onSurface: kFgDark,
      outline: kBorderDark,
    ),
    cardTheme: const CardThemeData(
      color: kCardDark,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(14)),
        side: BorderSide(color: kBorderDark),
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: kBgDark,
      foregroundColor: kFgDark,
      elevation: 0,
      titleTextStyle: GoogleFonts.inter(
        fontSize: 17,
        fontWeight: FontWeight.w700,
        color: kFgDark,
      ),
    ),
    textTheme: base.textTheme.apply(
      fontFamily: GoogleFonts.inter().fontFamily,
      bodyColor: kFgDark,
      displayColor: kFgDark,
    ).copyWith(
      bodyMedium: GoogleFonts.inter(color: kFgDark, fontSize: 14),
      bodySmall: GoogleFonts.inter(color: kFg2Dark, fontSize: 12),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: kCardDark,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: kBorderDark),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: kBorderDark),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: kActiveColorDark, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    ),
    dividerColor: kBorderDark,
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: kActiveColorDark,
      foregroundColor: Colors.white,
    ),
  );
}
