import 'package:flutter/material.dart';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';

// Ensure these imports match your actual file names
import '../main.dart';
import 'add_product_screen.dart';
import 'chat_detail_screen.dart';
import 'inventory_screen.dart';
import 'market_prices_screen.dart';
import 'profile_screen.dart';
import 'edit_profile_screen.dart'; // 📍 Added for the Edit Profile option
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
  String farmerName = "Loading...";
  String farmType = "Farmer";
  String? profileImagePath;
  List<Product> myProducts = [];
  bool isDarkMode = false; // 📍 Track local switch state

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      farmerName = prefs.getString('name_admin') ?? "Farmer Name";
      profileImagePath = prefs.getString('selfie_admin');
      bool isFarmer = prefs.getBool('isFarmer_admin') ?? true;
      farmType = isFarmer ? "Pure Organic Farm" : "Customer Account";
      // 📍 Sync local switch with the global theme on load
      isDarkMode = prefs.getBool('isDarkMode') ?? false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF4A6D41),
        title: const Text("Farmer Dashboard", style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      drawer: _buildDrawer(),

      // 📍 New Body Structure
      body: Column(
        children: [
          // 1. Scrollable Area (Dashboard Content)
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildProfileHeader(),
                  _buildLiveCropsSection(),
                  const SizedBox(height: 25),
                  _buildActionButtons(),
                  _buildImportantFeatures(), // Your new Grid is here
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),

          // 2. Fixed Bottom Area (Switch Button)
          const Divider(height: 1), // Adds a subtle line above the button
          _buildSwitchButton(),
        ],
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            decoration: const BoxDecoration(color: Color(0xFF4A6D41)),
            accountName: Text(farmerName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            accountEmail: Text(farmType),
            currentAccountPicture: CircleAvatar(
              backgroundColor: Colors.white,
              backgroundImage: profileImagePath != null ? FileImage(File(profileImagePath!)) : null,
              child: profileImagePath == null ? const Icon(Icons.person, size: 40, color: Color(0xFF4A6D41)) : null,
            ),
          ),
          ListTile(
            leading: const Icon(Icons.person_outline, color: Colors.green),
            title: const Text("My Profile"),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (c) => const ProfileScreen()));
            },
          ),
          // 📍 Edit Profile Option
          ListTile(
            leading: const Icon(Icons.edit_note, color: Colors.orange),
            title: const Text("Edit Profile"),
            onTap: () async {
              Navigator.pop(context);
              final result = await Navigator.push(context, MaterialPageRoute(builder: (c) => const EditProfileScreen()));
              if (result == true) _loadUserData();
            },
          ),
          // 📍 Dark Mode Toggle
          SwitchListTile(
            secondary: Icon(
                isDarkMode ? Icons.dark_mode : Icons.light_mode,
                color: isDarkMode ? Colors.amber : Colors.grey
            ),
            title: const Text("Dark Mode"),
            value: isDarkMode,
            activeColor: const Color(0xFF4A6D41),
            onChanged: (bool value) async {
              final prefs = await SharedPreferences.getInstance();
              setState(() {
                isDarkMode = value;
              });
              // 📍 Update global theme and save preference
              themeNotifier.value = value ? ThemeMode.dark : ThemeMode.light;
              await prefs.setBool('isDarkMode', value);
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.headset_mic_outlined, color: Colors.blue),
            title: const Text("Help & Support"),
            onTap: () => Navigator.pop(context),
          ),
          const Spacer(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text("Logout"),
            onTap: () {
              Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (c) => const LoginSelectionScreen()),
                      (route) => false
              );
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // Rest of your layout functions remain exactly the same as requested
  Widget _buildProfileHeader() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const ProfileScreen())),
            child: CircleAvatar(
              radius: 35,
              backgroundColor: const Color(0xFFF1F5F0),
              backgroundImage: profileImagePath != null ? FileImage(File(profileImagePath!)) : null,
              child: profileImagePath == null ? const Icon(Icons.person, size: 40, color: Color(0xFF4A6D41)) : null,
            ),
          ),
          const SizedBox(width: 15),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(farmerName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              Text(farmType, style: const TextStyle(color: Colors.grey, fontSize: 14)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLiveCropsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Text("My Live Crops", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 130,
          child: myProducts.isEmpty
              ? const Center(child: Text("No crops listed yet", style: TextStyle(color: Colors.grey)))
              : ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(left: 20),
            itemCount: myProducts.length,
            itemBuilder: (context, index) => _cropCard(myProducts[index], index),
          ),
        ),
      ],
    );
  }

  Widget _cropCard(Product product, int index) {
    return Container(
      width: 110,
      margin: const EdgeInsets.only(right: 15),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor, // Adapts to theme
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              child: Image.file(product.images[0], fit: BoxFit.cover, width: double.infinity),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(6.0),
            child: Text(product.name, style: const TextStyle(fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const SalesScreen())),
              icon: const Icon(Icons.bar_chart),
              label: const Text("Sales"),
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4A6D41),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12)
              ),
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () async {
                final result = await Navigator.push(context, MaterialPageRoute(builder: (c) => const AddProductScreen()));
                if (result != null) {
                  setState(() {
                    myProducts.add(Product(
                      name: result['name'], qty: result['qty'], price: result['price'],
                      unit: result['unit'], type: result['type'], images: result['images'],
                    ));
                  });
                }
              },
              icon: const Icon(Icons.add),
              label: const Text("Add Crop"),
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6B8E61),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12)
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImportantFeatures() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 25),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
              "Quick Tools",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)
          ),
          const SizedBox(height: 15),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 4,
            mainAxisSpacing: 10,
            crossAxisSpacing: 5,
            children: [
              _featureIcon(Icons.shopping_bag_outlined, "Orders", const OrdersScreen()),
              _featureIcon(Icons.inventory_2_outlined, "Inventory", InventoryScreen(products: myProducts)),
              _featureIcon(Icons.currency_rupee, "Market", const MarketPricesScreen()),
              _featureIcon(Icons.account_balance_wallet_outlined, "Expenses", const ExpenseTrackerScreen()),
              _featureIcon(Icons.chat_bubble_outline, "Messages", const ChatDetailScreen(userName: "Recent Buyer")),// 📍 Added Messages icon here

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
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => targetScreen),
          );
        }
      },
      child: Column(
        children: [
          CircleAvatar(
            backgroundColor: const Color(0xFF4A6D41).withValues(alpha: 0.1),
            child: Icon(icon, color: const Color(0xFF4A6D41)),
          ),
          const SizedBox(height: 5),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildSwitchButton() {
    return Container(
      padding: const EdgeInsets.all(20),
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (c) => const CustomerMarketScreen())
        ),
        icon: const Icon(Icons.swap_horiz, color: Color(0xFF4A6D41)),
        label: const Text("Switch to Customer Mode", style: TextStyle(color: Color(0xFF4A6D41))),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 15),
          side: const BorderSide(color: Color(0xFF4A6D41)),
        ),
      ),
    );
  } // <--- Closes the function
} // <--- Closes the _HomeScreenState class