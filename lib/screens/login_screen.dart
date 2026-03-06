import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'home_screen.dart';
import 'customer_market_screen.dart';
import 'registration_screen.dart'; // 📍 Ensure this matches your filename

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isObscured = true;
  final _userController = TextEditingController();
  final _passController = TextEditingController();

  Future<void> _handleLogin() async {
    final prefs = await SharedPreferences.getInstance();
    String username = _userController.text.trim();
    String password = _passController.text;

    String? savedPass = prefs.getString('pass_$username');
    bool? isFarmer = prefs.getBool('isFarmer_$username');

    // 📍 Fix: Check 'mounted' before using context after an async await
    if (!mounted) return;

    if (savedPass != null && savedPass == password) {
      if (isFarmer == true) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (c) => const HomeScreen()));
      } else {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (c) => const CustomerMarketScreen()));
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Invalid Username or Password"), backgroundColor: Colors.red)
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
          backgroundColor: const Color(0xFF4A6D41),
          title: const Text("Login", style: TextStyle(color: Colors.white)),
          centerTitle: true
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(25),
        child: Column(
          children: [
            const SizedBox(height: 40),
            const Icon(Icons.lock_outline, size: 100, color: Color(0xFF4A6D41)),
            const SizedBox(height: 50),
            TextField(
              controller: _userController,
              decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  hintText: "Username",
                  prefixIcon: const Icon(Icons.person, color: Color(0xFF4A6D41)),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none)
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _passController,
              obscureText: _isObscured,
              decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  hintText: "Password",
                  prefixIcon: const Icon(Icons.lock, color: Color(0xFF4A6D41)),
                  suffixIcon: IconButton(
                      icon: Icon(_isObscured ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => _isObscured = !_isObscured)
                  ),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none)
              ),
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4A6D41)),
                onPressed: _handleLogin,
                child: const Text("Login", style: TextStyle(color: Colors.white, fontSize: 18)),
              ),
            ),
            const SizedBox(height: 40),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text("Don't have an account? "),
                GestureDetector(
                  // 📍 Fix: Navigates to the correct RegistrationScreen class
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const RegistrationScreen(isFarmer: true))),
                  child: const Text("Register", style: TextStyle(color: Color(0xFF4A6D41), fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}