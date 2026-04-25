import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_constants.dart';

// ─── Aydınlık Tema — Parşömen & Zümrüt ───────────────────────────────────────

final nazarTheme = ThemeData(
  colorScheme: ColorScheme.fromSeed(seedColor: kGreen),
  useMaterial3: true,
  scaffoldBackgroundColor: kBg,
  textTheme: GoogleFonts.cormorantGaramondTextTheme().copyWith(
    bodyMedium: GoogleFonts.cormorantGaramond(color: const Color(0xFF3D3420)),
    bodyLarge: GoogleFonts.cormorantGaramond(color: const Color(0xFF3D3420)),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: kGreen,
      foregroundColor: Colors.white,
      disabledBackgroundColor: kGreen.withValues(alpha: 0.5),
      padding: const EdgeInsets.symmetric(vertical: kButtonPaddingV),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: kGold.withValues(alpha: 0.55)),
      ),
      elevation: 0,
    ),
  ),
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(foregroundColor: Colors.grey),
  ),
  snackBarTheme: SnackBarThemeData(
    backgroundColor: Colors.red.shade700,
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
  ),
);

// ─── Karanlık Tema — Lapis Lazuli & Altın ────────────────────────────────────

final nazarDarkTheme = ThemeData(
  colorScheme: ColorScheme.fromSeed(
    seedColor: kGold,
    brightness: Brightness.dark,
    surface: kDarkSurface,
  ),
  useMaterial3: true,
  scaffoldBackgroundColor: kDarkBg,
  textTheme: GoogleFonts.cormorantGaramondTextTheme(
    ThemeData.dark().textTheme,
  ).copyWith(
    bodyMedium: GoogleFonts.cormorantGaramond(color: kDarkText),
    bodyLarge: GoogleFonts.cormorantGaramond(color: kDarkText),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: kDarkSurface,
      foregroundColor: kGold,
      disabledBackgroundColor: kDarkSurface.withValues(alpha: 0.5),
      padding: const EdgeInsets.symmetric(vertical: kButtonPaddingV),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: kGold.withValues(alpha: 0.6)),
      ),
      elevation: 0,
    ),
  ),
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(
      foregroundColor: kGold.withValues(alpha: 0.7),
    ),
  ),
  snackBarTheme: SnackBarThemeData(
    backgroundColor: Colors.red.shade900,
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
  ),
);
