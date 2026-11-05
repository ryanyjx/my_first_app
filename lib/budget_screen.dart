import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'month_year_picker.dart';
import 'add_transaction_screen.dart';

class BudgetScreen extends StatefulWidget {
  final List<Map<String, dynamic>> transactions;

  const BudgetScreen({
    super.key,
    required this.transactions,
  });

  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen> {
  final List<String> categories = [
    'Food',
    'Transport',
    'Shopping',
    'Bills',
    'Other',
  ];

  final Map<String, double> budgets = {
    'Food': 0,
    'Transport': 0,
    'Shopping': 0,
    'Bills': 0,
    'Other': 0,
  };

  DateTime selectedMonth = DateTime.now();

  double getSpentForCategory(String category) {
    return widget.transactions.where((transaction) {
      if (transaction['type'] != 'Expense') return false;
      if (transaction['category'] != category) return false;
      if (transaction['date'] == null) return false;

      final date = DateTime.parse(transaction['date']);

      return date.year == selectedMonth.year &&
          date.month == selectedMonth.month;
    }).fold(
      0.0,
      (sum, transaction) => sum + (transaction['amount'] as num).toDouble(),
    );
  }

  @override
  void initState() {
    super.initState();
    loadBudgets();
  }

  Future<void> loadBudgets() async {
    final prefs = await SharedPreferences.getInstance();

    setState(() {
      for (var category in categories) {
        budgets[category] = prefs.getDouble('budget_$category') ?? 0.0;
      }
    });
  }

  Future<void> saveBudget(String category, double amount) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setDouble('budget_$category', amount);
  }

  Future<void> selectMonth() async {
    final picked = await showMonthYearPicker(
      context: context,
      initialDate: selectedMonth,
    );

    if (picked != null) {
      setState(() {
        selectedMonth = picked;
      });
    }
  }

  Future<void> editBudget(String category) async {
    final result = await showDialog<double>(
      context: context,
      builder: (dialogContext) {
        final controller = TextEditingController(
          text: (budgets[category] ?? 0).toString(),
        );

        return AlertDialog(
          scrollable: true,
          title: Text('Set $category Budget'),
          content: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(
              decimal: true,
            ),
            inputFormatters: [
              MoneyInputFormatter(),
            ],
            decoration: const InputDecoration(
              labelText: 'Budget Amount (RM)',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                final amount = double.tryParse(controller.text);

                if (amount != null && amount >= 0) {
                  Navigator.pop(dialogContext, amount);
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (!mounted) return;

    if (result != null) {
      setState(() {
        budgets[category] = result;
      });

      await saveBudget(category, result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Budgets'),
        backgroundColor: const Color(0xFF1E293B),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Monthly Budgets',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton.icon(
                  onPressed: selectMonth,
                  icon: const Icon(Icons.calendar_month),
                  label: Text(
                    '${selectedMonth.month}/${selectedMonth.year}',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView.builder(
                itemCount: categories.length,
                itemBuilder: (context, index) {
                  final category = categories[index];
                  final spent = getSpentForCategory(category);
                  final budget = budgets[category] ?? 0;
                  final progress =
                      budget > 0 ? (spent / budget).clamp(0.0, 1.0) : 0.0;
                  final isOverBudget = budget > 0 && spent > budget;
                  final isNearBudget =
                      budget > 0 && spent >= budget * 0.8 && spent <= budget;

                  return Card(
                    color: const Color(0xFF1E293B),
                    margin: const EdgeInsets.only(bottom: 15),
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                category,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              IconButton(
                                onPressed: () {
                                  editBudget(category);
                                },
                                icon: const Icon(
                                  Icons.edit,
                                  color: Colors.blueAccent,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Spent: RM ${spent.toStringAsFixed(2)}',
                          ),
                          Text(
                            'Budget: RM ${budget.toStringAsFixed(2)}',
                          ),
                          const SizedBox(height: 12),
                          LinearProgressIndicator(
                            value: progress,
                            minHeight: 8,
                            backgroundColor: Colors.grey.shade700,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              isOverBudget
                                  ? Colors.redAccent
                                  : isNearBudget
                                      ? Colors.orangeAccent
                                      : Colors.blueAccent,
                            ),
                          ),
                        ],
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
