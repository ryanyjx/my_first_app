import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

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
  DateTime selectedMonth = DateTime.now();

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
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: selectedMonth,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2035),
                    initialDatePickerMode: DatePickerMode.year,
                  );

                  if (picked != null) {
                    setState(() {
                      selectedMonth = DateTime(
                        picked.year,
                        picked.month,
                      );
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
                            'RM ${entry.value.toStringAsFixed(2)}',
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
          'RM ${amount.toStringAsFixed(2)}',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ],
    );
  }
}
