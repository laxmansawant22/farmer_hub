import 'package:flutter/material.dart';

class MarketPricesScreen extends StatelessWidget {
  const MarketPricesScreen({super.key});

  final List<Map<String, dynamic>> prices = const [
    {'crop': 'Wheat (Kanak)', 'price': '2,125', 'unit': 'Quintal', 'trend': 'up', 'market': 'Indore Mandi'},
    {'crop': 'Basmati Rice', 'price': '4,500', 'unit': 'Quintal', 'trend': 'down', 'market': 'Karnal Market'},
    {'crop': 'Mustard (Sarson)', 'price': '5,450', 'unit': 'Quintal', 'trend': 'stable', 'market': 'Jaipur Mandi'},
    {'crop': 'Tomato', 'price': '1,200', 'unit': 'Crate', 'trend': 'up', 'market': 'Azadpur Mandi'},
    {'crop': 'Potato', 'price': '800', 'unit': 'Sack', 'trend': 'down', 'market': 'Agra Market'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF4A6D41),
        title: const Text("Today's Market Prices", style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(15),
            color: Colors.green.withValues(alpha: 0.1),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: Color(0xFF4A6D41)),
                SizedBox(width: 10),
                Expanded(child: Text("Prices are updated every 6 hours based on major Mandis.")),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(10),
              itemCount: prices.length,
              itemBuilder: (context, index) {
                final item = prices[index];
                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(15),
                    title: Text(item['crop'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    subtitle: Text("Market: ${item['market']}"),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text("₹${item['price']}", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF4A6D41))),
                        Text("per ${item['unit']}", style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        _getTrendIcon(item['trend']),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _getTrendIcon(String trend) {
    if (trend == 'up') return const Icon(Icons.trending_up, color: Colors.green, size: 16);
    if (trend == 'down') return const Icon(Icons.trending_down, color: Colors.red, size: 16);
    return const Icon(Icons.trending_flat, color: Colors.blue, size: 16);
  }
}