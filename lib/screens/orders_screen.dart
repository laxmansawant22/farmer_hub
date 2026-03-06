import 'package:flutter/material.dart';

class OrdersScreen extends StatelessWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: const Color(0xFF4A6D41),
          title: const Text("My Orders", style: TextStyle(color: Colors.white)),
          bottom: const TabBar(
            indicatorColor: Colors.white,
            tabs: [
              Tab(text: "Active"),
              Tab(text: "Completed"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildOrderList(isActive: true),
            _buildOrderList(isActive: false),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderList({required bool isActive}) {
    // 📍 Sample data for the farmer
    return ListView.builder(
      padding: const EdgeInsets.all(15),
      itemCount: isActive ? 3 : 5,
      itemBuilder: (context, index) {
        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 15),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Order #102$index", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                    _statusChip(isActive ? "Pending" : "Delivered"),
                  ],
                ),
                const Divider(),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const CircleAvatar(backgroundColor: Color(0xFFE8F5E9), child: Icon(Icons.shopping_basket, color: Colors.green)),
                  title: Text(index % 2 == 0 ? "Organic Tomatoes" : "Fresh Potatoes", style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text("Customer: Sanjay Desai\nQuantity: 10 kg"),
                  trailing: Text("₹ ${120 * (index + 1)}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green)),
                ),
                if (isActive) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {},
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                          child: const Text("Mark as Shipped", style: TextStyle(color: Colors.white)),
                        ),
                      ),
                    ],
                  )
                ]
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _statusChip(String status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: status == "Pending" ? Colors.orange[100] : Colors.green[100],
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(status, style: TextStyle(color: status == "Pending" ? Colors.orange[800] : Colors.green[800], fontSize: 12, fontWeight: FontWeight.bold)),
    );
  }
}