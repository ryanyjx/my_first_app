import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'currency_service.dart';
import 'month_year_picker.dart';

class HistoryScreen extends StatefulWidget {
  final List<Map<String, dynamic>> transactions;
  final Future<void> Function(Map<String, dynamic>) onEdit;
  final Future<void> Function(Map<String, dynamic>) onDelete;

  const HistoryScreen({
    super.key,
    required this.transactions,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  String get userId => FirebaseAuth.instance.currentUser!.uid;

  String baseCurrency = 'MYR';
  String displayCurrency = 'MYR';

  Map<String, double> exchangeRates = {
    'MYR': 1.0,
  };
  DateTime? selectedMonth;
  String selectedType = 'All';
  String selectedCategory = 'All';
  String searchText = '';

  final List<String> categories = [
    'Food',
    'Transport',
    'Shopping',
    'Bills',
    'Salary',
    'Business',
    'Gift',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    loadCurrencySettings();
  }

  Future<void> loadCurrencySettings() async {
    final prefs = await SharedPreferences.getInstance();

    final savedBaseCurrency = prefs.getString('baseCurrency_$userId') ?? 'MYR';

    final savedDisplayCurrency =
        prefs.getString('currency_$userId') ?? savedBaseCurrency;

    try {
      final rates = await CurrencyService.getRates(savedBaseCurrency);

      if (!mounted) return;

      setState(() {
        baseCurrency = savedBaseCurrency;
        displayCurrency = savedDisplayCurrency;
        exchangeRates = rates;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        baseCurrency = savedBaseCurrency;
        displayCurrency = savedBaseCurrency;
        exchangeRates = {savedBaseCurrency: 1.0};
      });
    }
  }

  double convertAmount(double amount) {
    final rate = exchangeRates[displayCurrency];

    if (rate == null) {
      return amount;
    }

    return amount * rate;
  }

  String formatDisplayAmount(double amount) {
    return CurrencyService.formatAmount(
      convertAmount(amount),
      displayCurrency,
    );
  }

  List<Map<String, dynamic>> get filteredTransactions {
    final results = widget.transactions.where((transaction) {
      final date = DateTime.tryParse(
        transaction['date']?.toString() ?? '',
      );

      if (selectedMonth != null) {
        if (date == null ||
            date.year != selectedMonth!.year ||
            date.month != selectedMonth!.month) {
          return false;
        }
      }

      if (selectedType != 'All' && transaction['type'] != selectedType) {
        return false;
      }

      if (selectedCategory != 'All' &&
          transaction['category'] != selectedCategory) {
        return false;
      }

      final description =
          transaction['description']?.toString().toLowerCase() ?? '';

      if (!description.contains(searchText.toLowerCase())) {
        return false;
      }

      return true;
    }).toList();

    results.sort((a, b) {
      final dateA = DateTime.tryParse(a['date']?.toString() ?? '');
      final dateB = DateTime.tryParse(b['date']?.toString() ?? '');

      if (dateA == null) return 1;
      if (dateB == null) return -1;

      return dateB.compareTo(dateA);
    });

    return results;
  }

  Future<void> chooseMonth() async {
    final picked = await showMonthYearPicker(
      context: context,
      initialDate: selectedMonth ?? DateTime.now(),
    );

    if (picked != null) {
      setState(() {
        selectedMonth = picked;
      });
    }
  }

  Future<void> deleteTransaction(
    Map<String, dynamic> transaction,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Transaction?'),
        content: const Text(
          'Are you sure you want to delete this transaction?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await widget.onDelete(transaction);

      if (mounted) {
        setState(() {});
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayedTransactions = filteredTransactions;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaction History'),
        backgroundColor: const Color(0xFF1E293B),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search...',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(vertical: 12),
                    ),
                    onChanged: (value) => setState(() => searchText = value),
                  ),
                ),
                SizedBox(width: 10),
                OutlinedButton.icon(
                  onPressed: chooseMonth,
                  icon: const Icon(Icons.calendar_month, size: 18),
                  label: Text(
                    selectedMonth == null
                        ? 'All Months'
                        : DateFormat('MMM yyyy').format(selectedMonth!),
                  ),
                ),
                if (selectedMonth != null)
                  IconButton(
                    onPressed: () {
                      setState(() {
                        selectedMonth = null;
                      });
                    },
                    icon: const Icon(Icons.clear),
                    tooltip: 'Show all months',
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: selectedType,
                    decoration: const InputDecoration(
                      labelText: 'Type',
                      border: OutlineInputBorder(),
                    ),
                    items: ['All', 'Income', 'Expense']
                        .map((type) => DropdownMenuItem(
                              value: type,
                              child: Text(type),
                            ))
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedType = value!;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: selectedCategory,
                    decoration: const InputDecoration(
                      labelText: 'Category',
                      border: OutlineInputBorder(),
                    ),
                    items: ['All', ...categories]
                        .toSet()
                        .map((category) => DropdownMenuItem(
                              value: category,
                              child: Text(category),
                            ))
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedCategory = value!;
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 15),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${displayedTransactions.length} transaction(s)',
                style: const TextStyle(color: Colors.white60),
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: displayedTransactions.isEmpty
                  ? const Center(
                      child: Text(
                        'No transactions found.',
                        style: TextStyle(color: Colors.white60),
                      ),
                    )
                  : ListView.builder(
                      itemCount: displayedTransactions.length,
                      itemBuilder: (context, index) {
                        final transaction = displayedTransactions[index];

                        final isExpense = transaction['type'] == 'Expense';

                        final amount =
                            (transaction['amount'] as num).toDouble();

                        final date = DateTime.tryParse(
                          transaction['date']?.toString() ?? '',
                        );

                        return Dismissible(
                          key: ValueKey(
                            transaction['id'] ?? transaction.hashCode,
                          ),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.only(right: 20),
                            alignment: Alignment.centerRight,
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: const Icon(
                              Icons.delete,
                              color: Colors.white,
                            ),
                          ),
                          confirmDismiss: (_) async {
                            final confirmed = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Delete Transaction?'),
                                content: const Text(
                                  'Are you sure you want to delete this transaction?',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, false),
                                    child: const Text('Cancel'),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, true),
                                    child: const Text(
                                      'Delete',
                                      style: TextStyle(color: Colors.red),
                                    ),
                                  ),
                                ],
                              ),
                            );

                            return confirmed ?? false;
                          },
                          onDismissed: (_) async {
                            await widget.onDelete(transaction);

                            if (mounted) {
                              setState(() {});
                            }
                          },
                          child: Card(
                            color: const Color(0xFF1E293B),
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: const Color(0xFF121826),
                                child: Icon(
                                  Icons.receipt_long,
                                  color: const Color(0xFF3D7BFF),
                                ),
                              ),
                              title: Text(
                                transaction['description'] ?? '',
                              ),
                              subtitle: Text(
                                '${transaction['category']} • '
                                '${date != null ? DateFormat('dd MMM yyyy').format(date) : 'No date'}',
                              ),
                              trailing: Text(
                                '${isExpense ? '- ' : '+ '}${formatDisplayAmount(amount)}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isExpense
                                      ? Colors.redAccent
                                      : Colors.greenAccent,
                                ),
                              ),
                              onTap: () async {
                                await widget.onEdit(transaction);

                                if (mounted) {
                                  setState(() {});
                                }
                              },
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
