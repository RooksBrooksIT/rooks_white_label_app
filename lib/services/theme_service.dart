import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeService extends ChangeNotifier {
  ThemeService._();
  static final ThemeService instance = ThemeService._();

  Color _primaryColor = Colors.deepPurple;
  Color _secondaryColor = Colors.amber;
  Color _backgroundColor = Colors.white;
  bool _isDarkMode = false;
  String _fontFamily = 'Roboto';
  String _appName = 'ServicePro';
  String _databaseName = 'default_db';
  String? _logoUrl;

  Color get primaryColor => _primaryColor;
  Color get secondaryColor => _secondaryColor;
  Color get backgroundColor => _backgroundColor;
  bool get isDarkMode => _isDarkMode;
  String get fontFamily => _fontFamily;
  String get appName => _appName;
  String get databaseName => _databaseName;
  String? get logoUrl => _logoUrl;

  ThemeData get themeData {
    final base = _isDarkMode ? ThemeData.dark() : ThemeData.light();
    return base.copyWith(
      primaryColor: _primaryColor,
      colorScheme: ColorScheme.fromSeed(
        seedColor: _primaryColor,
        secondary: _secondaryColor,
        brightness: _isDarkMode ? Brightness.dark : Brightness.light,
        surface:
            _backgroundColor, // Use background color for surface/background
      ),
      textTheme: GoogleFonts.getTextTheme(_fontFamily, base.textTheme),
      scaffoldBackgroundColor: _backgroundColor,
      canvasColor: _backgroundColor,
      appBarTheme: AppBarTheme(
        backgroundColor: _backgroundColor,
        foregroundColor:
            _isDarkMode || _backgroundColor.computeLuminance() < 0.5
            ? Colors.white
            : Colors.black,
        elevation: 0,
      ),
    );
  }

  /// Default Rooks & Brooks theme for subscription screens
  ThemeData get defaultTheme {
    const primary = Colors.deepPurple;
    const secondary = Colors.amber;
    const background = Colors.white;
    const fontFamily = 'Roboto';

    final base = ThemeData.light();
    return base.copyWith(
      primaryColor: primary,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        secondary: secondary,
        brightness: Brightness.light,
        surface: background,
      ),
      textTheme: GoogleFonts.getTextTheme(fontFamily, base.textTheme),
      scaffoldBackgroundColor: background,
      canvasColor: background,
      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
    );
  }

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final primaryValue = prefs.getInt('primaryColor');
    final secondaryValue = prefs.getInt('secondaryColor');
    final backgroundValue = prefs.getInt('backgroundColor');

    if (primaryValue != null) _primaryColor = Color(primaryValue);
    if (secondaryValue != null) _secondaryColor = Color(secondaryValue);
    if (backgroundValue != null) {
      _backgroundColor = Color(backgroundValue);
    } else {
      // Default based on mode if not set
      _backgroundColor = prefs.getBool('isDarkMode') == true
          ? const Color(0xFF121212)
          : Colors.white;
    }

    _isDarkMode = prefs.getBool('isDarkMode') ?? false;
    _fontFamily = prefs.getString('fontFamily') ?? 'Roboto';
    _appName = prefs.getString('appName') ?? 'ServicePro';
    _databaseName = prefs.getString('databaseName') ?? 'default_db';
    _logoUrl = prefs.getString('logoUrl');
    notifyListeners();
  }

  Future<void> saveToLocal() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('primaryColor', _primaryColor.value);
    await prefs.setInt('secondaryColor', _secondaryColor.value);
    await prefs.setInt('backgroundColor', _backgroundColor.value);
    await prefs.setBool('isDarkMode', _isDarkMode);
    await prefs.setString('fontFamily', _fontFamily);
    await prefs.setString('appName', _appName);
    await prefs.setString('databaseName', _databaseName);
    if (_logoUrl != null) {
      await prefs.setString('logoUrl', _logoUrl!);
    } else {
      await prefs.remove('logoUrl');
    }
  }

  void updateTheme({
    required Color primary,
    required Color secondary,
    required Color backgroundColor,
    required bool isDarkMode,
    required String fontFamily,
    required String appName,
    String? logoUrl,
    String? databaseName,
  }) {
    _primaryColor = primary;
    _secondaryColor = secondary;
    _backgroundColor = backgroundColor;
    _isDarkMode = isDarkMode;
    _fontFamily = fontFamily;
    _appName = appName;
    if (databaseName != null) _databaseName = databaseName;
    _logoUrl = logoUrl;
    notifyListeners();
    saveToLocal();
  }

  void loadFromMap(Map<String, dynamic> data) {
    if (data['primaryColor'] != null) {
      _primaryColor = Color(data['primaryColor']);
    }
    if (data['secondaryColor'] != null) {
      _secondaryColor = Color(data['secondaryColor']);
    }
    if (data['backgroundColor'] != null) {
      _backgroundColor = Color(data['backgroundColor']);
    }
    if (data['useDarkMode'] != null) {
      _isDarkMode = data['useDarkMode'];
    }
    if (data['fontFamily'] != null) {
      _fontFamily = data['fontFamily'];
    }
    if (data['appName'] != null) {
      _appName = data['appName'];
    }
    if (data['databaseName'] != null) {
      _databaseName = data['databaseName'];
    }
    if (data['logoUrl'] != null) {
      _logoUrl = data['logoUrl'];
    }
    notifyListeners();
    saveToLocal();
  }
}
