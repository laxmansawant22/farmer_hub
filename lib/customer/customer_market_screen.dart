import 'dart:convert' show base64Decode;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart'; 

// 📍 Standardized Imports
import '../translations.dart';
import '../screens/login_selection_screen.dart';
import '../screens/home_screen.dart';
import 'product_detail_screen.dart';
import 'my_orders_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/edit_profile_screen.dart';
import 'cart_screen.dart';

class CustomerMarketScreen extends StatefulWidget {
  const CustomerMarketScreen({super.key});

  @override
  State<CustomerMarketScreen> createState() => _CustomerMarketScreenState();
}

class _CustomerMarketScreenState extends State<CustomerMarketScreen> {
  String _selectedCategory = 'All';
  String _searchQuery = "";
  final TextEditingController _searchController = TextEditingController();

  Position? _currentPosition;
  String _currentAddress = "Locating...";

  // 📍 Comparison State
  List<Map<String, dynamic>> _selectedForCompare = [];

  @override
  void initState() {
    super.initState();
    _determinePosition();
  }

  Future<void> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    Position position = await Geolocator.getCurrentPosition();
    setState(() {
      _currentPosition = position;
      _currentAddress = "Current Location Detected";
    });
  }

  double _getRawDistance(double? fLat, double? fLon) {
    if (_currentPosition == null || fLat == null || fLon == null) return 999999;
    return Geolocator.distanceBetween(
        _currentPosition!.latitude, _currentPosition!.longitude, fLat, fLon) / 1000;
  }

  String _calculateDistance(double? fLat, double? fLon) {
    double dist = _getRawDistance(fLat, fLon);
    return dist > 10000 ? "-- Km" : "${dist.toStringAsFixed(1)} Km";
  }

  void _toggleCompare(Map<String, dynamic> product) {
    setState(() {
      bool isSelected = _selectedForCompare.any((item) => item['id'] == product['id']);
      if (isSelected) {
        _selectedForCompare.removeWhere((item) => item['id'] == product['id']);
      } else {
        if (_selectedForCompare.length < 3) {
          _selectedForCompare.add(product);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("You can compare up to 3 products")),
          );
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppTranslations.translate(context, 'market')),
        backgroundColor: const Color(0xFF4A6D41),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      drawer: _buildCustomerDrawer(),
      floatingActionButton: _buildCartFAB(),
      bottomNavigationBar: _selectedForCompare.isNotEmpty ? _buildCompareBar() : null,
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildSearchBar(),
            _buildLocationBanner(),
            _buildTopFarmersBanner(),
            _buildCategoryFilter(),

            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('products').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}"));
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Color(0xFF4A6D41)));
                }

                var docs = snapshot.data!.docs.where((doc) {
                  var data = doc.data() as Map<String, dynamic>;
                  bool matchesCategory = _selectedCategory == 'All' || data['type'] == _selectedCategory;
                  bool matchesSearch = data['name'].toString().toLowerCase().contains(_searchQuery.toLowerCase());
                  return matchesCategory && matchesSearch;
                }).toList();

                if (docs.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 50),
                    child: Center(child: Text("No crops found in this category.")),
                  );
                }

                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(12),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.62, // Adjusted for extra button
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    var data = docs[index].data() as Map<String, dynamic>;
                    data['id'] = docs[index].id;
                    return _buildProductCard(data);
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompareBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      height: 70,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text("${_selectedForCompare.length} items selected", style: const TextStyle(fontWeight: FontWeight.bold)),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: _showComparisonSheet,
            child: const Text("Compare Now", style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }

  void _showComparisonSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        builder: (_, controller) => Container(
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Container(width: 50, height: 5, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
              const SizedBox(height: 15),
              const Text("Comparison Analysis", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const Divider(),
              Expanded(
                child: SingleChildScrollView(
                  controller: controller,
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: [
                      const DataColumn(label: Text('Feature')),
                      ..._selectedForCompare.map((p) => DataColumn(label: Text(p['name'], style: const TextStyle(fontWeight: FontWeight.bold)))),
                    ],
                    rows: [
                      DataRow(cells: [
                        const DataCell(Text("Price")),
                        ..._selectedForCompare.map((p) => DataCell(Text("₹${p['price']}"))),
                      ]),
                      DataRow(cells: [
                        const DataCell(Text("Distance")),
                        ..._selectedForCompare.map((p) => DataCell(Text(_calculateDistance(p['lat'], p['lng'])))),
                      ]),
                      DataRow(cells: [
                        const DataCell(Text("Method")),
                        ..._selectedForCompare.map((p) => DataCell(Text(p['method'] ?? "Organic"))),
                      ]),
                      DataRow(cells: [
                        const DataCell(Text("Rating")),
                        ..._selectedForCompare.map((p) => const DataCell(Icon(Icons.star, color: Colors.orange, size: 16))),
                      ]),
                    ],
                  ),
                ),
              ),
              _buildWinnerCard(),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWinnerCard() {
    if (_selectedForCompare.length < 2) return const SizedBox();
    
    // Simple logic: Best = Lowest Price & Closest
    var best = _selectedForCompare.reduce((a, b) {
      double scoreA = (double.tryParse(a['price'].toString()) ?? 0) + (_getRawDistance(a['lat'], a['lng']));
      double scoreB = (double.tryParse(b['price'].toString()) ?? 0) + (_getRawDistance(b['lat'], b['lng']));
      return scoreA < scoreB ? a : b;
    });

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: Colors.green[50], borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.green)),
      child: Row(
        children: [
          const Icon(Icons.auto_awesome, color: Colors.green),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              "Recommendation: ${best['name']} is the best option because of its competitive price and proximity.",
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildProductCard(Map<String, dynamic> data) {
    String base64Image = (data['images'] as List).isNotEmpty ? data['images'][0] : "";
    String dist = _calculateDistance(data['lat'], data['lng']);
    bool isSelected = _selectedForCompare.any((item) => item['id'] == data['id']);

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isSelected ? const BorderSide(color: Colors.orange, width: 2) : BorderSide.none,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  child: base64Image.isNotEmpty
                      ? Image.memory(base64Decode(base64Image), width: double.infinity, height: double.infinity, fit: BoxFit.cover)
                      : Container(color: Colors.grey[200]),
                ),
                Positioned(
                  top: 5, right: 5,
                  child: IconButton(
                    onPressed: () => _toggleCompare(data),
                    icon: Icon(isSelected ? Icons.check_circle : Icons.add_circle_outline, color: isSelected ? Colors.orange : Colors.white),
                    style: IconButton.styleFrom(backgroundColor: Colors.black26),
                  ),
                )
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(data['name'] ?? "", style: const TextStyle(fontWeight: FontWeight.bold), maxLines: 1),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("₹${data['price']}", style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                    Text(dist, style: const TextStyle(fontSize: 10, color: Colors.blueGrey)),
                  ],
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => ProductDetailsScreen(productData: data))),
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4A6D41), minimumSize: const Size(0, 30)),
                        child: const Text("View", style: TextStyle(color: Colors.white, fontSize: 11)),
                      ),
                    ),
                  ],
                )
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ... (Rest of your UI builders like _buildSearchBar, _buildLocationBanner, etc. remain the same)
  Widget _buildLocationBanner() {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [Colors.blue.shade50, Colors.blue.shade100]),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          const Icon(Icons.my_location, color: Colors.blue, size: 30),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Farmers Near Me", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue)),
                Text(_currentAddress, style: const TextStyle(color: Colors.blueGrey, fontSize: 11)),
              ],
            ),
          ),
          TextButton(
            onPressed: _determinePosition,
            child: const Text("Refresh", style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  Widget _buildTopFarmersBanner() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFDECEC),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Verified Top Farmers", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const Text("Get the best quality harvest.", style: TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.black),
                  child: const Text("View All", style: TextStyle(color: Colors.white)),
                )
              ],
            ),
          ),
          const Icon(Icons.verified_user, size: 60, color: Colors.redAccent),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(12),
      color: const Color(0xFF4A6D41),
      child: TextField(
        controller: _searchController,
        onChanged: (val) => setState(() => _searchQuery = val),
        decoration: InputDecoration(
          hintText: "Search for crops...",
          prefixIcon: const Icon(Icons.search),
          fillColor: Colors.white,
          filled: true,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
          contentPadding: EdgeInsets.zero,
        ),
      ),
    );
  }

  Widget _buildCategoryFilter() {
    List<String> categories = ['All', 'Vegetables', 'Fruits', 'Seeds', 'Other'];
    return SizedBox(
      height: 55,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        itemBuilder: (context, index) {
          bool isSelected = _selectedCategory == categories[index];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5),
            child: ChoiceChip(
              label: Text(categories[index]),
              selected: isSelected,
              onSelected: (val) => setState(() => _selectedCategory = categories[index]),
              selectedColor: const Color(0xFF4A6D41),
              labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCustomerDrawer() {
    final user = FirebaseAuth.instance.currentUser;
    return Drawer(
      child: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(user?.email).snapshots(),
        builder: (context, snapshot) {
          var userData = snapshot.data?.data() as Map<String, dynamic>?;
          return Column(
            children: [
              UserAccountsDrawerHeader(
                decoration: const BoxDecoration(color: Color(0xFF4A6D41)),
                accountName: Text(userData?['name'] ?? "User"),
                accountEmail: Text(user?.email ?? ""),
                currentAccountPicture: CircleAvatar(
                  backgroundImage: userData?['imageUrl'] != null ? MemoryImage(base64Decode(userData!['imageUrl'])) : null,
                  child: userData?['imageUrl'] == null ? const Icon(Icons.person) : null,
                ),
              ),
              ListTile(leading: const Icon(Icons.person), title: const Text("Profile"), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => ProfileScreen(role: userData?['role'] ?? 'customer')))),
              ListTile(leading: const Icon(Icons.edit), title: const Text("Edit Profile"), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => EditProfileScreen(role: userData?['role'] ?? 'customer')))),
              ListTile(leading: const Icon(Icons.history), title: const Text("My Orders"), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const MyOrdersScreen()))),
              if (userData?['role'] == 'farmer')
                ListTile(leading: const Icon(Icons.dashboard, color: Colors.orange), title: const Text("Farmer Dashboard"), onTap: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (c) => const HomeScreen()))),
              const Spacer(),
              ListTile(leading: const Icon(Icons.logout, color: Colors.red), title: const Text("Logout"), onTap: () => FirebaseAuth.instance.signOut().then((_) => Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (c) => const LoginSelectionScreen()), (r) => false))),
              const SizedBox(height: 20),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCartFAB() {
    return FloatingActionButton(
      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const CartScreen())).then((_) => setState(() {})),
      backgroundColor: const Color(0xFF4A6D41),
      child: const Icon(Icons.shopping_cart, color: Colors.white),
    );
  }
}