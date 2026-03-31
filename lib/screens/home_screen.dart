import 'dart:convert' show base64Decode;
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// 📍 Standard Project Imports
import '../main.dart';
import '../translations.dart';
import 'add_product_screen.dart';
import 'inventory_screen.dart';
import 'market_prices_screen.dart';
import 'profile_screen.dart';
import 'edit_profile_screen.dart';
import 'login_selection_screen.dart';
import 'sales_screen.dart';
import 'orders_screen.dart';
import 'expense_tracker_screen.dart';
import 'farmer_reviews_screen.dart';
import '../customer/customer_market_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool isDarkMode = false;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late ScrollController _marqueeController;
  Timer? _marqueeTimer;

  @override
  void initState() {
    super.initState();
    _loadThemeSettings();
    _marqueeController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startMarquee());
  }

  void _startMarquee() {
    _marqueeTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (_marqueeController.hasClients) {
        double maxExtent = _marqueeController.position.maxScrollExtent;
        double currentOffset = _marqueeController.offset;
        if (currentOffset >= maxExtent) {
          _marqueeController.jumpTo(0);
        } else {
          _marqueeController.animateTo(currentOffset + 2,
              duration: const Duration(milliseconds: 50), curve: Curves.linear);
        }
      }
    });
  }

  Future<void> _loadThemeSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      isDarkMode = prefs.getBool('isDarkMode') ?? false;
    });
  }

  @override
  void dispose() {
    _marqueeTimer?.cancel();
    _marqueeController.dispose();
    super.dispose();
  }

  // 📍 SMOOTH NAVIGATION HELPER
  void _smoothNavigate(Widget screen) {
    Navigator.push(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 400),
        pageBuilder: (context, animation, secondaryAnimation) => screen,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  Future<void> _showLogoutDialog() async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(AppTranslations.translate(context, 'logout')),
        content: Text(AppTranslations.translate(context, 'logout_confirm_msg') ?? "Are you sure you want to log out?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (c) => const LoginSelectionScreen()), (route) => false);
            },
            child: const Text("Logout"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        backgroundColor: const Color(0xFF4A6D41),
        title: Text(
            AppTranslations.translate(context, 'farmer_dashboard'),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      drawer: _buildDrawer(),
      body: Column(
        children: [
          _buildMarqueeHeader(),
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  _buildFertilizerStoreSection(),
                  const SizedBox(height: 30),
                  _buildLiveCropsSection(),
                  const SizedBox(height: 40),
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

  Widget _buildMarqueeHeader() {
    final user = FirebaseAuth.instance.currentUser;
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(user?.email).snapshots(),
      builder: (context, snapshot) {
        String displayName = "Farmer";
        if (snapshot.hasData && snapshot.data!.exists) {
          var data = snapshot.data!.data() as Map<String, dynamic>;
          displayName = data['name'] ?? "Farmer";
        }
        String welcomeMsg = "WELCOME TO AGRIMARKET, $displayName  •  ";

        return Container(
          height: 45, // Slightly larger for professional look
          color: const Color(0xFF4A6D41).withOpacity(0.08),
          child: ListView.builder(
            controller: _marqueeController,
            scrollDirection: Axis.horizontal,
            itemBuilder: (context, index) => Center(
              child: Text(
                welcomeMsg.toUpperCase(),
                style: const TextStyle(color: Color(0xFF2E4D26), fontWeight: FontWeight.w900, fontSize: 15, letterSpacing: 1.2),
              ),
            ),
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
          String role = "customer";

          if (snapshot.hasData && snapshot.data!.exists) {
            var data = snapshot.data!.data() as Map<String, dynamic>;
            name = data['name'] ?? "Farmer Name";
            imageUrlBase64 = data['imageUrl'] ?? "";
            role = data['role'] ?? "customer";
          }

          return Column(
            children: [
              // 📍 TAP ON HEADER TO VIEW FULL PROFILE
              GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                  _smoothNavigate(const ProfileScreen(role: 'farmer',));
                },
                child: UserAccountsDrawerHeader(
                  decoration: const BoxDecoration(color: Color(0xFF4A6D41)),
                  accountName: Text(name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  accountEmail: Text(user?.email ?? "No Email"),
                  currentAccountPicture: Hero(
                    tag: 'profile-pic',
                    child: CircleAvatar(
                      backgroundColor: Colors.white,
                      child: imageUrlBase64.isNotEmpty
                          ? ClipOval(child: Image.memory(base64Decode(imageUrlBase64), width: 90, height: 90, fit: BoxFit.cover))
                          : const Icon(Icons.person, size: 45, color: Color(0xFF4A6D41)),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    _buildSidebarRatingInfo(),
                    if (role == 'farmer')
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange[800],
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 4,
                          ),
                          onPressed: () {
                            Navigator.pop(context);
                            Navigator.pushReplacement(context, MaterialPageRoute(builder: (c) => const CustomerMarketScreen()));
                          },
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.storefront_rounded),
                              SizedBox(width: 10),
                              Text("ENTER MARKET", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            ],
                          ),
                        ),
                      ),
                    const Divider(),
                    _drawerTile(Icons.person_outline, 'view profile', () {
                      Navigator.pop(context);
                      _smoothNavigate(const ProfileScreen(role: 'farmer',));
                    }),
                    _drawerTile(Icons.language_rounded, 'language', _showLanguageSelector),
                    _drawerTile(Icons.edit_note_rounded, 'edit profile', () {
                      Navigator.pop(context);
                      _smoothNavigate(const EditProfileScreen(role: 'farmer'));
                    }),
                    SwitchListTile(
                      secondary: Icon(isDarkMode ? Icons.dark_mode : Icons.light_mode, color: const Color(0xFF4A6D41)),
                      title: Text(AppTranslations.translate(context, 'dark mode')),
                      value: isDarkMode,
                      onChanged: (bool value) async {
                        final prefs = await SharedPreferences.getInstance();
                        setState(() => isDarkMode = value);
                        themeNotifier.value = value ? ThemeMode.dark : ThemeMode.light;
                        await prefs.setBool('isDarkMode', value);
                      },
                    ),
                  ],
                ),
              ),
              const Divider(),
              _drawerTile(Icons.logout_rounded, 'logout', _showLogoutDialog, color: Colors.red),
              const SizedBox(height: 20),
            ],
          );
        },
      ),
    );
  }

  Widget _drawerTile(IconData icon, String translationKey, VoidCallback onTap, {Color? color}) {
    return ListTile(
      leading: Icon(icon, color: color ?? const Color(0xFF4A6D41)),
      title: Text(AppTranslations.translate(context, translationKey), style: TextStyle(color: color, fontWeight: FontWeight.w600)),
      onTap: onTap,
    );
  }

  Widget _buildSidebarRatingInfo() {
    final user = FirebaseAuth.instance.currentUser;
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('farmer_reviews').where('farmerEmail', isEqualTo: user?.email).snapshots(),
      builder: (context, snapshot) {
        double avgRating = 0.0;
        int reviewCount = 0;
        if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
          reviewCount = snapshot.data!.docs.length;
          double total = 0;
          for (var doc in snapshot.data!.docs) total += (doc['rating'] ?? 0).toDouble();
          avgRating = total / reviewCount;
        }
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.grey[200]!)),
          child: InkWell(
            onTap: () => _smoothNavigate(const FarmerReviewsScreen()),
            child: Row(children: [
              const Icon(Icons.stars_rounded, color: Colors.amber, size: 28),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text("Service Rating", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                Text(reviewCount == 0 ? "New Farmer" : "${avgRating.toStringAsFixed(1)} / 5.0 ($reviewCount Reviews)", style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ]),
            ]),
          ),
        );
      },
    );
  }

  Widget _buildFertilizerStoreSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Agriculture Store", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF2E4D26))),
          const SizedBox(height: 15),
          InkWell(
            onTap: () => _smoothNavigate(const FertilizerStoreScreen()),
            child: Container(
              width: double.infinity,
              height: 190,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(25),
                image: const DecorationImage(
                  image: NetworkImage("https://images.unsplash.com/photo-1628352081506-83c43123ed6d?q=80&w=1000&auto=format&fit=crop"),
                  fit: BoxFit.cover,
                  colorFilter: ColorFilter.mode(Colors.black45, BlendMode.darken),
                ),
                boxShadow: [BoxShadow(color: Colors.green.withOpacity(0.2), blurRadius: 15, offset: const Offset(0, 8))],
              ),
              child: Padding(
                padding: const EdgeInsets.all(25),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    const Text("Seeds & Fertilizers", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                    const Text("Find nearby stores and daily deals", style: TextStyle(color: Colors.white70, fontSize: 14)),
                    const SizedBox(height: 15),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(30)),
                      child: const Text("Visit Now", style: TextStyle(color: Color(0xFF4A6D41), fontWeight: FontWeight.bold)),
                    )
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveCropsSection() {
    final user = FirebaseAuth.instance.currentUser;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("My Live Crops", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF2E4D26))),
              IconButton(onPressed: () => _smoothNavigate(const InventoryScreen(products: [])), icon: const Icon(Icons.arrow_forward_ios, size: 18, color: Color(0xFF4A6D41))),
            ],
          ),
        ),
        SizedBox(
          height: 240,
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('products').where('farmerId', isEqualTo: user?.uid).snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Center(child: Text(AppTranslations.translate(context, 'no_crops_listed')));
              }
              return ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                physics: const BouncingScrollPhysics(),
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  var data = snapshot.data!.docs[index].data() as Map<String, dynamic>;
                  return _cropCard(data);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _cropCard(Map<String, dynamic> product) {
    String base64Image = (product['images'] as List).isNotEmpty ? product['images'][0] : "";
    num remaining = product['quantity'] ?? 0;
    num total = product['totalStock'] ?? remaining;
    double progress = total > 0 ? (remaining / total).clamp(0.0, 1.0) : 0.0;

    return Container(
      width: 180,
      margin: const EdgeInsets.only(right: 20, bottom: 15, top: 10),
      decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 6))]
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
              child: base64Image.isNotEmpty
                  ? Image.memory(base64Decode(base64Image), fit: BoxFit.cover, width: double.infinity)
                  : Container(color: Colors.grey[100], child: const Icon(Icons.eco, color: Colors.grey, size: 40)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(product['name'] ?? "", style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                const SizedBox(height: 4),
                Text("${remaining.toStringAsFixed(0)} ${product['unit'] ?? 'kg'} left",
                    style: TextStyle(fontSize: 12, color: remaining < (total * 0.2) ? Colors.red : Colors.grey[600], fontWeight: FontWeight.w600)),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                    backgroundColor: Colors.grey.shade100,
                    valueColor: AlwaysStoppedAnimation<Color>(remaining < (total * 0.2) ? Colors.red : const Color(0xFF4A6D41)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActionSection() {
    return Container(
      padding: const EdgeInsets.only(top: 15, bottom: 30, left: 20, right: 20),
      decoration: BoxDecoration(color: Theme.of(context).scaffoldBackgroundColor, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))]),
      child: Row(children: [
        Expanded(child: _actionBtn(Icons.analytics_outlined, 'sales', () => _smoothNavigate(const SalesScreen()), const Color(0xFF4A6D41))),
        const SizedBox(width: 15),
        _actionCircleBtn(),
        const SizedBox(width: 15),
        Expanded(child: _actionBtn(Icons.add_circle_outline, 'add_crop', () => _smoothNavigate(const AddProductScreen()), const Color(0xFF6B8E61))),
      ]),
    );
  }

  Widget _actionBtn(IconData icon, String label, VoidCallback onTap, Color color) {
    return ElevatedButton.icon(
      onPressed: onTap, icon: Icon(icon, size: 20),
      label: Text(AppTranslations.translate(context, label), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
      style: ElevatedButton.styleFrom(backgroundColor: color, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 18), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
    );
  }

  Widget _actionCircleBtn() {
    return InkWell(
      onTap: _showFeatureMenu,
      child: Container(padding: const EdgeInsets.all(14), decoration: const BoxDecoration(color: Color(0xFF4A6D41), shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 8)]), child: const Icon(Icons.grid_view_rounded, color: Colors.white, size: 30)),
    );
  }

  void _showFeatureMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(30),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 50, height: 5, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
          const SizedBox(height: 30),
          GridView.count(
            shrinkWrap: true, crossAxisCount: 4, mainAxisSpacing: 25,
            children: [
              _featureIcon(Icons.shopping_bag_outlined, 'orders', const FarmerOrdersScreen()),
              _featureIcon(Icons.inventory_2_outlined, 'inventory', const InventoryScreen(products: [])),
              _featureIcon(Icons.currency_rupee, 'market', const MarketPricesScreen()),
              _featureIcon(Icons.wallet_outlined, 'expenses', const ExpenseTrackerScreen()),
            ],
          ),
        ]),
      ),
    );
  }

  Widget _featureIcon(IconData icon, String label, Widget? target) {
    return InkWell(
      onTap: () { Navigator.pop(context); if (target != null) _smoothNavigate(target); },
      child: Column(children: [
        CircleAvatar(radius: 25, backgroundColor: const Color(0xFF4A6D41).withOpacity(0.1), child: Icon(icon, color: const Color(0xFF4A6D41))),
        const SizedBox(height: 8),
        Text(AppTranslations.translate(context, label), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
      ]),
    );
  }

  void _showLanguageSelector() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 25),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Select Language", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
            const SizedBox(height: 15),
            _langItem('en', 'English'),
            _langItem('mr', 'मराठी'),
            _langItem('hi', 'हिन्दी'),
          ],
        ),
      ),
    );
  }

  Widget _langItem(String code, String label) {
    return ListTile(
      title: Text(label, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w500)),
      onTap: () async {
        languageNotifier.value = Locale(code);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('language_code', code);
        Navigator.pop(context);
      },
    );
  }
}

