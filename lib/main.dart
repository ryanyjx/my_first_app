// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'add_transaction_screen.dart';
import 'package:intl/intl.dart';
import 'monthly_overview_screen.dart';
import 'budget_screen.dart';
import 'month_year_picker.dart';
import 'history_screen.dart';

const Color backgroundColor = Color(0xFF121826);
const Color cardColor = Color(0xFF1E293B);
const Color blue = Color(0xFF3D7BFF);

void main() {
  runApp(const BudgetBuddyApp());
}

class BudgetBuddyApp extends StatelessWidget {
  const BudgetBuddyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'BudgetBuddy',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: backgroundColor,
        primaryColor: blue,
        colorScheme: ColorScheme.fromSeed(
          seedColor: blue,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Map<String, dynamic>> transactions = [];

  DateTime selectedMonth = DateTime.now();

  List<Map<String, dynamic>> get filteredTransactions {
    return transactions.where((transaction) {
      if (transaction['date'] == null) return false;

      final date = DateTime.parse(transaction['date']);

      return date.year == selectedMonth.year &&
          date.month == selectedMonth.month;
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    loadTransactions();
    loadStartingValues();
  }

  Future<void> loadTransactions() async {
    final prefs = await SharedPreferences.getInstance();

    final savedTransactions = prefs.getStringList('transactions');

    if (savedTransactions != null) {
      setState(() {
        transactions = savedTransactions
            .map((item) => Map<String, dynamic>.from(jsonDecode(item)))
            .toList();
      });
    }
  }

  Future<void> loadStartingValues() async {
    final prefs = await SharedPreferences.getInstance();

    setState(() {
      startingBalance = prefs.getDouble('startingBalance') ?? 0.00;
      startingIncome = prefs.getDouble('startingIncome') ?? 0.00;
      startingExpenses = prefs.getDouble('startingExpenses') ?? 0.00;
    });
  }

  Future<void> saveTransactions() async {
    final prefs = await SharedPreferences.getInstance();

    final savedTransactions =
        transactions.map((transaction) => jsonEncode(transaction)).toList();

    await prefs.setStringList('transactions', savedTransactions);

    await saveStartingValues();
  }

  double startingBalance = 0.00;
  double startingIncome = 0.00;
  double startingExpenses = 0.00;
  Future<void> saveStartingValues() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setDouble('startingBalance', startingBalance);
    await prefs.setDouble('startingIncome', startingIncome);
    await prefs.setDouble('startingExpenses', startingExpenses);
  }

  double get totalIncome {
    return transactions
        .where((t) => t['type'] == 'Income')
        .fold(0.0, (sum, t) => sum + (t['amount'] as num).toDouble());
  }

  double get totalExpenses {
    return transactions
        .where((t) => t['type'] == 'Expense')
        .fold(0.0, (sum, t) => sum + (t['amount'] as num).toDouble());
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

  double get totalBalance {
    return totalIncome - totalExpenses;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hello there 👋',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                      SizedBox(height: 5),
                      Text(
                        'BudgetBuddy',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  CircleAvatar(
                    backgroundColor: cardColor,
                    child: Icon(Icons.person, color: blue),
                  ),
                ],
              ),

              const SizedBox(height: 30),

              // Total Balance
              InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => MonthlyOverviewScreen(
                        transactions: transactions,
                      ),
                    ),
                  );
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF3D7BFF), Color(0xFF2455C3)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Total Balance',
                        style: TextStyle(color: Colors.white70),
                      ),
                      SizedBox(height: 12),
                      Text(
                        'RM ${totalBalance.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Your current balance',
                        style: TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            'View Monthly Overview',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 5),
                          const Icon(
                            Icons.arrow_forward_ios,
                            color: Colors.white,
                            size: 12,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 25),

              // Income and Expenses
              Row(
                children: [
                  Expanded(
                    child: SummaryCard(
                      title: 'Income',
                      amount: 'RM ${monthlyIncome.toStringAsFixed(2)}',
                      icon: Icons.arrow_downward,
                      iconColor: Colors.greenAccent,
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: SummaryCard(
                      title: 'Expenses',
                      amount: 'RM ${monthlyExpenses.toStringAsFixed(2)}',
                      icon: Icons.arrow_upward,
                      iconColor: Colors.redAccent,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Recent Transactions
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Recent Transactions',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextButton(
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
                    child: Text(
                      DateFormat('MMMM yyyy').format(selectedMonth),
                      style: const TextStyle(color: Colors.blueAccent),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 15),

              if (filteredTransactions.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: Text(
                      'No new transactions yet.',
                      style: TextStyle(color: Colors.white60),
                    ),
                  ),
                )
              else
                ...filteredTransactions.reversed.map<Widget>((transaction) {
                  final isExpense = transaction['type'] == 'Expense';
                  final amount = transaction['amount'] as double;

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
                    confirmDismiss: (direction) async {
                      return await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Delete Transaction?'),
                          content: const Text(
                            'Are you sure you want to delete this transaction?',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () {
                                Navigator.pop(context, false);
                              },
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.pop(context, true);
                              },
                              child: const Text(
                                'Delete',
                                style: TextStyle(color: Colors.red),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                    onDismissed: (direction) async {
                      setState(() {
                        transactions.remove(transaction);
                      });

                      await saveTransactions();
                    },
                    child: GestureDetector(
                      onTap: () async {
                        final result =
                            await Navigator.push<Map<String, dynamic>>(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AddTransactionScreen(
                              transaction: transaction,
                            ),
                          ),
                        );

                        if (result != null) {
                          setState(() {
                            final index = transactions.indexOf(transaction);
                            if (index != -1) {
                              transactions[index] = result;
                            }
                          });

                          await saveTransactions();
                        }
                      },
                      child: TransactionTile(
                        title: transaction['description'] as String,
                        category: transaction['category'] as String,
                        amount:
                            '${isExpense ? '- ' : '+ '}RM ${amount.toStringAsFixed(2)}',
                        date: transaction['date'] ?? '',
                        icon: Icons.receipt_long,
                        isExpense: isExpense,
                      ),
                    ),
                  );
                }).toList(),
            ],
          ),
        ),
      ),

      // Floating Add Button
      floatingActionButton: FloatingActionButton(
        backgroundColor: blue,
        foregroundColor: Colors.white,
        onPressed: () async {
          final result = await Navigator.push<Map<String, dynamic>>(
            context,
            MaterialPageRoute(
              builder: (context) => const AddTransactionScreen(),
            ),
          );

          if (result != null) {
            setState(() {
              transactions.add(result);
            });

            await saveTransactions();
          }
        },
        child: const Icon(Icons.add, size: 30),
      ),

      // Bottom Navigation
      bottomNavigationBar: NavigationBar(
        backgroundColor: cardColor,
        onDestinationSelected: (index) {
          if (index == 1) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => BudgetScreen(
                  transactions: transactions,
                ),
              ),
            );
          } else if (index == 2) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => HistoryScreen(
                  transactions: transactions,
                  onEdit: (transaction) async {
                    final result = await Navigator.push<Map<String, dynamic>>(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AddTransactionScreen(
                          transaction: transaction,
                        ),
                      ),
                    );

                    if (result != null) {
                      setState(() {
                        final transactionIndex =
                            transactions.indexOf(transaction);

                        if (transactionIndex != -1) {
                          transactions[transactionIndex] = result;
                        }
                      });

                      await saveTransactions();
                    }
                  },
                  onDelete: (transaction) async {
                    setState(() {
                      transactions.remove(transaction);
                    });

                    await saveTransactions();
                  },
                ),
              ),
            );
          }
        },
        indicatorColor: blue.withOpacity(0.25),
        selectedIndex: 0,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(Icons.account_balance_wallet),
            label: 'Budgets',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'History',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

// Summary Card
class SummaryCard extends StatelessWidget {
  final String title;
  final String amount;
  final IconData icon;
  final Color iconColor;

  const SummaryCard({
    super.key,
    required this.title,
    required this.amount,
    required this.icon,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 25),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              amount,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Transaction Tile
class TransactionTile extends StatelessWidget {
  final String title;
  final String category;
  final String amount;
  final String date;
  final IconData icon;
  final bool isExpense;

  const TransactionTile({
    super.key,
    required this.title,
    required this.category,
    required this.amount,
    required this.date,
    required this.icon,
    required this.isExpense,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: backgroundColor,
            child: Icon(icon, color: blue),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  date.isNotEmpty
                      ? DateFormat('dd MMM yyyy').format(DateTime.parse(date))
                      : 'No date',
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  category,
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  category,
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Text(
            amount,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isExpense ? Colors.redAccent : Colors.greenAccent,
            ),
          ),
        ],
      ),
    );
  }
}
