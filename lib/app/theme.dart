import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.system);

final ThemeData lightTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.light,
  colorSchemeSeed: Colors.indigo,
  appBarTheme: const AppBarTheme(
    centerTitle: true,
    elevation: 0,
  ),
  cardTheme: const CardTheme(
    elevation: 1,
    margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      minimumSize: const Size(double.infinity, 48),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
  ),
);

final ThemeData darkTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  colorSchemeSeed: Colors.indigo,
  appBarTheme: const AppBarTheme(
    centerTitle: true,
    elevation: 0,
  ),
  cardTheme: const CardTheme(
    elevation: 1,
    margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      minimumSize: const Size(double.infinity, 48),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
  ),
);

ThemeData applyDynamicColor(ThemeData theme, ColorScheme dynamic) {
  return theme.copyWith(
    colorScheme: dynamic,
  );
}
