import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/registration_screen.dart';
import 'screens/home_screen.dart';
// 📍 Ensure this filename matches your file in the Store directory
import 'Store/store_dashboard_screen.dart';
import 'customer/customer_market_screen.dart';
import 'firebase_options.dart';
import 'notification_service.dart';

import '../screens/login_selection_screen.dart';

final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);
final ValueNotifier<Locale> languageNotifier = ValueNotifier(const Locale('en'));

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    await NotificationService.init();

    final prefs = await SharedPreferences.getInstance();
    themeNotifier.value = (prefs.getBool('isDarkMode') ?? false) ? ThemeMode.dark : ThemeMode.light;
    languageNotifier.value = Locale(prefs.getString('language code') ?? 'en');
  } catch (e) {
    debugPrint("Critical Initialization Error: $e");
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  void _updateUserToken(User user) async {
    try {
      String? token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.email)
            .update({'fcmToken': token});
      }
    } catch (e) {
      debugPrint("FCM Token Update Error: $e");
    }
  }

  Route _createSlideRoute(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(1.0, 0.0);
        const end = Offset.zero;
        const curve = Curves.easeInOutExpo;

        var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
        return SlideTransition(
          position: animation.drive(tween),
          child: child,
        );
      },
      transitionDuration: const Duration(milliseconds: 600),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, currentMode, __) {
        return ValueListenableBuilder<Locale>(
          valueListenable: languageNotifier,
          builder: (_, currentLocale, __) {
            return MaterialApp(
              debugShowCheckedModeBanner: false,
              locale: currentLocale,
              supportedLocales: const [Locale('en'), Locale('mr'), Locale('hi')],
              localizationsDelegates: const [
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              themeMode: currentMode,

              theme: ThemeData(
                useMaterial3: true,
                colorSchemeSeed: const Color(0xFF4A6D41),
                brightness: Brightness.light,
              ),

              darkTheme: ThemeData(
                useMaterial3: true,
                colorSchemeSeed: const Color(0xFF4A6D41),
                brightness: Brightness.dark,
              ),

              home: StreamBuilder<User?>(
                stream: FirebaseAuth.instance.authStateChanges(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) return const SplashScreen();

                  return FutureBuilder(
                    future: Future.delayed(const Duration(milliseconds: 1500)),
                    builder: (context, timer) {
                      if (timer.connectionState != ConnectionState.done) return const SplashScreen();

                      if (snapshot.hasData && snapshot.data != null) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          _updateUserToken(snapshot.data!);
                        });

                        return FutureBuilder<DocumentSnapshot>(
                          future: FirebaseFirestore.instance.collection('users').doc(snapshot.data!.email).get(),
                          builder: (context, userSnapshot) {
                            if (userSnapshot.connectionState == ConnectionState.waiting) return const SplashScreen();

                            if (userSnapshot.hasData && userSnapshot.data!.exists) {
                              final data = userSnapshot.data!.data() as Map<String, dynamic>?;
                              String role = data?['role'] ?? 'farmer';

                              // 📍 FIXED: Use StoreScreen() to match your class name
                              if (role == 'store') return const StoreScreen();
                              if (role == 'customer') return const CustomerMarketScreen();
                              return const HomeScreen();
                            }
                            return const LoginSelectionScreen();
                          },
                        );
                      }

                      return const LoginSelectionScreen();
                    },
                  );
                },
              ),

              onGenerateRoute: (settings) {
                if (settings.name == '/login') {
                  final String role = settings.arguments as String? ?? 'farmer';
                  return _createSlideRoute(LoginScreen(role: role));
                }
                if (settings.name == '/register') {
                  final String role = settings.arguments as String? ?? 'farmer';
                  return _createSlideRoute(RegistrationScreen(role: role));
                }
                // 📍 Add this for the Logout logic in StoreScreen to work
                if (settings.name == '/login_selection') {
                  return _createSlideRoute(const LoginSelectionScreen());
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