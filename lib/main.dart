import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

// 📍 IMPORT FIX: Ensure these match your actual filenames
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/registration_screen.dart';
import 'screens/home_screen.dart';
import 'screens/store_dashboard_screen.dart';
import 'screens/customer_market_screen.dart';
import 'screens/login_selection_screen.dart'; // 📍 Added this
import 'firebase_options.dart';
import 'notification_service.dart';

final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);
final ValueNotifier<Locale> languageNotifier = ValueNotifier(const Locale('en'));

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    await NotificationService.init();

    final prefs = await SharedPreferences.getInstance();
    bool isDark = prefs.getBool('isDarkMode') ?? false;
    themeNotifier.value = isDark ? ThemeMode.dark : ThemeMode.light;

    String langCode = prefs.getString('language_code') ?? 'en';
    languageNotifier.value = Locale(langCode);

  } catch (e) {
    debugPrint("Initialization Error: $e");
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, ThemeMode currentMode, __) {
        return ValueListenableBuilder<Locale>(
          valueListenable: languageNotifier,
          builder: (_, Locale currentLocale, __) {
            return MaterialApp(
              debugShowCheckedModeBanner: false,
              title: 'Krishi Market',
              locale: currentLocale,
              supportedLocales: const [
                Locale('en'),
                Locale('mr'),
                Locale('hi'),
              ],
              localizationsDelegates: const [
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              themeMode: currentMode,
              theme: ThemeData(
                useMaterial3: true,
                brightness: Brightness.light,
                primaryColor: const Color(0xFF4A6D41),
                colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF4A6D41)),
              ),
              darkTheme: ThemeData(
                useMaterial3: true,
                brightness: Brightness.dark,
              ),

              // 📍 THE FIX: Using a FutureBuilder to ensure splash shows, then redirects
              home: FutureBuilder(
                future: Future.delayed(const Duration(seconds: 3)), // Shows Splash for 3 seconds
                builder: (context, timerSnapshot) {
                  if (timerSnapshot.connectionState == ConnectionState.waiting) {
                    return const SplashScreen();
                  }

                  return StreamBuilder<User?>(
                    stream: FirebaseAuth.instance.authStateChanges(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const SplashScreen();
                      }

                      // If User is Logged In
                      if (snapshot.hasData && snapshot.data != null) {
                        return FutureBuilder<DocumentSnapshot>(
                          future: FirebaseFirestore.instance
                              .collection('users')
                              .doc(snapshot.data!.email)
                              .get(),
                          builder: (context, userSnapshot) {
                            if (userSnapshot.connectionState == ConnectionState.waiting) {
                              return const SplashScreen();
                            }

                            if (userSnapshot.hasData && userSnapshot.data!.exists) {
                              String role = userSnapshot.data!['role'] ?? 'farmer';
                              if (role == 'store') return const StoreDashboardScreen();
                              if (role == 'customer') return const CustomerMarketScreen();
                              return const HomeScreen();
                            }
                            // Logged in but no profile? Send to login
                            return const LoginSelectionScreen();
                          },
                        );
                      }

                      // If NOT Logged In
                      return const LoginSelectionScreen();
                    },
                  );
                },
              ),

              onGenerateRoute: (settings) {
                if (settings.name == '/login') {
                  final String role = settings.arguments as String? ?? 'farmer';
                  return MaterialPageRoute(builder: (c) => LoginScreen(role: role));
                }
                if (settings.name == '/register') {
                  final String role = settings.arguments as String? ?? 'farmer';
                  return MaterialPageRoute(builder: (c) => RegistrationScreen(role: role));
                }
                return null;
              },
            );
          },
        );
      },
    );
  }
}