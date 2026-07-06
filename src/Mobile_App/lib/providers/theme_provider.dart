import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.light;
  bool alertSound = true;
  bool vibration = true;
  bool notifications = true;
  int nodeTimeoutSeconds = 90;

  ThemeMode get themeMode => _themeMode;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _themeMode = ThemeMode.values[prefs.getInt('themeMode') ?? 1];
    alertSound = prefs.getBool('alertSound') ?? true;
    vibration = prefs.getBool('vibration') ?? true;
    notifications = prefs.getBool('notifications') ?? true;
    nodeTimeoutSeconds = prefs.getInt('nodeTimeoutSeconds') ?? 90;
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode value) async {
    _themeMode = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('themeMode', value.index);
    notifyListeners();
  }

  Future<void> setAlertSound(bool value) async {
    alertSound = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('alertSound', value);
    notifyListeners();
  }

  Future<void> setVibration(bool value) async {
    vibration = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('vibration', value);
    notifyListeners();
  }

  Future<void> setNotifications(bool value) async {
    notifications = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications', value);
    notifyListeners();
  }

  Future<void> setNodeTimeout(int value) async {
    nodeTimeoutSeconds = value.clamp(30, 300);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('nodeTimeoutSeconds', nodeTimeoutSeconds);
    notifyListeners();
  }
}
