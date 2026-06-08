import 'package:flutter/material.dart';

final Color _bg = const Color(0xFF0F1724);
final Color _surface = const Color(0xFF0B1320);
final Color _accent = const Color(0xFFC79A2E);
final Color _textPrimary = const Color(0xFFE6F0F6);
final Color _textSecondary = const Color(0xFF9AA4B2);

final ThemeData alfredTheme = ThemeData(
  brightness: Brightness.dark,
  primaryColor: _bg,
  scaffoldBackgroundColor: _bg,
  cardColor: _surface,
  colorScheme: ColorScheme.dark(
    primary: _accent,
    secondary: _textSecondary,
    surface: _surface,
    background: _bg,
    onPrimary: Colors.black,
    onSurface: _textPrimary,
  ),
  textTheme: TextTheme(
    titleLarge: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600, fontSize: 18, color: _textPrimary),
    titleMedium: TextStyle(fontFamily: 'Inter', fontSize: 15, color: _textPrimary),
    bodyLarge: TextStyle(fontFamily: 'Inter', fontSize: 14, color: _textPrimary),
    bodyMedium: TextStyle(fontFamily: 'Inter', fontSize: 13, color: _textSecondary),
    bodySmall: TextStyle(fontFamily: 'Inter', fontSize: 12, color: _textSecondary),
  ),
  appBarTheme: AppBarTheme(
    backgroundColor: _surface,
    elevation: 0,
    titleTextStyle: TextStyle(color: _textPrimary, fontSize: 18, fontWeight: FontWeight.w600, fontFamily: 'Inter'),
    iconTheme: IconThemeData(color: _textPrimary),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: _accent,
      foregroundColor: Colors.black,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
  ),
  floatingActionButtonTheme: FloatingActionButtonThemeData(
    backgroundColor: _accent,
    foregroundColor: Colors.black,
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: _surface,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
    hintStyle: TextStyle(color: _textSecondary),
  ),
);