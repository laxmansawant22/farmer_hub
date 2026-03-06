import 'package:flutter/material.dart';

class ExpenseTrackerScreen extends StatefulWidget {
  const ExpenseTrackerScreen({super.key});

  @override
  State<ExpenseTrackerScreen> createState() => _ExpenseTrackerScreenState();
}

class _ExpenseTrackerScreenState extends State<ExpenseTrackerScreen> {
  String _selectedFilter = 'All';

  final List<Map<String, dynamic>> _transactions = [
    {'title': 'Wheat Sale', 'amount': 12000.0, 'isIncome': true, 'date': DateTime.now()},
    {'title': 'Fertilizer', 'amount': 2500.0, 'isIncome': false, 'date': DateTime.now().subtract(const Duration(days: 45))},
    {'title': 'Tractor Repair', 'amount': 5000.0, 'isIncome': false, 'date': DateTime.now().subtract(const Duration(days: 2))},
  ];

  List<Map<String, dynamic>> get _filteredTransactions {
    final now = DateTime.now();
    if (_selectedFilter == 'Month') {
      return _transactions.where((t) => t['date'].month == now.month && t['date'].year == now.year).toList();
    } else if (_selectedFilter == 'Year') {
      return _transactions.where((t) => t['date'].year == now.year).toList();
    }
    return _transactions;
  }

  double get totalIncome => _filteredTransactions.where((t) => t['isIncome']).fold(0, (sum, t) => sum + t['amount']);
  double get totalExpense => _filteredTransactions.where((t) => !t['isIncome']).fold(0, (sum, t) => sum + t['amount']);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Expense & Profit Tracker"),
        backgroundColor: const Color(0xFF4A6D41),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          _buildBalanceCard(),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
            child: Row(
              children: [
                const Text("Filter:", style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(width: 10),
                _filterChip('All'),
                const SizedBox(width: 5),
                _filterChip('Month'),
                const SizedBox(width: 5),
                _filterChip('Year'),
              ],
            ),
          ),

          Expanded(
            child: ListView.builder(
              itemCount: _filteredTransactions.length,
              itemBuilder: (context, index) {
                final t = _filteredTransactions[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: t['isIncome']
                        ? Colors.green.withValues(alpha: 0.1)
                        : Colors.red.withValues(alpha: 0.1),
                    child: Icon(
                      t['isIncome'] ? Icons.arrow_upward : Icons.arrow_downward,
                      color: t['isIncome'] ? Colors.green : Colors.red,
                    ),
                  ),
                  title: Text(t['title'], style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text("${t['date'].day}/${t['date'].month}/${t['date'].year}"),
                  trailing: Text(
                    "₹${t['amount']}",
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: t['isIncome'] ? Colors.green : Colors.red
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

  Widget _filterChip(String label) {
    return ChoiceChip(
      label: Text(label),
      selected: _selectedFilter == label,
      onSelected: (bool selected) {
        setState(() {
          _selectedFilter = label;
        });
      },
    );
  }

  Widget _buildBalanceCard() {
    double net = totalIncome - totalExpense;
    bool isProfit = net >= 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: isProfit ? const Color(0xFF4A6D41) : Colors.red.shade900,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Text("$_selectedFilter Net Result", style: const TextStyle(color: Colors.white70)),
          Text("₹${net.abs()}", style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),

          // Profit/Loss Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              isProfit ? "YOU ARE IN PROFIT" : "YOU ARE IN LOSS",
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),

          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _summaryItem("Income", "₹$totalIncome", Icons.add_circle_outline, Colors.greenAccent),
              _summaryItem("Expense", "₹$totalExpense", Icons.remove_circle_outline, Colors.orangeAccent),
            ],
          ),
        ],
      ),
    );
  }

  // 📍 Method now properly defined within the state class
  Widget _summaryItem(String label, String value, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 5),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
            Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
      ],
    );
  }
}