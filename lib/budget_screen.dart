import 'month_year_picker.dart';
import 'add_transaction_screen.dart';
import 'currency_service.dart';
import 'notification_service.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BudgetScreen extends StatefulWidget {
  static Future<void> checkBudgetNotifications({
    required List<Map<String, dynamic>> transactions,
    required String userId,
  }) async {
    final categories = [
      'Food',
      'Transport',
      'Shopping',
      'Bills',
      'Other',
    ];

    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final monthKey = '${now.year}_${now.month}';

    for (int i = 0; i < categories.length; i++) {
      final category = categories[i];

      final budget = prefs.getDouble('budget_${userId}_$category') ?? 0.0;

      if (budget <= 0) continue;

      final spent = transactions.where((transaction) {
        if (transaction['type'] != 'Expense') return false;
        if (transaction['category'] != category) return false;
        if (transaction['date'] == null) return false;

        final date = DateTime.parse(transaction['date']);

        return date.year == now.year && date.month == now.month;
      }).fold<double>(
        0.0,
        (sum, transaction) => sum + (transaction['amount'] as num).toDouble(),
      );

      if (spent >= budget * 0.8) {
        final key = 'budget_warning_${userId}_${category}_$monthKey';

        if (!(prefs.getBool(key) ?? false)) {
          await NotificationService.showBudgetNotification(
            id: i * 2,
            title: '$category Budget Warning',
            body: 'You have used 80% of your $category budget.',
          );

          await prefs.setBool(key, true);
        }
      }

      if (spent > budget) {
        final key = 'budget_exceeded_${userId}_${category}_$monthKey';

        if (!(prefs.getBool(key) ?? false)) {
          await NotificationService.showBudgetNotification(
            id: i * 2 + 1,
            title: '$category Budget Exceeded!',
            body: 'You have exceeded your $category budget.',
          );

          await prefs.setBool(key, true);
        }
      }
    }
  }

  final List<Map<String, dynamic>> transactions;

  const BudgetScreen({
    super.key,
    required this.transactions,
  });

  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen> {
  String get userId => FirebaseAuth.instance.currentUser!.uid;
  String baseCurrency = 'MYR';
  String displayCurrency = 'MYR';

  Map<String, double> exchangeRates = {
    'MYR': 1.0,
  };
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
        displayCurrency = savedDisplayCurrency;
        exchangeRates = {savedBaseCurrency: 1.0};
      });

      debugPrint('Currency loading error: $e');
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

  Future<void> loadBudgets() async {
    final prefs = await SharedPreferences.getInstance();

    final alreadyMigrated = prefs.getBool('legacyBudgetsMigrated') ?? false;

    if (!alreadyMigrated) {
      for (var category in categories) {
        final oldBudget = prefs.getDouble('budget_$category');

        if (oldBudget != null) {
          await prefs.setDouble(
            'budget_${userId}_$category',
            oldBudget,
          );
          await prefs.remove('budget_$category');
        }
      }

      await prefs.setBool('legacyBudgetsMigrated', true);
    }

    if (!mounted) return;

    setState(() {
      for (var category in categories) {
        budgets[category] =
            prefs.getDouble('budget_${userId}_$category') ?? 0.0;
      }
    });

    await checkBudgetNotifications();
  }

  Future<void> saveBudget(String category, double amount) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setDouble(
      'budget_${userId}_$category',
      amount,
    );
  }

  Future<void> checkBudgetNotifications() async {
    final now = DateTime.now();

    // Only send notifications for the current month.
    if (selectedMonth.year != now.year || selectedMonth.month != now.month) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();

    for (int i = 0; i < categories.length; i++) {
      final category = categories[i];
      final budget = budgets[category] ?? 0;
      final spent = getSpentForCategory(category);

      if (budget <= 0) continue;

      final monthKey = '${now.year}_${now.month}';

      // Check whether spending has reached 80%.
      if (spent >= budget * 0.8) {
        final warningKey = 'budget_warning_${userId}_${category}_$monthKey';

        final alreadyNotified = prefs.getBool(warningKey) ?? false;

        if (!alreadyNotified) {
          await NotificationService.showBudgetNotification(
            id: i * 2,
            title: '$category Budget Warning',
            body: 'You have used 80% of your $category budget.',
          );

          await prefs.setBool(warningKey, true);
        }
      }

      // Check whether spending has exceeded the budget.
      if (spent > budget) {
        final exceededKey = 'budget_exceeded_${userId}_${category}_$monthKey';

        final alreadyNotified = prefs.getBool(exceededKey) ?? false;

        if (!alreadyNotified) {
          await NotificationService.showBudgetNotification(
            id: i * 2 + 1,
            title: '$category Budget Exceeded!',
            body: 'You have exceeded your $category budget.',
          );

          await prefs.setBool(exceededKey, true);
        }
      }
    }
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
          text: convertAmount(budgets[category] ?? 0).toStringAsFixed(2),
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
            decoration: InputDecoration(
              labelText: 'Budget Amount',
              prefixText:
                  '${CurrencyService.getCurrencySymbol(displayCurrency)} ',
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
      await checkBudgetNotifications();
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
                            'Spent: ${formatDisplayAmount(spent)}',
                          ),
                          Text(
                            'Budget: ${formatDisplayAmount(budget)}',
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
