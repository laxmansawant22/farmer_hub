import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart';
import '../translations.dart';
import 'login_screen.dart';
import 'registration_screen.dart'; // 📍 Ensure this is imported for 'Create an Account'

class LoginSelectionScreen extends StatefulWidget {
  const LoginSelectionScreen({super.key});

  @override
  State<LoginSelectionScreen> createState() => _LoginSelectionScreenState();
}

class _LoginSelectionScreenState extends State<LoginSelectionScreen> {
  String get _currentLangName {
    if (languageNotifier.value.languageCode == 'mr') return "मराठी";
    if (languageNotifier.value.languageCode == 'hi') return "हिंदी";
    return "English";
  }

  void _showLanguagePicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                AppTranslations.translate(context, 'select_language'),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF4A6D41)),
              ),
              const SizedBox(height: 10),
              const Divider(),
              _languageOption("English", const Locale('en')),
              _languageOption("Hindi (हिंदी)", const Locale('hi')),
              _languageOption("Marathi (मराठी)", const Locale('mr')),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _languageOption(String lang, Locale locale) {
    bool isSelected = languageNotifier.value == locale;
    return ListTile(
      leading: Icon(Icons.language, color: isSelected ? const Color(0xFF4A6D41) : Colors.grey),
      title: Text(
        lang,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? const Color(0xFF4A6D41) : Colors.black87,
        ),
      ),
      trailing: isSelected ? const Icon(Icons.check_circle, color: Color(0xFF4A6D41)) : null,
      onTap: () async {
        languageNotifier.value = locale;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('language_code', locale.languageCode);
        if (!mounted) return;
        Navigator.pop(context);
        setState(() {});
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    const primaryGreen = Color(0xFF4A6D41);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(top: 8.0, right: 12.0),
            child: ActionChip(
              avatar: const Icon(Icons.translate, size: 16, color: primaryGreen),
              label: Text(_currentLangName, style: const TextStyle(color: primaryGreen, fontWeight: FontWeight.bold)),
              backgroundColor: primaryGreen.withOpacity(0.1),
              onPressed: _showLanguagePicker,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 25),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 30),
              // 📍 Tractor Icon from your design
              const Icon(Icons.agriculture_rounded, size: 120, color: primaryGreen),
              const SizedBox(height: 10),
              Text(
                "Krishi Market", //
                style: const TextStyle(
                  fontSize: 38,
                  fontWeight: FontWeight.bold,
                  color: primaryGreen,
                ),
              ),
              const SizedBox(height: 50),

              _roleCard(
                title: "I am a Farmer",
                description: "List crops and manage inventory",
                icon: Icons.person_search_rounded,
                role: 'farmer',
              ),
              const SizedBox(height: 16),

              _roleCard(
                title: "I am a Customer",
                description: "Buy fresh produce from farms",
                icon: Icons.shopping_cart_rounded,
                role: 'customer',
              ),
              const SizedBox(height: 16),

              _roleCard(
                title: "I am a Store",
                description: "Manage seeds and fertilizers",
                icon: Icons.storefront_rounded,
                role: 'store',
              ),

              const SizedBox(height: 40),



              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _roleCard({required String title, required String description, required IconData icon, required String role}) {
    return InkWell(
      onTap: () {
        // 📍 Check that LoginScreen class exists in login_screen.dart
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => LoginScreen(role: role)),
        );
      },
      borderRadius: BorderRadius.circular(15),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FBF9),
          border: Border.all(color: Colors.grey.shade300, width: 1),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF4A6D41).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: const Color(0xFF4A6D41), size: 28),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: Color(0xFF2E3D2A)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, color: Colors.grey, size: 18),
          ],
        ),
      ),
    );
  }
}