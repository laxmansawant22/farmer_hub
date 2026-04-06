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

  // 📍 Range Logic: Default 5km, Min 0.5km (500m), Max 50km
  double _selectedKmRange = 5.0;

  // 📍 Comparison State
  List<Map<String, dynamic>> _selectedForCompare = [];
  bool _isComparisonMode = false; // Toggle via Tools

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

  double _getRawDistance(dynamic fLat, dynamic fLon) {
    if (_currentPosition == null || fLat == null || fLon == null) return 999999;
    double lat = double.tryParse(fLat.toString()) ?? 0.0;
    double lon = double.tryParse(fLon.toString()) ?? 0.0;
    return Geolocator.distanceBetween(
        _currentPosition!.latitude, _currentPosition!.longitude, lat, lon) / 1000;
  }

  String _calculateDistance(dynamic fLat, dynamic fLon) {
    double dist = _getRawDistance(fLat, fLon);
    return dist > 10000 ? "-- Km" : "${dist.toStringAsFixed(1)} Km";
  }

  // 📍 Range Selector Dialog
  void _showRangePicker() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: const Text("Select Search Radius"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("Current: ${_selectedKmRange < 1 ? '${(_selectedKmRange * 1000).toInt()} Meters' : '${_selectedKmRange.toStringAsFixed(1)} KM'}"),
              const SizedBox(height: 10),
              Slider(
                value: _selectedKmRange,
                min: 0.5, // 500 Meters
                max: 50.0, // 50 KM
                divisions: 99,
                activeColor: const Color(0xFF4A6D41),
                inactiveColor: Colors.green.shade100,
                label: "${_selectedKmRange.toStringAsFixed(1)} KM",
                onChanged: (val) {
                  setDialogState(() => _selectedKmRange = val);
                  setState(() => _selectedKmRange = val);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () {
                  setState(() => _selectedKmRange = 5.0); // Reset to default
                  Navigator.pop(context);
                },
                child: const Text("Reset to 5KM", style: TextStyle(color: Colors.red))
            ),
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Apply", style: TextStyle(color: Color(0xFF4A6D41), fontWeight: FontWeight.bold))),
          ],
        ),
      ),
    );
  }

  // 📍 Tools Menu
  void _showToolsMenu() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
          const Padding(
            padding: EdgeInsets.all(15.0),
            child: Text("Market Tools", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          ListTile(
            leading: Icon(_isComparisonMode ? Icons.close : Icons.compare_arrows, color: Colors.orange),
            title: Text(_isComparisonMode ? "Stop Comparison Mode" : "Start Comparison Mode"),
            onTap: () {
              setState(() {
                _isComparisonMode = !_isComparisonMode;
                if (!_isComparisonMode) _selectedForCompare.clear();
              });
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.location_searching, color: Color(0xFF4A6D41)),
            title: const Text("Reset Location Range (5KM)"),
            onTap: () {
              setState(() => _selectedKmRange = 5.0);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Range reset to 5KM")));
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  void _showLogoutPopup() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Text("Logout"),
        content: const Text("Are you sure you want to exit AgriMarket?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (mounted) {
                Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (c) => const LoginSelectionScreen()), (r) => false);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            child: const Text("Logout", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
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
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Max 3 items allowed")));
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
      bottomNavigationBar: _selectedForCompare.isNotEmpty ? _buildCompareBar() : _buildMarketBottomBar(),
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

                List<QueryDocumentSnapshot> allDocs = snapshot.data!.docs;
                DateTime twelveHoursAgo = DateTime.now().subtract(const Duration(hours: 12));

                var filteredDocs = allDocs.where((doc) {
                  var data = doc.data() as Map<String, dynamic>;

                  // 📍 FIX: Robust parsing for large quantities (4000kg etc)
                  int stock = (double.tryParse(data['quantity']?.toString() ?? '0') ?? 0).toInt();

                  Timestamp? ts = data['timestamp'] as Timestamp?;

                  if (stock <= 0 && ts != null) {
                    if (ts.toDate().isBefore(twelveHoursAgo)) return false;
                  }

                  double distance = _getRawDistance(data['lat'], data['lng']);
                  if (distance > _selectedKmRange) return false;

                  bool matchesCategory = _selectedCategory == 'All' || data['type'] == _selectedCategory;
                  bool matchesSearch = data['name'].toString().toLowerCase().contains(_searchQuery.toLowerCase());
                  return matchesCategory && matchesSearch;
                }).toList();

                filteredDocs.sort((a, b) {
                  int stockA = (double.tryParse((a.data() as Map<String, dynamic>)['quantity']?.toString() ?? '0') ?? 0).toInt();
                  int stockB = (double.tryParse((b.data() as Map<String, dynamic>)['quantity']?.toString() ?? '0') ?? 0).toInt();
                  if (stockA > 0 && stockB <= 0) return -1;
                  if (stockA <= 0 && stockB > 0) return 1;
                  return 0;
                });

                if (filteredDocs.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 50),
                    child: Center(child: Text("No crops found within range.")),
                  );
                }

                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(12),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.62,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: filteredDocs.length,
                  itemBuilder: (context, index) {
                    var data = filteredDocs[index].data() as Map<String, dynamic>;
                    data['id'] = filteredDocs[index].id;
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

  Widget _buildMarketBottomBar() {
    return BottomAppBar(
      height: 70,
      padding: EdgeInsets.zero,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _bottomActionButton(Icons.history, "My Orders", () => Navigator.push(context, MaterialPageRoute(builder: (c) => const MyOrdersScreen()))),
          _bottomActionButton(Icons.build_circle, "Tools", _showToolsMenu, isCenter: true),
          _bottomActionButton(Icons.shopping_cart, "Cart", () => Navigator.push(context, MaterialPageRoute(builder: (c) => const CartScreen()))),
        ],
      ),
    );
  }

  Widget _bottomActionButton(IconData icon, String label, VoidCallback onTap, {bool isCenter = false}) {
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: isCenter ? Colors.orange : const Color(0xFF4A6D41), size: isCenter ? 30 : 24),
          Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey[700])),
        ],
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
                      ..._selectedForCompare.map((p) => DataColumn(label: Text(p['name']?.toString() ?? 'Item', style: const TextStyle(fontWeight: FontWeight.bold)))),
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
                        ..._selectedForCompare.map((p) => DataCell(Text(p['method']?.toString() ?? "Organic"))),
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
          Expanded(child: Text("Best option: ${best['name']} based on price & location.", style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }

  Widget _buildProductCard(Map<String, dynamic> data) {
    String base64Image = (data['images'] as List?)?.isNotEmpty == true ? data['images'][0] : "";
    String dist = _calculateDistance(data['lat'], data['lng']);
    bool isSelected = _selectedForCompare.any((item) => item['id'] == data['id']);

    // 📍 FIX: Ensure large quantities (4000) are parsed as INT
    int stock = (double.tryParse(data['quantity']?.toString() ?? '0') ?? 0).toInt();

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
                  child: Opacity(
                    opacity: stock <= 0 ? 0.5 : 1.0,
                    child: base64Image.isNotEmpty
                        ? Image.memory(base64Decode(base64Image), width: double.infinity, height: double.infinity, fit: BoxFit.cover)
                        : Container(color: Colors.grey[200], child: const Center(child: Icon(Icons.image_not_supported))),
                  ),
                ),
                if (stock <= 0)
                  Center(child: Container(padding: const EdgeInsets.all(6), color: Colors.red.withOpacity(0.8), child: const Text("OUT OF STOCK", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10)))),

                // 📍 Comparison Icon: Only show if comparison mode is ON
                if (_isComparisonMode)
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
                Text(data['name']?.toString() ?? "", style: const TextStyle(fontWeight: FontWeight.bold), maxLines: 1),
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
                        onPressed: stock <= 0 ? null : () => Navigator.push(context, MaterialPageRoute(builder: (c) => ProductDetailsScreen(productData: data))),
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4A6D41), minimumSize: const Size(0, 30)),
                        child: Text(stock <= 0 ? "Unavailable" : "View", style: const TextStyle(color: Colors.white, fontSize: 11)),
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

  Widget _buildLocationBanner() {
    return InkWell(
      onTap: _showRangePicker,
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            gradient: LinearGradient(colors: [Colors.green.shade50, Colors.green.shade100]),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.green.shade200)
        ),
        child: Row(
          children: [
            const Icon(Icons.people_alt, color: Color(0xFF4A6D41), size: 30),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text("Nearby Farmers", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF4A6D41))),
              Text("Search radius: ${_selectedKmRange.toStringAsFixed(1)} KM", style: const TextStyle(color: Colors.blueGrey, fontSize: 11)),
            ])),
            const Icon(Icons.tune, color: Color(0xFF4A6D41))
          ],
        ),
      ),
    );
  }

  Widget _buildTopFarmersBanner() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFFFDECEC), borderRadius: BorderRadius.circular(20)),
      child: Row(
        children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text("Verified Top Farmers", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Text("Premium local harvest.", style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 10),
            ElevatedButton(onPressed: () {}, style: ElevatedButton.styleFrom(backgroundColor: Colors.black), child: const Text("View All", style: TextStyle(color: Colors.white))),
          ])),
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
          fillColor: Colors.white, filled: true,
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
                accountName: Text(userData?['name']?.toString() ?? "User"),
                accountEmail: Text(user?.email ?? ""),
                currentAccountPicture: CircleAvatar(
                  backgroundColor: Colors.white,
                  backgroundImage: (userData?['imageUrl'] != null && userData!['imageUrl'].toString().isNotEmpty)
                      ? MemoryImage(base64Decode(userData['imageUrl'].toString()))
                      : null,
                  child: (userData?['imageUrl'] == null || userData!['imageUrl'].toString().isEmpty)
                      ? const Icon(Icons.person, size: 40, color: Color(0xFF4A6D41))
                      : null,
                ),
              ),
              ListTile(leading: const Icon(Icons.person), title: const Text("Profile"), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => ProfileScreen(role: userData?['role']?.toString() ?? 'customer')))),
              ListTile(leading: const Icon(Icons.edit), title: const Text("Edit Profile"), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => EditProfileScreen(role: userData?['role']?.toString() ?? 'customer')))),
              ListTile(leading: const Icon(Icons.history), title: const Text("My Orders"), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const MyOrdersScreen()))),
              if (userData?['role'] == 'farmer')
                ListTile(leading: const Icon(Icons.dashboard, color: Colors.orange), title: const Text("Farmer Dashboard"), onTap: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (c) => const HomeScreen()))),
              const Spacer(),
              ListTile(leading: const Icon(Icons.logout, color: Colors.red), title: const Text("Logout"), onTap: _showLogoutPopup),
              const SizedBox(height: 20),
            ],
          );
        },
      ),
    );
  }
}