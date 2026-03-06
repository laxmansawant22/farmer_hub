import 'package:flutter/material.dart';

class CustomerMarketScreen extends StatelessWidget {
  const CustomerMarketScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Customer Market",
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: const Color(0xFF2E7D32), // Dark Green
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.menu, color: Colors.white),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildWelcomeHeader(),
            const SizedBox(height: 20),
            _buildSearchBar(),
            const SizedBox(height: 25),
            _buildProductCategories(),
            const SizedBox(height: 10),
            _buildOtherFeatures(),
            const SizedBox(height: 25),
            const Text("Popular Farmers",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),
            _buildPopularFarmersList(),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text("Welcome, Rajesh!",
            style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2E7D32))),
        TextButton(
          onPressed: () {},
          child: const Text("Edit", style: TextStyle(color: Colors.green)),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)],
      ),
      child: const TextField(
        decoration: InputDecoration(
          hintText: "Search fruits, vegetables...",
          prefixIcon: Icon(Icons.search, color: Colors.green),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: 15),
        ),
      ),
    );
  }

  Widget _buildProductCategories() {
    return Row(
      children: [
        _buildCategoryCard("Vegetables", "https://cdn-icons-png.flaticon.com/512/10411/10411265.png"),
        const SizedBox(width: 15),
        _buildCategoryCard("Fruits", "https://cdn-icons-png.flaticon.com/512/3194/3194591.png"),
      ],
    );
  }

  Widget _buildCategoryCard(String name, String imageUrl) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.green[50],
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.green[100]!),
        ),
        child: Column(
          children: [
            Image.network(imageUrl, height: 60),
            const SizedBox(height: 10),
            Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildOtherFeatures() {
    return Row(
      children: [
        _buildFeatureCard("My\nCart", Icons.shopping_cart_outlined),
        const SizedBox(width: 15),
        _buildFeatureCard("Nearby\nFarmer", Icons.location_on_outlined),
      ],
    );
  }

  Widget _buildFeatureCard(String title, IconData icon) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.only(top: 15),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.green),
            const SizedBox(width: 10),
            Text(title, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _buildPopularFarmersList() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 2,
      itemBuilder: (context, index) {
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          child: ListTile(
            leading: const CircleAvatar(backgroundColor: Colors.white, radius: 25, backgroundImage: NetworkImage("https://cdn-icons-png.flaticon.com/512/2044/2044805.png")),
            title: Text(index == 0 ? "Sanjay Patel" : "Ramesh Patel", style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(index == 0 ? "Organic Farm • 1.5 km away" : "Pure Organic Farm • 2.0 km away"),
            trailing: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.star, color: Colors.amber, size: 20), Text("4.5", style: TextStyle(fontWeight: FontWeight.bold))]),
          ),
        );
      },
    );
  }
}