import 'package:flutter/material.dart';

class ThemeService extends ChangeNotifier {
  ThemeService._();
  static final ThemeService instance = ThemeService._();

  Color _primaryColor = Colors.deepPurple;
  Color _secondaryColor = Colors.amber;
  bool _isDarkMode = false;
  String _fontFamily = 'Roboto';

  Color get primaryColor => _primaryColor;
  Color get secondaryColor => _secondaryColor;
  bool get isDarkMode => _isDarkMode;
  String get fontFamily => _fontFamily;

  ThemeData get themeData {
    final base = _isDarkMode ? ThemeData.dark() : ThemeData.light();
    return base.copyWith(
      primaryColor: _primaryColor,
      colorScheme: ColorScheme.fromSeed(
        seedColor: _primaryColor,
        secondary: _secondaryColor,
        brightness: _isDarkMode ? Brightness.dark : Brightness.light,
      ),
      textTheme: base.textTheme.apply(fontFamily: _fontFamily),
      useMaterial3: true,
      // You can customize more components here based on the colors
      appBarTheme: AppBarTheme(
        backgroundColor: _isDarkMode ? Colors.grey[900] : Colors.white,
        foregroundColor: _isDarkMode ? Colors.white : Colors.black,
      ),
    );
  }

  void updateTheme({
    required Color primary,
    required Color secondary,
    required bool isDarkMode,
    required String fontFamily,
  }) {
    _primaryColor = primary;
    _secondaryColor = secondary;
    _isDarkMode = isDarkMode;
    _fontFamily = fontFamily;
    notifyListeners();
  }

  void loadFromMap(Map<String, dynamic> data) {
    if (data['primaryColor'] != null) {
      _primaryColor = Color(data['primaryColor']);
    }
    if (data['secondaryColor'] != null) {
      _secondaryColor = Color(data['secondaryColor']);
    }
    if (data['useDarkMode'] != null) {
      _isDarkMode = data['useDarkMode'];
    }
    if (data['fontFamily'] != null) {
      _fontFamily = data['fontFamily'];
    }
    notifyListeners();
  }
}
