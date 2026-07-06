import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static ThemeData get lightTheme => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF4F7FB),
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF00D1FF),
          secondary: Color(0xFF00C853),
          surface: Color(0xFFFFFFFF),
          error: Color(0xFFEF4444),
        ),
        textTheme: GoogleFonts.interTextTheme(ThemeData.light().textTheme),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: const Color(0xFFFFFFFF),
          indicatorColor: const Color(0xFF00D1FF).withOpacity(0.16),
          labelTextStyle: MaterialStateProperty.all(
            GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800),
          ),
        ),
      );

  static ThemeData get darkTheme => lightTheme;
}
