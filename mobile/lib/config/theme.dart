import 'package:flutter/material.dart';

import 'app_constants.dart';

final nazarTheme = ThemeData(
  colorScheme: ColorScheme.fromSeed(seedColor: kGreen),
  useMaterial3: true,
  scaffoldBackgroundColor: kBg,
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