// 📍 FERTILIZER STORE SCREEN (Matches Home Style)
class FertilizerStoreScreen extends StatelessWidget {
  const FertilizerStoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Agriculture Store", style: TextStyle(fontWeight: FontWeight.bold)), backgroundColor: const Color(0xFF4A6D41), foregroundColor: Colors.white, elevation: 0),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(25),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text("Certified Retailers", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF2E4D26))),
          const SizedBox(height: 20),
          _buildStoreCard("Green Valley Agro", "2.5 km away", "Open • Closes 8 PM"),
          _buildStoreCard("Maharashtra Fertilizer Hub", "4.1 km away", "Open • Closes 7 PM"),
          const SizedBox(height: 35),
          const Text("Browse Categories", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF2E4D26))),
          const SizedBox(height: 20),
          GridView.count(
            shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2, mainAxisSpacing: 20, crossAxisSpacing: 20, childAspectRatio: 1.3,
            children: [
              _catCard("Organic", Icons.eco, Colors.green),
              _catCard("Chemical", Icons.science, Colors.blue),
              _catCard("Seeds", Icons.grain, Colors.orange),
              _catCard("Tools", Icons.build, Colors.blueGrey),
            ],
          )
        ]),
      ),
    );
  }

  Widget _buildStoreCard(String name, String dist, String status) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: Colors.grey.shade200)),
      margin: const EdgeInsets.only(bottom: 15),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: const CircleAvatar(backgroundColor: Color(0xFF4A6D41), child: Icon(Icons.storefront_outlined, color: Colors.white)),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text("$dist • $status", style: const TextStyle(fontSize: 12, color: Colors.grey)),
        trailing: const Icon(Icons.directions_outlined, color: Colors.blue),
      ),
    );
  }

  Widget _catCard(String title, IconData icon, Color color) {
    return Container(
      decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(25), border: Border.all(color: color.withOpacity(0.15))),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, color: color, size: 36),
        const SizedBox(height: 10),
        Text(title, style: TextStyle(fontWeight: FontWeight.w900, color: color, fontSize: 16)),
      ]),
    );
  }
}