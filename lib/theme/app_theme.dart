import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Executive look-and-feel for the Legal ERP.
///   Primary  : Deep Navy Blue (#001F3F)
///   Highlight: Muted Gold     (#D4AF37)
///   Surface  : Off-White       (#F8F9FA)
class AppColors {
  static const navy = Color(0xFF001F3F);
  static const gold = Color(0xFFD4AF37);
  static const offWhite = Color(0xFFF8F9FA);
  static const navyDark = Color(0xFF000F1F);
  static const navySoft = Color(0xFF13325C);
  static const goldSoft = Color(0xFFE8C766);
  static const ink = Color(0xFF1A1A1A);
  static const danger = Color(0xFFB71C1C);
  static const success = Color(0xFF1B5E20);
  static const warn = Color(0xFFB26A00);
  static const divider = Color(0xFFE3E6EA);
}

class AppTheme {
  static ThemeData light() {
    final base = ThemeData.light(useMaterial3: true);
    final textTheme = GoogleFonts.cairoTextTheme(base.textTheme).apply(
      bodyColor: AppColors.ink,
      displayColor: AppColors.navy,
    );

    return base.copyWith(
      colorScheme: const ColorScheme.light(
        primary: AppColors.navy,
        onPrimary: Colors.white,
        secondary: AppColors.gold,
        onSecondary: AppColors.navy,
        surface: Colors.white,
        onSurface: AppColors.ink,
        error: AppColors.danger,
      ),
      scaffoldBackgroundColor: AppColors.offWhite,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.cairo(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actionsIconTheme: const IconThemeData(color: AppColors.gold),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 1.5,
        margin: const EdgeInsets.all(8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.divider),
        ),
      ),
      drawerTheme: const DrawerThemeData(
        backgroundColor: AppColors.navy,
        scrimColor: Color(0x88000000),
        width: 280,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.divider,
        thickness: 1,
        space: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        labelStyle: GoogleFonts.cairo(color: AppColors.navy),
        hintStyle: GoogleFonts.cairo(color: Colors.black45),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.gold, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.danger),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.gold,
          foregroundColor: AppColors.navy,
          textStyle: GoogleFonts.cairo(fontWeight: FontWeight.w700),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.navy,
          side: const BorderSide(color: AppColors.navy),
          textStyle: GoogleFonts.cairo(fontWeight: FontWeight.w600),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.navy,
          textStyle: GoogleFonts.cairo(fontWeight: FontWeight.w600),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.gold,
        foregroundColor: AppColors.navy,
      ),
      dataTableTheme: DataTableThemeData(
        headingRowColor:
            WidgetStatePropertyAll(AppColors.navy.withValues(alpha: 0.05)),
        headingTextStyle: GoogleFonts.cairo(
          color: AppColors.navy,
          fontWeight: FontWeight.w800,
        ),
        dataTextStyle: GoogleFonts.cairo(color: AppColors.ink),
        dividerThickness: 1,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.offWhite,
        side: const BorderSide(color: AppColors.divider),
        labelStyle: GoogleFonts.cairo(color: AppColors.navy),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.navy,
        contentTextStyle: GoogleFonts.cairo(color: Colors.white),
      ),
    );
  }
}
