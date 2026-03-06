import 'package:flutter/material.dart';

class SalesScreen extends StatelessWidget {
  const SalesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Sales Overview", style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF4A6D41),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 📍 Moved from Home: Total Sales Card
            _buildTotalSalesCard(),
            const SizedBox(height: 30),
            const Text("Active Sales",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),
            // 📍 List of current active sales
            _buildActiveSalesList(),
          ],
        ),
      ),
    );
  }

  Widget _buildTotalSalesCard() {
    return Container(
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6B8E61), Color(0xFF4A6D41)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 5),
          )
        ],
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Total Revenue", style: TextStyle(color: Colors.white70, fontSize: 16)),
              SizedBox(height: 8),
              Text("₹ 85,000",
                  style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
              Text("Calculated from all time sales", style: TextStyle(color: Colors.white54, fontSize: 12)),
            ],
          ),
          Icon(Icons.account_balance_wallet, color: Colors.white, size: 50),
        ],
      ),
    );
  }

  Widget _buildActiveSalesList() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 4, // Sample count
      itemBuilder: (context, index) {
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          child: ListTile(
            leading: const CircleAvatar(
              backgroundColor: Color(0xFFE8F5E9),
              child: Icon(Icons.trending_up, color: Colors.green),
            ),
            title: Text(index % 2 == 0 ? "Bulk Tomatoes Order" : "Carrot Wholesale"),
            subtitle: Text("Quantity: ${20 + (index * 5)} kg"),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text("₹ ${500 * (index + 1)}",
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                const Text("Processing", style: TextStyle(fontSize: 10, color: Colors.orange)),
              ],
            ),
          ),
        );
      },
    );
  }
}