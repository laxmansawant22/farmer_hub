import 'package:flutter/material.dart';
import 'package:laxman_1/screens/registration_screen.dart';
import 'login_screen.dart';
import 'registration_screen.dart'; // Ensure you've created this file

class LoginSelectionScreen extends StatelessWidget {
  const LoginSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 🌿 App Branding
              const Icon(Icons.agriculture, size: 100, color: Color(0xFF4A6D41)),
              const SizedBox(height: 20),
              const Text(
                "Krishi Market",
                style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF4A6D41)
                ),
              ),
              const SizedBox(height: 40),

              // 👨‍🌾 Farmer Selection
              _roleCard(
                context,
                title: "I am a Farmer",
                subtitle: "List crops and manage inventory",
                icon: Icons.person_search,
                isFarmer: true,
              ),

              const SizedBox(height: 20),

              // 🛒 Customer Selection
              _roleCard(
                context,
                title: "I am a Customer",
                subtitle: "Buy fresh produce from farms",
                icon: Icons.shopping_cart,
                isFarmer: false,
              ),

              const SizedBox(height: 50),

              // 📝 Direct Registration Option
              const Text("New here?"),
              TextButton(
                onPressed: () {
                  // Default to Farmer registration if they click here
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const RegistrationScreen(isFarmer: true),
                    ),
                  );
                },
                child: const Text(
                  "Create an Account",
                  style: TextStyle(
                      color: Color(0xFF4A6D41),
                      fontWeight: FontWeight.bold,
                      fontSize: 16
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _roleCard(BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isFarmer,
  }) {
    Color primaryColor = const Color(0xFF4A6D41);

    return InkWell(
      onTap: () {
        // 🚀 Navigate to LoginScreen
        // You can also pass 'isFarmer' to LoginScreen if you want it to look different
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      },
      borderRadius: BorderRadius.circular(15),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          border: Border.all(color: primaryColor.withOpacity(0.3)),
          borderRadius: BorderRadius.circular(15),
          color: primaryColor.withOpacity(0.05),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: primaryColor,
              child: Icon(icon, color: Colors.white),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      title,
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryColor)
                  ),
                  Text(
                      subtitle,
                      style: const TextStyle(fontSize: 13, color: Colors.black54)
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: primaryColor),
          ],
        ),
      ),
    );
  }
}