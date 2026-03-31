import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:fl_chart/fl_chart.dart';

// 📍 Standard Project Imports
import '../translations.dart';

class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key});

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  DateTimeRange? _selectedDateRange;
  final String? farmerEmail = FirebaseAuth.instance.currentUser?.email;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";
  String _selectedStatus = "All";

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>> _getUserData(String email) async {
    var snap = await FirebaseFirestore.instance.collection('users').doc(email).get();
    return snap.data() ?? {'name': email, 'phone': 'N/A', 'address': 'N/A'};
  }

  Future<Map<String, dynamic>> _getFarmerData() async {
    var snap = await FirebaseFirestore.instance.collection('users').doc(farmerEmail).get();
    return snap.data() ?? {'name': 'Farmer', 'phone': 'N/A', 'address': 'N/A'};
  }

  Future<void> _generatePdf(List<QueryDocumentSnapshot> docs, double total, String periodLabel, {bool isShare = true}) async {
    try {
      final pdf = pw.Document();
      var farmerData = await _getFarmerData();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(32),
          header: (context) => pw.Column(
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text("AGRI MARKET - SALES REPORT", style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.green900)),
                    pw.Text("Date: ${DateFormat('dd/MM/yyyy').format(DateTime.now())}"),
                  ],
                ),
                pw.Divider(thickness: 1),
                pw.SizedBox(height: 10),
              ]
          ),
          footer: (context) => pw.Align(alignment: pw.Alignment.centerRight, child: pw.Text("Page ${context.pageNumber} of ${context.pagesCount}")),
          build: (pw.Context context) => [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  pw.Text("FARMER DETAILS", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                  pw.Text("Name: ${farmerData['name'] ?? 'N/A'}"),
                  pw.Text("Contact: ${farmerData['phone'] ?? 'N/A'}"),
                  pw.Container(width: 200, child: pw.Text("Address: ${farmerData['address'] ?? 'N/A'}", style: const pw.TextStyle(fontSize: 8))),
                ]),
                pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                  pw.Text("REPORT SUMMARY", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                  pw.Text("Period: $periodLabel"),
                  pw.Text("Transactions: ${docs.length}"),
                  pw.Text("Total Revenue: Rs ${total.toStringAsFixed(2)}", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.green)),
                ]),
              ],
            ),
            pw.SizedBox(height: 20),
            pw.TableHelper.fromTextArray(
              headers: ['Sr.', 'Product', 'Order Date', 'Customer', 'Amount', 'Status'],
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.green800),
              cellStyle: const pw.TextStyle(fontSize: 9),
              data: List.generate(docs.length, (index) {
                var data = docs[index].data() as Map<String, dynamic>;
                DateTime oDate = data['timestamp'] != null ? (data['timestamp'] as Timestamp).toDate() : DateTime.now();
                double amt = ((data['price'] ?? 0) * (data['qty'] ?? 0)) + (double.tryParse(data['deliveryCharge']?.toString() ?? '0') ?? 0.0);

                return [
                  (index + 1).toString(),
                  data['productName'] ?? "N/A",
                  DateFormat('dd/MM/yy').format(oDate),
                  data['customerEmail']?.split('@')[0] ?? "N/A",
                  "Rs ${amt.toStringAsFixed(2)}",
                  data['status'] ?? "N/A",
                ];
              }),
            ),
          ],
        ),
      );

      if (isShare) {
        final output = await getTemporaryDirectory();
        final file = File("${output.path}/AgriReport_${DateTime.now().millisecondsSinceEpoch}.pdf");
        await file.writeAsBytes(await pdf.save());
        await Share.shareXFiles([XFile(file.path)], text: 'Detailed Sales Report');
      } else {
        await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save(), name: 'Detailed_Report.pdf');
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("PDF Error: $e")));
    }
  }

  Future<void> _generateSingleInvoice(Map<String, dynamic> data, String orderId) async {
    try {
      final pdf = pw.Document();
      double subtotal = ((data['price'] ?? 0) * (data['qty'] ?? 0)).toDouble();
      double delivery = double.tryParse(data['deliveryCharge']?.toString() ?? '0') ?? 0.0;
      DateTime orderDate = data['timestamp'] != null ? (data['timestamp'] as Timestamp).toDate() : DateTime.now();

      var farmerData = await _getFarmerData();
      var customerData = await _getUserData(data['customerEmail']);

      pdf.addPage(
        pw.Page(
          build: (context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                pw.Text("TAX INVOICE", style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.green900)),
                pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                  pw.Text("Order ID: #${orderId.substring(0, 8)}"),
                  pw.Text("Date: ${DateFormat('dd MMM yyyy').format(orderDate)}"),
                ]),
              ]),
              pw.Divider(thickness: 2, color: PdfColors.green),
              pw.SizedBox(height: 20),
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  pw.Text("FROM (FARMER):", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                  pw.Text(farmerData['name'] ?? "N/A", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.Text("Mob: ${farmerData['phone'] ?? 'N/A'}"),
                  pw.Container(width: 180, child: pw.Text("Addr: ${farmerData['address'] ?? 'N/A'}", style: const pw.TextStyle(fontSize: 8))),
                ]),
                pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                  pw.Text("BILL TO (CUSTOMER):", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                  pw.Text(customerData['name'] ?? "N/A", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.Text("Mob: ${customerData['phone'] ?? 'N/A'}"),
                  pw.Container(width: 180, child: pw.Text("Addr: ${customerData['address'] ?? 'N/A'}", textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 8))),
                ]),
              ]),
              pw.SizedBox(height: 40),
              pw.TableHelper.fromTextArray(
                headers: ['Product Item', 'Unit Price', 'Qty', 'Total'],
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.green800),
                data: [[data['productName'] ?? "N/A", "Rs ${data['price']}", data['qty'], "Rs $subtotal"]],
              ),
              pw.SizedBox(height: 30),
              pw.Align(alignment: pw.Alignment.centerRight, child: pw.Container(width: 200, child: pw.Column(children: [
                pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text("Subtotal:"), pw.Text("Rs $subtotal")]),
                pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text("Delivery:"), pw.Text("Rs $delivery")]),
                pw.Divider(),
                pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                  pw.Text("Grand Total:", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.Text("Rs ${subtotal + delivery}", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14, color: PdfColors.green900)),
                ]),
              ]))),
              pw.Spacer(),
              pw.Center(child: pw.Text("Thank you for using Agri Market!", style: pw.TextStyle(fontStyle: pw.FontStyle.italic, color: PdfColors.grey700))),
            ],
          ),
        ),
      );
      await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save(), name: 'Invoice $orderId.pdf');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Invoice Error: $e")));
    }
  }

  void _showReportOptions(List<QueryDocumentSnapshot> allDocs) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          children: [
            Text(AppTranslations.translate(context, 'select period'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 15),
            ListTile(
              leading: const Icon(Icons.date_range, color: Color(0xFF4A6D41)),
              title: const Text("Custom Date Range"),
              onTap: () async {
                Navigator.pop(context);
                final picked = await showDateRangePicker(context: context, firstDate: DateTime(2024), lastDate: DateTime.now());
                if (picked != null) {
                  String label = "${DateFormat('dd/MM/yy').format(picked.start)} - ${DateFormat('dd/MM/yy').format(picked.end)}";
                  _processFilteredReport(allDocs, picked.start, picked.end, label);
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.calendar_month, color: Color(0xFF4A6D41)),
              title: const Text("Current Month Report"),
              onTap: () {
                Navigator.pop(context);
                DateTime now = DateTime.now();
                _processFilteredReport(allDocs, DateTime(now.year, now.month, 1), now, DateFormat('MMMM yyyy').format(now));
              },
            ),
          ],
        ),
      ),
    );
  }

  void _processFilteredReport(List<QueryDocumentSnapshot> docs, DateTime start, DateTime end, String label) {
    var filtered = docs.where((doc) {
      DateTime d = (doc['timestamp'] as Timestamp).toDate();
      return d.isAfter(start.subtract(const Duration(seconds: 1))) && d.isBefore(end.add(const Duration(days: 1)));
    }).toList();

    double earnings = filtered.fold(0, (prev, doc) {
      var data = doc.data() as Map<String, dynamic>;
      return prev + ((data['price'] ?? 0) * (data['qty'] ?? 0)) + (double.tryParse(data['deliveryCharge']?.toString() ?? '0') ?? 0.0);
    });

    if (filtered.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No data for this period")));
      return;
    }

    _generatePdf(filtered, earnings, label, isShare: false);
  }

  void _showOrderDetails(Map<String, dynamic> data, String docId) {
    double itemTotal = ((data['price'] ?? 0) * (data['qty'] ?? 0)).toDouble();
    double del = double.tryParse(data['deliveryCharge']?.toString() ?? '0') ?? 0.0;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('users').doc(data['customerEmail']).snapshots(),
          builder: (context, snapshot) {
            var userData = snapshot.data?.data() as Map<String, dynamic>?;
            return Padding(
              padding: const EdgeInsets.all(25),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    const Text("Order Details", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close))
                  ]),
                  const Divider(),
                  _infoRow("Order ID", "#${docId.substring(0, 8)}"),
                  _infoRow("Order Date", data['timestamp'] != null ? DateFormat('dd MMM yyyy, hh:mm a').format((data['timestamp'] as Timestamp).toDate()) : "N/A"),
                  _infoRow("Customer", userData?['name'] ?? "N/A"),
                  _infoRow("Contact", userData?['phone'] ?? "N/A"),
                  _infoRow("Product", data['productName']),
                  _infoRow("Quantity", "${data['qty']}"),
                  _infoRow("Total Amount", "₹${itemTotal + del}", isBold: true),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () { Navigator.pop(context); _generateSingleInvoice(data, docId); },
                      icon: const Icon(Icons.download),
                      label: const Text("Download Invoice"),
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4A6D41), foregroundColor: Colors.white),
                    ),
                  )
                ],
              ),
            );
          }
      ),
    );
  }

  Widget _infoRow(String label, String? value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 14)),
        Flexible(child: Text(value ?? "N/A", textAlign: TextAlign.right, style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.w600, fontSize: 14))),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () {
            if (_selectedDateRange != null) {
              setState(() => _selectedDateRange = null);
            } else {
              Navigator.pop(context);
            }
          },
        ),
        title: Text(AppTranslations.translate(context, 'Sales analytics')),
        backgroundColor: const Color(0xFF4A6D41),
        foregroundColor: Colors.white,
        actions: [
          if (_selectedDateRange != null)
            IconButton(icon: const Icon(Icons.filter_alt_off), onPressed: () => setState(() => _selectedDateRange = null)),
          IconButton(icon: const Icon(Icons.calendar_month), onPressed: () async {
            final picked = await showDateRangePicker(context: context, firstDate: DateTime(2023), lastDate: DateTime.now());
            if (picked != null) setState(() { _selectedDateRange = picked; });
          })
        ],
        bottom: TabBar(
            controller: _tabController,
            indicatorColor: Colors.white,
            // This sets the color for the currently selected tab
            labelColor: Colors.white,
            // This sets the "dark white" / grey color for the unselected tabs
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(text: AppTranslations.translate(context, 'analytics')),
              Tab(text: AppTranslations.translate(context, 'history')),


        ]),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('farmer orders')
            .where('farmerEmail', isEqualTo: farmerEmail)
            .where('status', whereIn: ['Shipped', 'Delivered', 'Completed', 'Received', 'shipped', 'delivered', 'completed', 'received'])
            .orderBy('timestamp', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text("No records found"));

          var docs = snapshot.data!.docs;
          if (_selectedDateRange != null) {
            docs = docs.where((doc) {
              DateTime d = (doc['timestamp'] as Timestamp).toDate();
              return d.isAfter(_selectedDateRange!.start) && d.isBefore(_selectedDateRange!.end.add(const Duration(days: 1)));
            }).toList();
          }

          double totalEarnings = docs.fold(0, (prev, doc) {
            var data = doc.data() as Map<String, dynamic>;
            double sub = ((data['price'] ?? 0) * (data['qty'] ?? 0)).toDouble();
            double del = double.tryParse(data['deliveryCharge']?.toString() ?? '0') ?? 0.0;
            return prev + sub + del;
          });

          return TabBarView(controller: _tabController, children: [
            _buildAnalyticsTab(docs, totalEarnings, snapshot.data!.docs),
            _buildHistoryTab(docs),
          ]);
        },
      ),
    );
  }

  Widget _buildAnalyticsTab(List<QueryDocumentSnapshot> currentDocs, double totalEarnings, List<QueryDocumentSnapshot> allDocs) {
    String label = _selectedDateRange == null ? "Total Lifetime Revenue" : "${DateFormat('dd MMM').format(_selectedDateRange!.start)} - ${DateFormat('dd MMM').format(_selectedDateRange!.end)}";

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(children: [
        _buildSummaryHeader(totalEarnings, currentDocs.length, label),
        _buildChart(currentDocs),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: ElevatedButton.icon(
            onPressed: () => _showReportOptions(allDocs),
            icon: const Icon(Icons.picture_as_pdf),
            label: Text(AppTranslations.translate(context, 'Download report')),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[800], foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Align(alignment: Alignment.centerLeft, child: Text("Recent Sales", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
        ),
        _buildTransactionList(currentDocs, limit: 10),
      ]),
    );
  }

  Widget _buildHistoryTab(List<QueryDocumentSnapshot> docs) {
    var filteredDocs = docs.where((doc) {
      var data = doc.data() as Map<String, dynamic>;
      String prodName = (data['productName'] ?? "").toString().toLowerCase();
      String status = (data['status'] ?? "").toString().toLowerCase();
      return prodName.contains(_searchQuery) && (_selectedStatus == "All" || status == _selectedStatus.toLowerCase());
    }).toList();

    return Column(children: [
      Padding(
        padding: const EdgeInsets.all(15),
        child: Row(children: [
          Expanded(child: TextField(controller: _searchController, decoration: InputDecoration(hintText: "Search items...", prefixIcon: const Icon(Icons.search), filled: true, fillColor: Colors.grey[200], border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none)))),
          const SizedBox(width: 10),
          DropdownButton<String>(value: _selectedStatus, underline: const SizedBox(), icon: const Icon(Icons.filter_list), items: ["All", "Shipped", "Delivered", "Completed", "Received"].map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 12)))).toList(), onChanged: (val) => setState(() => _selectedStatus = val!)),
        ]),
      ),
      Expanded(
        child: ListView.builder(
          itemCount: filteredDocs.length,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          itemBuilder: (context, index) {
            var data = filteredDocs[index].data() as Map<String, dynamic>;
            double total = ((data['price'] ?? 0) * (data['qty'] ?? 0)) + (double.tryParse(data['deliveryCharge']?.toString() ?? '0') ?? 0.0);
            return Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
                // 📍 FIXED: Changed parameter to 'side' and used BorderSide
                side: BorderSide(color: Colors.grey[200]!, width: 1),
              ),
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                onTap: () => _showOrderDetails(data, filteredDocs[index].id),
                leading: const CircleAvatar(
                    backgroundColor: Color(0xFF4A6D41),
                    child: Icon(Icons.shopping_bag, color: Colors.white, size: 18)
                ),
                title: Text(data['productName'] ?? "Product", style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(DateFormat('dd MMM, yyyy').format((data['timestamp'] as Timestamp).toDate())),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text("₹${total.toStringAsFixed(0)}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                    Text(data['status'] ?? "", style: TextStyle(fontSize: 10, color: Colors.grey[600])),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    ]);
  }

  Widget _buildTransactionList(List<QueryDocumentSnapshot> docs, {int? limit}) {
    var list = limit != null ? docs.take(limit).toList() : docs;
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: list.length,
      itemBuilder: (context, index) {
        var data = list[index].data() as Map<String, dynamic>;
        double total = ((data['price'] ?? 0) * (data['qty'] ?? 0)) + (double.tryParse(data['deliveryCharge']?.toString() ?? '0') ?? 0.0);
        return ListTile(
          onTap: () => _showOrderDetails(data, list[index].id),
          leading: const Icon(Icons.history_edu, color: Color(0xFF4A6D41)),
          title: Text(data['productName'] ?? "Product", style: const TextStyle(fontSize: 14)),
          subtitle: Text(data['customerEmail']?.split('@')[0] ?? ""),
          trailing: Text("₹${total.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold)),
        );
      },
    );
  }

  Widget _buildSummaryHeader(double total, int count, String periodLabel) {
    return Container(
      width: double.infinity, padding: const EdgeInsets.all(25), margin: const EdgeInsets.all(15),
      decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF4A6D41), Color(0xFF6B8E61)], begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(25),
          boxShadow: [BoxShadow(color: Colors.green.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5))]
      ),
      child: Column(children: [
        Text(periodLabel.toUpperCase(), style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
        const SizedBox(height: 5),
        Text("₹${total.toStringAsFixed(2)}", style: const TextStyle(color: Colors.white, fontSize: 38, fontWeight: FontWeight.bold)),
        const SizedBox(height: 5),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(20)),
          child: Text("$count Successful Sales", style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500)),
        ),
      ]),
    );
  }

  Widget _buildChart(List<QueryDocumentSnapshot> docs) {
    Map<DateTime, double> dailyMap = {};
    for (int i = 6; i >= 0; i--) {
      DateTime day = DateTime.now().subtract(Duration(days: i));
      dailyMap[DateTime(day.year, day.month, day.day)] = 0;
    }
    for (var doc in docs) {
      var data = doc.data() as Map<String, dynamic>;
      if (data['timestamp'] == null) continue;
      DateTime date = (data['timestamp'] as Timestamp).toDate();
      DateTime key = DateTime(date.year, date.month, date.day);
      if (dailyMap.containsKey(key)) {
        double total = ((data['price'] ?? 0) * (data['qty'] ?? 0)) + (double.tryParse(data['deliveryCharge']?.toString() ?? '0') ?? 0.0);
        dailyMap[key] = dailyMap[key]! + total;
      }
    }
    List<DateTime> sortedKeys = dailyMap.keys.toList()..sort();
    return Container(
      height: 220, padding: const EdgeInsets.all(20),
      child: BarChart(BarChartData(
        barGroups: List.generate(sortedKeys.length, (i) => BarChartGroupData(x: i, barRods: [BarChartRodData(toY: dailyMap[sortedKeys[i]]!, color: const Color(0xFF4A6D41), width: 16, borderRadius: BorderRadius.circular(4))])),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (v, m) {
            int i = v.toInt();
            if (i < 0 || i >= sortedKeys.length) return const SizedBox();
            return Padding(padding: const EdgeInsets.only(top: 8), child: Text(DateFormat('E').format(sortedKeys[i]), style: const TextStyle(fontSize: 10, color: Colors.grey)));
          })),
        ),
        gridData: const FlGridData(show: false), borderData: FlBorderData(show: false),
      )),
    );
  }
}