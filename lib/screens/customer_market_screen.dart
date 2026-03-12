import 'package:flutter/material.dart';
import 'home_screen.dart'; // Ensure this matches your farmer dashboard filename

class CustomerMarketScreen extends StatefulWidget {
  const CustomerMarketScreen({super.key});

  @override
  State<CustomerMarketScreen> createState() => _CustomerMarketScreenState();
}

class _CustomerMarketScreenState extends State<CustomerMarketScreen> {
  // Mock data for the market
  final List<Map<String, dynamic>> _products = [
    {'name': 'Organic Wheat', 'price': '₹40/kg', 'image': Icons.grass, 'farmer': 'Farmer John'},
    {'name': 'Fresh Rice', 'price': '₹65/kg', 'image': Icons.eco, 'farmer': 'Agri Farms'},
    {'name': 'Golden Corn', 'price': '35/kg', 'image': Icons.wb_sunny, 'farmer': 'Village Co.'},
    {'name': 'Brown Lentils', 'price': '₹90/kg', 'image': Icons.grain, 'farmer': 'Farmer John'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("Customer Market", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.orange.shade800,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: Column(
        children: [
          // 1. Scrollable Market Content
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSearchHeader(),
                  const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text("Available Crops", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                  _buildProductGrid(),
                ],
              ),
            ),
          ),

          // 2. Fixed Switch Button at Bottom
          const Divider(height: 1),
          _buildSwitchToFarmerButton(),
        ],
      ),
    );
  }

  Widget _buildSearchHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.orange.shade800,
      child: TextField(
        decoration: InputDecoration(
          hintText: "Search for fresh produce...",
          prefixIcon: const Icon(Icons.search),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(vertical: 0),
        ),
      ),
    );
  }

  Widget _buildProductGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 15,
        mainAxisSpacing: 15,
        childAspectRatio: 0.8,
      ),
      itemCount: _products.length,
      itemBuilder: (context, index) {
        final product = _products[index];
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5)],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(product['image'], size: 50, color: Colors.orange.shade800),
              const SizedBox(height: 10),
              Text(product['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(product['price'], style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
              Text("By ${product['farmer']}", style: const TextStyle(fontSize: 11, color: Colors.grey)),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange.shade800,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(80, 30),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                child: const Text("View", style: TextStyle(fontSize: 12)),
              )
            ],
          ),
        );
      },
    );
  }

  Widget _buildSwitchToFarmerButton() {
    return Container(
      padding: const EdgeInsets.all(20),
      width: double.infinity,
      color: Colors.white,
      child: OutlinedButton.icon(
        onPressed: () {
          // 📍 This brings the user back to the Farmer Dashboard
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const HomeScreen()),
          );
        },
        icon: const Icon(Icons.agriculture, color: Colors.orange),
        label: const Text(
          "Switch to Farmer Mode",
          style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
        ),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 15),
          side: BorderSide(color: Colors.orange.shade800, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}