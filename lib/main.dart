import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/splash_screen.dart'; // Ensure your path is correct

// 📍 Global notifier for the theme
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 📍 Load saved theme preference on startup
  final prefs = await SharedPreferences.getInstance();
  bool isDark = prefs.getBool('isDarkMode') ?? false;
  themeNotifier.value = isDark ? ThemeMode.dark : ThemeMode.light;

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // 📍 ValueListenableBuilder rebuilds the app when themeNotifier changes
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, ThemeMode currentMode, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Krishi Market',

          // 📍 Light Theme Settings
          theme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.light,
            primaryColor: const Color(0xFF4A6D41),
            colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF4A6D41)),
          ),

          // 📍 Dark Theme Settings
          darkTheme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.dark,
            primaryColor: const Color(0xFF4A6D41),
            scaffoldBackgroundColor: const Color(0xFF121212),
          ),

          themeMode: currentMode,
          home: const SplashScreen(),
        );
      },
    );
  }
}