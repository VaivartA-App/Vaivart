import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTypography {
  AppTypography._();

  static TextTheme get textTheme => GoogleFonts.interTextTheme();

  static TextStyle get label => GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.03,
      );

  static TextStyle get body => GoogleFonts.inter(fontSize: 13);

  static TextStyle get caption => GoogleFonts.inter(
        fontSize: 11,
        letterSpacing: 0.02,
      );

  static TextStyle get sectionHeader => GoogleFonts.inter(
        fontSize: 10,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.08,
      );
}
