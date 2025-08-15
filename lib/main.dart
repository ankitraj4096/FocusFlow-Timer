import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fluttertoast/fluttertoast.dart';

import 'theme.dart';
import 'screens/timer_page.dart';

void main() {
  runApp(ProductivityTimerApp());
}

class ProductivityTimerApp extends StatefulWidget {
  @override
  _ProductivityTimerAppState createState() => _ProductivityTimerAppState();
}

class _ProductivityTimerAppState extends State<ProductivityTimerApp> {
  ThemeMode _themeMode = ThemeMode.system;

  @override
  void initState() {
    super.initState();
    _loadThemeMode();
  }

  Future<void> _loadThemeMode() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    int? themeIndex = prefs.getInt('themeMode');
    setState(() {
      if (themeIndex == null) {
        _themeMode = ThemeMode.system;
      } else {
        _themeMode = ThemeMode.values[themeIndex];
      }
    });
  }

  Future<void> _saveThemeMode(ThemeMode mode) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setInt('themeMode', mode.index);
  }

  void _onThemeModeChanged(ThemeMode newMode) {
    setState(() {
      _themeMode = newMode;
    });
    _saveThemeMode(newMode);
    Fluttertoast.showToast(
      msg: "Theme changed to ${newMode.toString().split('.').last}",
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Productivity Timer',
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: _themeMode,
      debugShowCheckedModeBanner: false,
      home: TimerPage(
        themeMode: _themeMode,
        onThemeModeChanged: _onThemeModeChanged,
      ),
    );
  }
}
