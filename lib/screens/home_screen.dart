import 'dart:convert' show base64Decode;
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// 📍 FIXED IMPORTS: Removed '../' or 'screens/' because files are in the same folder
import '../main.dart';
import '../translations.dart';
import 'main.dart'; // Required for themeNotifier and languageNotifier
import 'translations.dart'; // Required for AppTranslations
import 'add_product_screen.dart';
import 'inventory_screen.dart';
import 'market_prices_screen.dart';
import 'profile_screen.dart';
import 'edit_profile_screen.dart';
import 'login_selection_screen.dart';
import 'sales_screen.dart';
import 'orders_screen.dart';
import 'customer_market_screen.dart';
import 'expense_tracker_screen.dart';


class Product {
  String name;
  String qty;
  String price;
  String unit;
  String type;
  List<File> images;

  Product({
    required this.name,
    required this.qty,
    required this.price,
    required this.unit,
    required this.type,
    required this.images,
  });
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Product> myProducts = [];
  bool isDarkMode = false;

  @override
  void initState() {
    super.initState();
    _loadThemeSettings();
  }

  Future<void> _loadThemeSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      isDarkMode = prefs.getBool('isDarkMode') ?? false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF4A6D41),
        title: Text(
            AppTranslations.translate(context, 'farmer_dashboard'),
            style: const TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      drawer: _buildDrawer(),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildWelcomeHeader(),
                  _buildLiveCropsSection(),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          _buildBottomActionSection(),
        ],
      ),
    );
  }

  Widget _buildWelcomeHeader() {
    final user = FirebaseAuth.instance.currentUser;
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user?.email)
          .snapshots(),
      builder: (context, snapshot) {
        String displayName = "Farmer";
        if (snapshot.hasData && snapshot.data!.exists) {
          var data = snapshot.data!.data() as Map<String, dynamic>;
          displayName = data['name'] ?? "Farmer";
        }
        return Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                  AppTranslations.translate(context, 'welcome'),
                  style: TextStyle(fontSize: 16, color: Colors.grey[600])
              ),
              Text(displayName, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF4A6D41))),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDrawer() {
    final user = FirebaseAuth.instance.currentUser;
    return Drawer(
      child: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(user?.email).snapshots(),
        builder: (context, snapshot) {
          String name = "Farmer";
          String imageUrlBase64 = "";

          if (snapshot.hasData && snapshot.data!.exists) {
            var data = snapshot.data!.data() as Map<String, dynamic>;
            name = data['name'] ?? "Farmer Name";
            imageUrlBase64 = data['imageUrl'] ?? "";
          }

          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    UserAccountsDrawerHeader(
                      decoration: const BoxDecoration(color: Color(0xFF4A6D41)),
                      accountName: Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      accountEmail: Text(user?.email ?? "No Email"),
                      currentAccountPicture: GestureDetector(
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(context, MaterialPageRoute(builder: (c) => const ProfileScreen(role: 'farmer')));
                        },
                        child: CircleAvatar(
                          backgroundColor: Colors.white,
                          child: imageUrlBase64.isNotEmpty
                              ? ClipOval(child: Image.memory(base64Decode(imageUrlBase64), width: 90, height: 90, fit: BoxFit.cover))
                              : const Icon(Icons.person, size: 40, color: Color(0xFF4A6D41)),
                        ),
                      ),
                    ),

                    // 📍 LANGUAGE SELECTION DROPDOWN
                    ListTile(
                      leading: const Icon(Icons.language, color: Colors.blue),
                      title: Text(AppTranslations.translate(context, 'language')),
                      trailing: ValueListenableBuilder<Locale>(
                          valueListenable: languageNotifier,
                          builder: (context, currentLocale, _) {
                            return DropdownButton<String>(
                              value: currentLocale.languageCode,
                              underline: const SizedBox(),
                              items: const [
                                DropdownMenuItem(value: 'en', child: Text("English")),
                                DropdownMenuItem(value: 'mr', child: Text("मराठी")),
                                DropdownMenuItem(value: 'hi', child: Text("हिन्दी")),
                              ],
                              onChanged: (val) async {
                                if (val != null) {
                                  languageNotifier.value = Locale(val);
                                  final prefs = await SharedPreferences.getInstance();
                                  await prefs.setString('language_code', val);
                                }
                              },
                            );
                          }
                      ),
                    ),

                    SwitchListTile(
                      secondary: Icon(isDarkMode ? Icons.dark_mode : Icons.light_mode, color: isDarkMode ? Colors.amber : Colors.grey),
                      title: Text(AppTranslations.translate(context, 'dark_mode')),
                      value: isDarkMode,
                      onChanged: (bool value) async {
                        final prefs = await SharedPreferences.getInstance();
                        setState(() => isDarkMode = value);
                        themeNotifier.value = value ? ThemeMode.dark : ThemeMode.light;
                        await prefs.setBool('isDarkMode', value);
                      },
                    ),
                    const Divider(),
                    ListTile(
                      leading: const Icon(Icons.swap_horiz, color: Color(0xFF4A6D41)),
                      title: Text(AppTranslations.translate(context, 'switch_mode')),
                      subtitle: Text(AppTranslations.translate(context, 'switch_to_customer')),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.pushReplacement(context, MaterialPageRoute(builder: (c) => const CustomerMarketScreen()));
                      },
                    ),
                    const Divider(),
                    ListTile(
                      leading: const Icon(Icons.edit_note, color: Colors.orange),
                      title: Text(AppTranslations.translate(context, 'edit_profile')),
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const EditProfileScreen(role: 'farmer'))),
                    ),
                  ],
                ),
              ),
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
                title: Text(AppTranslations.translate(context, 'logout')),
                onTap: () async {
                  await FirebaseAuth.instance.signOut();
                  Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (c) => const LoginSelectionScreen()), (route) => false);
                },
              ),
              const SizedBox(height: 10),
            ],
          );
        },
      ),
    );
  }

  Widget _buildLiveCropsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(AppTranslations.translate(context, 'my_live_crops'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 130,
          child: myProducts.isEmpty
              ? Center(child: Text(AppTranslations.translate(context, 'no_crops_listed')))
              : ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(left: 20),
            itemCount: myProducts.length,
            itemBuilder: (context, index) => _cropCard(myProducts[index]),
          ),
        ),
      ],
    );
  }

  Widget _cropCard(Product product) {
    return Container(
      width: 110,
      margin: const EdgeInsets.only(right: 15),
      decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
      child: Column(
        children: [
          Expanded(child: ClipRRect(borderRadius: const BorderRadius.vertical(top: Radius.circular(12)), child: Image.file(product.images[0], fit: BoxFit.cover, width: double.infinity))),
          Padding(padding: const EdgeInsets.all(6.0), child: Text(product.name, style: const TextStyle(fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }

  Widget _buildBottomActionSection() {
    return Container(
      padding: const EdgeInsets.only(top: 15, bottom: 30, left: 20, right: 20),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: const Offset(0, -2))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 4,
            children: [
              _featureIcon(Icons.shopping_bag_outlined, AppTranslations.translate(context, 'orders'), const OrdersScreen()),
              _featureIcon(Icons.inventory_2_outlined, AppTranslations.translate(context, 'inventory'), InventoryScreen(products: myProducts)),
              _featureIcon(Icons.currency_rupee, AppTranslations.translate(context, 'market'), const MarketPricesScreen()),
              _featureIcon(Icons.account_balance_wallet_outlined, AppTranslations.translate(context, 'expenses'), const ExpenseTrackerScreen()),
            ],
          ),
          const SizedBox(height: 20),

          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const SalesScreen())),
                  icon: const Icon(Icons.bar_chart),
                  label: Text(AppTranslations.translate(context, 'sales')),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4A6D41), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 18), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final result = await Navigator.push(context, MaterialPageRoute(builder: (c) => const AddProductScreen()));
                    if (result != null) {
                      setState(() {
                        myProducts.add(Product(name: result['name'], qty: result['qty'], price: result['price'], unit: result['unit'], type: result['type'], images: result['images']));
                      });
                    }
                  },
                  icon: const Icon(Icons.add),
                  label: Text(AppTranslations.translate(context, 'add_crop')),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6B8E61), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 18), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _featureIcon(IconData icon, String label, Widget? targetScreen) {
    return InkWell(
      onTap: () {
        if (targetScreen != null) {
          Navigator.push(context, MaterialPageRoute(builder: (context) => targetScreen));
        }
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
              backgroundColor: const Color(0xFF4A6D41).withAlpha(25),
              child: Icon(icon, color: const Color(0xFF4A6D41))
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}