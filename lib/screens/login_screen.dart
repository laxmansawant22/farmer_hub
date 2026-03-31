import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'registration_screen.dart';
import '../translations.dart';
import '../Store/store_dashboard_screen.dart';
import 'home_screen.dart';
import '../customer/customer_market_screen.dart';

class LoginScreen extends StatefulWidget {
  final String role;
  const LoginScreen({super.key, required this.role});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
  }

  Future<void> _loadSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _emailController.text = prefs.getString('saved_email') ?? "";
      _passwordController.text = prefs.getString('saved_password') ?? "";
    });
  }

  Future<void> _handleForgotPassword() async {
    if (_emailController.text.isEmpty) {
      _showError(AppTranslations.translate(context, 'enter_email_first'));
      return;
    }

    setState(() => _isLoading = true);
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: _emailController.text.trim(),
      );

      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: Text(AppTranslations.translate(context, 'reset_link_sent')),
          content: Text("${AppTranslations.translate(context, 'check_email_msg')} ${_emailController.text}"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("OK"),
            ),
          ],
        ),
      );
    } on FirebaseAuthException catch (e) {
      _showError(e.message ?? "Error sending reset email");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        setState(() => _isLoading = false);
        return;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      UserCredential userCredential = await FirebaseAuth.instance.signInWithCredential(credential);

      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userCredential.user!.email)
          .get();

      if (userDoc.exists) {
        String userRole = userDoc['role'];
        if (userRole == widget.role) {
          _navigateToDashboard(userRole);
        } else {
          await FirebaseAuth.instance.signOut();
          await GoogleSignIn().signOut();
          _showAccessDeniedDialog(userRole);
        }
      } else {
        await FirebaseAuth.instance.signOut();
        await GoogleSignIn().signOut();
        _showError(AppTranslations.translate(context, 'account_not_found'));
      }
    } catch (e) {
      _showError("Google Error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _navigateToDashboard(String role) {
    if (!mounted) return;
    Widget destination;
    if (role == 'farmer') {
      destination = const HomeScreen();
    } else if (role == 'customer') {
      destination = const CustomerMarketScreen();
    } else {
      destination = const StoreScreen();
    }

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => destination),
          (route) => false,
    );
  }

  void _showAccessDeniedDialog(String registeredRole) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.report_problem_rounded, color: Colors.red, size: 28),
            const SizedBox(width: 10),
            Text(AppTranslations.translate(context, 'access_denied')),
          ],
        ),
        content: Text("${AppTranslations.translate(context, 'role_mismatch_error')} $registeredRole."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppTranslations.translate(context, 'go_back')),
          ),
        ],
      ),
    );
  }

  Future<void> _handleLogin() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      _showError(AppTranslations.translate(context, 'fill_all_fields'));
      return;
    }

    setState(() => _isLoading = true);
    try {
      UserCredential userCredential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userCredential.user!.email)
          .get();

      if (userDoc.exists) {
        String userRole = userDoc['role'];
        if (userRole == widget.role) {
          _navigateToDashboard(userRole);
        } else {
          await FirebaseAuth.instance.signOut();
          _showAccessDeniedDialog(userRole);
        }
      } else {
        _showError("User record not found in database.");
      }
    } on FirebaseAuthException catch (e) {
      _showError(e.message ?? "Login Failed");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 📍 DYNAMIC THEME: Now correctly responds to the widget.role
    final themeColor = widget.role == 'farmer'
        ? const Color(0xFF4A6D41)
        : widget.role == 'store' ? Colors.blue.shade800 : Colors.orange.shade800;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: themeColor),
        title: Text(
          "${AppTranslations.translate(context, widget.role)} ${AppTranslations.translate(context, 'login')}",
          style: TextStyle(color: themeColor, fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(25.0),
        child: Column(
          children: [
            const SizedBox(height: 20),
            // 📍 DYNAMIC ICON: Changes based on role
            Icon(
              widget.role == 'farmer'
                  ? Icons.agriculture
                  : widget.role == 'store'
                  ? Icons.store
                  : Icons.shopping_bag,
              size: 100,
              color: themeColor,
            ),
            const SizedBox(height: 40),

            TextField(
              controller: _emailController,
              decoration: InputDecoration(
                labelText: AppTranslations.translate(context, 'Email'),
                prefixIcon: Icon(Icons.email, color: themeColor),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 20),

            TextField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              decoration: InputDecoration(
                labelText: AppTranslations.translate(context, 'password'),
                prefixIcon: Icon(Icons.lock, color: themeColor),
                suffixIcon: IconButton(
                  icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                ),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),

            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _isLoading ? null : _handleForgotPassword,
                child: Text(
                  AppTranslations.translate(context, 'forgot_password'),
                  style: TextStyle(color: themeColor, fontWeight: FontWeight.bold),
                ),
              ),
            ),

            const SizedBox(height: 15),

            ElevatedButton(
              onPressed: _isLoading ? null : _handleLogin,
              style: ElevatedButton.styleFrom(
                backgroundColor: themeColor,
                minimumSize: const Size(double.infinity, 60),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Text(
                AppTranslations.translate(context, 'login').toUpperCase(),
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),

            const SizedBox(height: 25),
            Row(
              children: [
                Expanded(child: Divider(color: Colors.grey.shade400)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text(AppTranslations.translate(context, 'or')),
                ),
                Expanded(child: Divider(color: Colors.grey.shade400)),
              ],
            ),
            const SizedBox(height: 25),

            OutlinedButton.icon(
              onPressed: _isLoading ? null : _handleGoogleSignIn,
              icon: const Icon(Icons.g_mobiledata, size: 30, color: Colors.black), // Simplified for brevity
              label: Text(
                AppTranslations.translate(context, 'continue_with_google'),
                style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16),
              ),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 60),
                side: const BorderSide(color: Colors.black, width: 2),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),

            const SizedBox(height: 30),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text("${AppTranslations.translate(context, 'NEW ')} ${AppTranslations.translate(context, widget.role)}?"),
                TextButton(
                  onPressed: () {
                    // 📍 CONTINUITY: Opens registration with the same role
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => RegistrationScreen(role: widget.role),
                      ),
                    );
                  },
                  child: Text(
                    AppTranslations.translate(context, 'create account'),
                    style: TextStyle(color: themeColor, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}