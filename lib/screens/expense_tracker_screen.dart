import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

enum FilterType { month, year, custom }
enum TransactionTypeFilter { all, income, expense }

class ExpenseTrackerScreen extends StatefulWidget {
  const ExpenseTrackerScreen({super.key});

  @override
  State<ExpenseTrackerScreen> createState() => _ExpenseTrackerScreenState();
}

class _ExpenseTrackerScreenState extends State<ExpenseTrackerScreen> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _otherCategoryController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  final List<String> _expenseCategories = ['seeds', 'labor', 'fertilizer', 'pesticides', 'machinery', 'transport', 'irrigation', 'other'];
  final List<String> _incomeCategories = ['crop_sale', 'government_subsidy', 'equipment_rental', 'livestock_sale', 'other_income', 'other'];

  final _firestore = FirebaseFirestore.instance;
  final _user = FirebaseAuth.instance.currentUser;

  FilterType _activeFilter = FilterType.month;
  TransactionTypeFilter _typeFilter = TransactionTypeFilter.all;
  DateTime _selectedMonthYear = DateTime.now();
  DateTimeRange? _customRange;

  final Set<String> _selectedIds = {};
  bool _isSelectionMode = false;
  bool _isSearching = false;
  String _searchQuery = "";

  @override
  void initState() {
    super.initState();
    // 📍 Trigger the daily reminder check when the screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkDailyRecord());
  }

  // 📍 NEW: ALERT NOTIFICATION LOGIC
  // Checks if any record exists for today. If not, shows a reminder.
  Future<void> _checkDailyRecord() async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final snapshot = await _firestore
        .collection('users')
        .doc(_user?.email)
        .collection('transactions')
        .where('timestamp', isGreaterThanOrEqualTo: startOfDay)
        .where('timestamp', isLessThan: endOfDay)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) {
      _showDailyReminder();
    }
  }

  void _showDailyReminder() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Row(
          children: [
            Icon(Icons.notification_important, color: Color(0xFF4A6D41)),
            SizedBox(width: 10),
            Text("Daily Reminder"),
          ],
        ),
        content: const Text("Namaste! You haven't added any farming records for today. Would you like to add one now?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("LATER", style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4A6D41)),
            onPressed: () {
              Navigator.pop(ctx);
              _showAddDialog();
            },
            child: const Text("ADD NOW", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _resetAllFilters() {
    setState(() {
      _activeFilter = FilterType.month;
      _typeFilter = TransactionTypeFilter.all;
      _selectedMonthYear = DateTime.now();
      _customRange = null;
      _isSearching = false;
      _searchQuery = "";
      _searchController.clear();
    });
  }

  // 📍 PDF EXPORT WITH SHARING
  Future<void> _exportAndSharePDF(List<DocumentSnapshot> docs, String farmerName, double totalIn, double totalOut) async {
    final pdf = pw.Document();
    final net = totalIn - totalOut;
    final isProfit = net >= 0;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) => [
          pw.Header(
            level: 0,
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text("Farming Financial Report", style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
                pw.Text(DateFormat('dd/MM/yyyy').format(DateTime.now())),
              ],
            ),
          ),
          pw.SizedBox(height: 10),
          pw.Text("Farmer Name: $farmerName", style: pw.TextStyle(fontSize: 14)),
          pw.Divider(),
          pw.SizedBox(height: 20),

          pw.TableHelper.fromTextArray(
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.green800),
            cellAlignment: pw.Alignment.centerLeft,
            headers: ['Date', 'Type', 'Category', 'Description', 'Amount'],
            data: docs.map((doc) {
              final date = (doc['timestamp'] as Timestamp).toDate();
              return [
                DateFormat('dd/MM/yy').format(date),
                doc['isIncome'] ? 'Income' : 'Expense',
                doc['category'].toString().toUpperCase(),
                doc['title'],
                "INR ${doc['amount']}"
              ];
            }).toList(),
          ),

          pw.SizedBox(height: 30),

          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey)),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                  pw.Text("Total Income:"),
                  pw.Text("INR ${totalIn.toStringAsFixed(2)}", style: pw.TextStyle(color: PdfColors.green)),
                ]),
                pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                  pw.Text("Total Expense:"),
                  pw.Text("INR ${totalOut.toStringAsFixed(2)}", style: pw.TextStyle(color: PdfColors.red)),
                ]),
                pw.Divider(),
                pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                  pw.Text("Net Status:", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.Text(
                    isProfit ? "PROFIT" : "LOSS",
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: isProfit ? PdfColors.green : PdfColors.red),
                  ),
                ]),
                pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                  pw.Text("Final Balance:", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.Text(
                    "INR ${net.abs().toStringAsFixed(2)}",
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: isProfit ? PdfColors.green : PdfColors.red),
                  ),
                ]),
              ],
            ),
          ),
          pw.Footer(
            padding: const pw.EdgeInsets.only(top: 20),
            trailing: pw.Text("Generated via Farm Expense Tracker", style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey)),
          ),
        ],
      ),
    );

    await Printing.sharePdf(
        bytes: await pdf.save(),
        filename: 'Farm_Report_${farmerName}_${DateFormat('dd_MM_yy').format(DateTime.now())}.pdf'
    );
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
        if (_selectedIds.isEmpty) _isSelectionMode = false;
      } else {
        _selectedIds.add(id);
        _isSelectionMode = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: _firestore.collection('users').doc(_user?.email).snapshots(),
      builder: (context, userSnapshot) {
        String farmerName = userSnapshot.data?.get('name') ?? "Farmer";

        return StreamBuilder<QuerySnapshot>(
          stream: _firestore.collection('users').doc(_user?.email).collection('transactions').orderBy('timestamp', descending: true).snapshots(),
          builder: (context, snapshot) {
            final allDocs = snapshot.data?.docs ?? [];
            final filteredDocs = allDocs.where((doc) {
              if (doc['timestamp'] == null) return false;

              if (_searchQuery.isNotEmpty) {
                bool matchesTitle = doc['title'].toString().toLowerCase().contains(_searchQuery.toLowerCase());
                bool matchesCategory = doc['category'].toString().toLowerCase().contains(_searchQuery.toLowerCase());
                if (!matchesTitle && !matchesCategory) return false;
              }

              if (_typeFilter == TransactionTypeFilter.income && !doc['isIncome']) return false;
              if (_typeFilter == TransactionTypeFilter.expense && doc['isIncome']) return false;

              DateTime date = (doc['timestamp'] as Timestamp).toDate();
              if (_activeFilter == FilterType.month) return date.month == _selectedMonthYear.month && date.year == _selectedMonthYear.year;
              if (_activeFilter == FilterType.year) return date.year == _selectedMonthYear.year;
              if (_activeFilter == FilterType.custom && _customRange != null) {
                return date.isAfter(_customRange!.start) && date.isBefore(_customRange!.end.add(const Duration(days: 1)));
              }
              return true;
            }).toList();

            double totalIn = 0;
            double totalOut = 0;
            for (var doc in filteredDocs) {
              double amt = (doc['amount'] as num).toDouble();
              doc['isIncome'] ? totalIn += amt : totalOut += amt;
            }

            return Scaffold(
              appBar: AppBar(
                backgroundColor: _isSelectionMode ? Colors.red[800] : const Color(0xFF4A6D41),
                foregroundColor: Colors.white,
                title: _isSearching
                    ? TextField(
                  controller: _searchController,
                  autofocus: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(hintText: "Search category or items...", hintStyle: TextStyle(color: Colors.white70), border: InputBorder.none),
                  onChanged: (val) => setState(() => _searchQuery = val),
                )
                    : Text(_isSelectionMode ? "${_selectedIds.length} Selected" : "Farming Accounts"),
                actions: [
                  if (_isSelectionMode)
                    IconButton(icon: const Icon(Icons.delete), onPressed: _deleteSelected)
                  else ...[
                    if (_typeFilter != TransactionTypeFilter.all || _searchQuery.isNotEmpty || _activeFilter != FilterType.month)
                      IconButton(
                          icon: const Icon(Icons.rotate_left),
                          tooltip: "Reset Filters",
                          onPressed: _resetAllFilters
                      ),
                    IconButton(
                        icon: Icon(_isSearching ? Icons.close : Icons.search),
                        onPressed: () => setState(() {
                          _isSearching = !_isSearching;
                          if (!_isSearching) {
                            _searchQuery = "";
                            _searchController.clear();
                          }
                        })
                    ),
                    IconButton(
                        icon: const Icon(Icons.share),
                        onPressed: () => _exportAndSharePDF(filteredDocs, farmerName, totalIn, totalOut)
                    ),
                  ]
                ],
              ),
              body: Column(
                children: [
                  _buildHeader(farmerName),
                  _buildFilterSelector(),
                  _buildProfitCard(totalIn, totalOut, totalIn - totalOut),
                  if (_typeFilter != TransactionTypeFilter.all)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: ActionChip(
                        avatar: const Icon(Icons.clear, size: 16),
                        label: Text("Showing: ${_typeFilter == TransactionTypeFilter.income ? 'Incomes Only' : 'Expenses Only'}"),
                        onPressed: () => setState(() => _typeFilter = TransactionTypeFilter.all),
                      ),
                    ),
                  Expanded(
                    child: filteredDocs.isEmpty
                        ? const Center(child: Text("No records found"))
                        : ListView.builder(
                      itemCount: filteredDocs.length,
                      itemBuilder: (context, index) {
                        final doc = filteredDocs[index];
                        final isSelected = _selectedIds.contains(doc.id);
                        return InkWell(
                          onLongPress: () => _toggleSelection(doc.id),
                          onTap: () => _isSelectionMode ? _toggleSelection(doc.id) : null,
                          child: Container(
                            color: isSelected ? Colors.green.withOpacity(0.1) : null,
                            child: _buildTransactionItem(doc, isSelected),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
              floatingActionButton: _isSelectionMode ? null : FloatingActionButton(
                backgroundColor: const Color(0xFF4A6D41),
                onPressed: _showAddDialog,
                child: const Icon(Icons.add, color: Colors.white),
              ),
            );
          },
        );
      },
    );
  }

  // --- UI HELPER WIDGETS ---

  Widget _buildHeader(String name) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
    child: Row(
      children: [
        CircleAvatar(backgroundColor: const Color(0xFF4A6D41), child: Text(name[0].toUpperCase(), style: const TextStyle(color: Colors.white))),
        const SizedBox(width: 12),
        Text("Namaste, $name!", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF4A6D41))),
      ],
    ),
  );

  Widget _buildProfitCard(double inVal, double outVal, double net) {
    bool isProfit = net >= 0;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]
      ),
      child: Column(
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            GestureDetector(
              onTap: () => setState(() => _typeFilter = TransactionTypeFilter.income),
              child: _cardSub("Income", inVal, Colors.green, _typeFilter == TransactionTypeFilter.income),
            ),
            GestureDetector(
              onTap: () => setState(() => _typeFilter = TransactionTypeFilter.expense),
              child: _cardSub("Expense", outVal, Colors.red, _typeFilter == TransactionTypeFilter.expense),
            ),
          ]),
          const Divider(height: 30),
          GestureDetector(
            onTap: () => setState(() => _typeFilter = TransactionTypeFilter.all),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(isProfit ? "IN PROFIT" : "IN LOSS", style: TextStyle(color: isProfit ? Colors.green : Colors.red, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
              Text("₹${net.abs().toStringAsFixed(2)}", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: isProfit ? Colors.green : Colors.red)),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _cardSub(String label, double val, Color col, bool isActive) => Container(
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(
      color: isActive ? col.withOpacity(0.1) : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      border: isActive ? Border.all(color: col) : null,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 10)),
        Text("₹${val.toStringAsFixed(0)}", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: col)),
      ],
    ),
  );

  Widget _buildFilterSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
      child: Row(
        children: [
          _filterBtn("Month", FilterType.month),
          _filterBtn("Year", FilterType.year),
          _filterBtn("Custom", FilterType.custom),
        ],
      ),
    );
  }

  Widget _filterBtn(String label, FilterType type) {
    bool isSelected = _activeFilter == type;
    return Expanded(
      child: InkWell(
        onTap: () async {
          setState(() => _activeFilter = type);
          if (type == FilterType.custom) {
            final range = await showDateRangePicker(context: context, firstDate: DateTime(2020), lastDate: DateTime.now());
            if (range != null) setState(() => _customRange = range);
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(color: isSelected ? const Color(0xFF4A6D41) : Colors.grey[200], borderRadius: BorderRadius.circular(10)),
          child: Text(label, textAlign: TextAlign.center, style: TextStyle(color: isSelected ? Colors.white : Colors.black, fontWeight: FontWeight.bold, fontSize: 13)),
        ),
      ),
    );
  }

  Widget _buildTransactionItem(DocumentSnapshot doc, bool selected) {
    bool isInc = doc['isIncome'];
    DateTime date = (doc['timestamp'] as Timestamp).toDate();
    String formattedDate = DateFormat('dd MMM yyyy, hh:mm a').format(date);

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: isInc ? Colors.green[50] : Colors.red[50],
        child: Icon(isInc ? Icons.arrow_downward : Icons.arrow_upward, color: isInc ? Colors.green : Colors.red, size: 20),
      ),
      title: Text(
          doc['category'].toString().toUpperCase(),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF4A6D41))
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(doc['title'], style: const TextStyle(color: Colors.black87, fontSize: 14)),
          Text(formattedDate, style: const TextStyle(color: Colors.grey, fontSize: 11)),
        ],
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text("₹${doc['amount']}", style: TextStyle(color: isInc ? Colors.green : Colors.red, fontWeight: FontWeight.bold, fontSize: 16)),
          if (selected) const Icon(Icons.check_circle, color: Colors.blue, size: 16),
        ],
      ),
    );
  }

  Future<void> _deleteSelected() async {
    final batch = _firestore.batch();
    for (var id in _selectedIds) {
      batch.delete(_firestore.collection('users').doc(_user?.email).collection('transactions').doc(id));
    }
    await batch.commit();
    setState(() { _selectedIds.clear(); _isSelectionMode = false; });
  }

  void _showAddDialog() {
    bool incomeMode = false;
    String? cat;
    DateTime selectedDate = DateTime.now();
    _amountController.clear(); _titleController.clear(); _otherCategoryController.clear();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Container(
          decoration: BoxDecoration(
            color: incomeMode ? Colors.green[50] : Colors.red[50],
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom + 20, left: 20, right: 20, top: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(incomeMode ? "Add New Income" : "Add New Expense",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: incomeMode ? Colors.green[900] : Colors.red[900])),
              const SizedBox(height: 15),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                ChoiceChip(
                    label: const Text("Expense"),
                    selected: !incomeMode,
                    selectedColor: Colors.red[200],
                    onSelected: (s) => setModalState(() { incomeMode = false; cat = null; })
                ),
                const SizedBox(width: 20),
                ChoiceChip(
                    label: const Text("Income"),
                    selected: incomeMode,
                    selectedColor: Colors.green[200],
                    onSelected: (s) => setModalState(() { incomeMode = true; cat = null; })
                ),
              ]),
              const SizedBox(height: 15),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now()
                  );
                  if (picked != null) setModalState(() => selectedDate = picked);
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(5)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Date: ${DateFormat('dd/MM/yyyy').format(selectedDate)}"),
                      const Icon(Icons.calendar_today, size: 18),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(controller: _amountController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Amount (₹)", border: OutlineInputBorder(), fillColor: Colors.white, filled: true)),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: cat,
                hint: const Text("Select Category"),
                decoration: const InputDecoration(border: OutlineInputBorder(), fillColor: Colors.white, filled: true),
                items: (incomeMode ? _incomeCategories : _expenseCategories).map((c) => DropdownMenuItem(value: c, child: Text(c.toUpperCase()))).toList(),
                onChanged: (v) => setModalState(() => cat = v),
              ),
              if (cat == 'other') ...[
                const SizedBox(height: 12),
                TextField(
                    controller: _otherCategoryController,
                    decoration: const InputDecoration(labelText: "Type Category Name", hintText: "e.g. Dairy, Poultry, etc.", border: OutlineInputBorder(), fillColor: Colors.white, filled: true)
                ),
              ],
              const SizedBox(height: 12),
              TextField(controller: _titleController, decoration: const InputDecoration(labelText: "Description", border: OutlineInputBorder(), fillColor: Colors.white, filled: true)),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () async {
                  if (_amountController.text.isEmpty || cat == null) return;

                  String finalCategory = (cat == 'other' && _otherCategoryController.text.isNotEmpty)
                      ? _otherCategoryController.text.trim()
                      : cat!;

                  await _firestore.collection('users').doc(_user?.email).collection('transactions').add({
                    'title': _titleController.text.trim(),
                    'amount': double.parse(_amountController.text),
                    'category': finalCategory,
                    'isIncome': incomeMode,
                    'timestamp': Timestamp.fromDate(selectedDate),
                  });
                  Navigator.pop(ctx);
                },
                style: ElevatedButton.styleFrom(
                    backgroundColor: incomeMode ? Colors.green[700] : Colors.red[700],
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
                ),
                child: const Text("SAVE RECORD", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}