import 'package:flutter/material.dart';

class CalculatorScreen extends StatefulWidget {
  @override
  _CalculatorScreenState createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends State<CalculatorScreen> {
  String _result = "Enter details to calculate";
  final TextEditingController _area = TextEditingController();

  void calculate() {
    double area = double.tryParse(_area.text) ?? 0;
    setState(() => _result = "Recommended: ${(area * 45).toStringAsFixed(1)} kg Fertilizer");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Fertilizer Spreading Guide")),
      body: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(controller: _area, decoration: InputDecoration(labelText: "Land Size (Acres)", border: OutlineInputBorder())),
            SizedBox(height: 20),
            ElevatedButton(onPressed: calculate, child: Text("Calculate Requirement")),
            SizedBox(height: 30),
            Container(padding: EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.green.withOpacity(0.1)), child: Text(_result, style: TextStyle(fontSize: 18, color: Colors.green, fontWeight: FontWeight.bold)))
          ],
        ),
      ),
    );
  }
}