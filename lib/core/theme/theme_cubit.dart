import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeCubit extends Cubit<ThemeMode> {
  final SharedPreferences sharedPreferences;
  static const String _themeKey = 'app_theme_mode';

  ThemeCubit({required this.sharedPreferences}) : super(ThemeMode.system) {
    _loadTheme();
  }

  void _loadTheme() {
    final themeString = sharedPreferences.getString(_themeKey);
    if (themeString == 'light') {
      emit(ThemeMode.light);
    } else if (themeString == 'dark') {
      emit(ThemeMode.dark);
    } else {
      emit(ThemeMode.system);
    }
  }

  Future<void> toggleTheme() async {
    final newMode = state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    await setTheme(newMode);
  }

  Future<void> setTheme(ThemeMode mode) async {
    String value = 'system';
    if (mode == ThemeMode.light) value = 'light';
    if (mode == ThemeMode.dark) value = 'dark';
    await sharedPreferences.setString(_themeKey, value);
    emit(mode);
  }
}
