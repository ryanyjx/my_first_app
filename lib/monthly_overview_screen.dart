import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'month_year_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'currency_service.dart';

class MonthlyOverviewScreen extends StatefulWidget {
  final List<Map<String, dynamic>> transactions;

  const MonthlyOverviewScreen({
    super.key,
    required this.transactions,
  });

  @override
  State<MonthlyOverviewScreen> createState() => _MonthlyOverviewScreenState();
}

class _MonthlyOverviewScreenState extends State<MonthlyOverviewScreen> {
  String get userId => FirebaseAuth.instance.currentUser!.uid;

  String baseCurrency = 'MYR';
  String displayCurrency = 'MYR';

  Map<String, double> exchangeRates = {
    'MYR': 1.0,
  };
  DateTime selectedMonth = DateTime.now();

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
    return widget.transactions.where((transaction) {
      if (transaction['date'] == null) return false;

      final date = DateTime.parse(transaction['date']);

      return date.year == selectedMonth.year &&
          date.month == selectedMonth.month;
    }).toList();
  }

  double get monthlyIncome {
    return filteredTransactions
        .where((t) => t['type'] == 'Income')
        .fold(0.0, (sum, t) => sum + (t['amount'] as num).toDouble());
  }

  double get monthlyExpenses {
    return filteredTransactions
        .where((t) => t['type'] == 'Expense')
        .fold(0.0, (sum, t) => sum + (t['amount'] as num).toDouble());
  }

  Map<String, double> get expenseBreakdown {
    final Map<String, double> breakdown = {};

    for (var transaction in filteredTransactions) {
      if (transaction['type'] == 'Expense') {
        final category = transaction['category'] ?? 'Other';
        final amount = (transaction['amount'] as num).toDouble();

        breakdown[category] = (breakdown[category] ?? 0) + amount;
      }
    }

    return breakdown;
  }

  @override
  Widget build(BuildContext context) {
    final total = monthlyIncome + monthlyExpenses;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Monthly Overview'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Month selector
            Center(
              child: TextButton.icon(
                onPressed: () async {
                  final picked = await showMonthYearPicker(
                    context: context,
                    initialDate: selectedMonth,
                  );

                  if (picked != null) {
                    setState(() {
                      selectedMonth = picked;
                    });
                  }
                },
                icon: const Icon(Icons.calendar_month),
                label: Text(
                  DateFormat('MMMM yyyy').format(selectedMonth),
                  style: const TextStyle(fontSize: 18),
                ),
              ),
            ),

            const SizedBox(height: 30),

            const Text(
              'Income vs Expenses',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 20),

            // Pie chart
            if (total > 0)
              SizedBox(
                height: 250,
                child: PieChart(
                  PieChartData(
                    sections: [
                      if (monthlyIncome > 0)
                        PieChartSectionData(
                          value: monthlyIncome,
                          color: Colors.green,
                          title:
                              '${(monthlyIncome / total * 100).toStringAsFixed(1)}%',
                          radius: 100,
                          titleStyle: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      if (monthlyExpenses > 0)
                        PieChartSectionData(
                          value: monthlyExpenses,
                          color: Colors.redAccent,
                          title:
                              '${(monthlyExpenses / total * 100).toStringAsFixed(1)}%',
                          radius: 100,
                          titleStyle: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                    ],
                  ),
                ),
              )
            else
              const SizedBox(
                height: 250,
                child: Center(
                  child: Text('No transactions for this month'),
                ),
              ),

            const SizedBox(height: 25),

            // Income
            _buildSummaryRow(
              'Income',
              monthlyIncome,
              Colors.green,
            ),

            const SizedBox(height: 15),

            // Expenses
            _buildSummaryRow(
              'Expenses',
              monthlyExpenses,
              Colors.redAccent,
            ),

            const Divider(height: 35),

            // Remaining balance
            _buildSummaryRow(
              'Remaining Balance',
              monthlyIncome - monthlyExpenses,
              Colors.blueAccent,
            ),

            const SizedBox(height: 35),

            const Text(
              'Expense Breakdown',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 20),

            if (expenseBreakdown.isEmpty)
              const Center(
                child: Text('No expenses for this month'),
              )
            else
              ...expenseBreakdown.entries.map((entry) {
                final percentage = monthlyExpenses > 0
                    ? (entry.value / monthlyExpenses) * 100
                    : 0.0;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            entry.key,
                            style: const TextStyle(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            formatDisplayAmount(entry.value),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value: percentage / 100,
                          minHeight: 9,
                          backgroundColor: Colors.grey.shade300,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Colors.blueAccent,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${percentage.toStringAsFixed(1)}%',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(
    String title,
    double amount,
    Color color,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 6,
              backgroundColor: color,
            ),
            const SizedBox(width: 10),
            Text(title),
          ],
        ),
        Text(
          formatDisplayAmount(amount),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ],
    );
  }
}
