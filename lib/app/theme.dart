import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Flork palette, the dark side of flork.family's tokens.
abstract final class Fk {
  static const bg = Color(0xFF141016);
  static const surface = Color(0xFF1E1923);
  static const card = Color(0xFF28212E);
  static const cardHi = Color(0xFF332A3A);
  static const line = Color(0x14FFEBFA);
  static const lineStrong = Color(0x29FFEBFA);
  static const chalk = Color(0xFFF6F0F8);
  static const muted = Color(0xFFA99FB0);
  static const knit = Color(0xFFFF3D8B);
  static const knitSoft = Color(0x29FF3D8B);
  static const up = Color(0xFF3ECF8E);
  static const down = Color(0xFFF0585A);
  static const gold = Color(0xFFE0B23A);

  static const r = 20.0;
  static const rPill = 999.0;

  /// Comic display face for campaign and section titles.
  static const display = TextStyle(fontFamily: 'ComicKats', color: chalk, height: 1.05);
}

ThemeData buildTheme() {
  final base = ThemeData(brightness: Brightness.dark, useMaterial3: true);
  final text = GoogleFonts.figtreeTextTheme(base.textTheme).apply(bodyColor: Fk.chalk, displayColor: Fk.chalk);
  return base.copyWith(
    scaffoldBackgroundColor: Fk.bg,
    colorScheme: const ColorScheme.dark(
      primary: Fk.knit,
      onPrimary: Colors.white,
      surface: Fk.surface,
      onSurface: Fk.chalk,
      error: Fk.down,
    ),
    textTheme: text,
    appBarTheme: AppBarTheme(
      backgroundColor: Fk.bg,
      foregroundColor: Fk.chalk,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
    ),
    splashFactory: InkSparkle.splashFactory,
    dividerColor: Fk.line,
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Fk.card,
      hintStyle: const TextStyle(color: Fk.muted),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: Fk.knit,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(56),
        shape: const StadiumBorder(),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating, backgroundColor: Fk.cardHi),
  );
}
