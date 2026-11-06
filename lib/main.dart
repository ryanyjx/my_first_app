// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'add_transaction_screen.dart';
import 'package:intl/intl.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'login_screen.dart';
import 'monthly_overview_screen.dart';
import 'budget_screen.dart';
import 'month_year_picker.dart';
import 'history_screen.dart';
import 'profile_screen.dart';
import 'currency_service.dart';
import 'notification_service.dart';

const Color backgroundColor = Color(0xFF121826);
const Color cardColor = Color(0xFF1E293B);
const Color blue = Color(0xFF3D7BFF);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await NotificationService.initialize();

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
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.userChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasData &&
            snapshot.data!.emailVerified &&
            !registrationPending) {
          return const HomeScreen();
        }

        return const LoginScreen();
      },
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int selectedIndex = 0;

  List<Map<String, dynamic>> transactions = [];

  String get userId => FirebaseAuth.instance.currentUser!.uid;

  String get transactionsKey => 'transactions_$userId';

  DateTime selectedMonth = DateTime.now();

  double startingBalance = 0.00;
  double startingIncome = 0.00;
  double startingExpenses = 0.00;
  double fixedMonthlyIncome = 0.00;
  double fixedMonthlyExpenses = 0.00;
  String baseCurrency = 'MYR';
  String displayCurrency = 'MYR';

  Map<String, double> exchangeRates = {
    'MYR': 1.0,
  };

  bool isCurrencyLoading = true;

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

    initializeMonthlyTransactions();
    loadCurrencySettings();
  }

  Future<void> initializeMonthlyTransactions() async {
    await loadTransactions();
    await loadStartingValues();
    await loadFixedMonthlyValues();
    await generateMonthlyTransactions();
  }

  Future<void> generateMonthlyTransactions() async {
    final prefs = await SharedPreferences.getInstance();

    final now = DateTime.now();
    final currentMonth = DateFormat('yyyy-MM').format(now);

    final generatedKey = 'fixedTransactionsGeneratedV2_$userId';

    final lastGeneratedMonth = prefs.getString(generatedKey);

    // Wait until both fixed amounts have been configured.
    if (fixedMonthlyIncome <= 0 || fixedMonthlyExpenses <= 0) {
      return;
    }

    // Prevent duplicate transactions in the same month.
    if (lastGeneratedMonth == currentMonth) {
      return;
    }

    final transactionDate = DateTime(now.year, now.month, 1);

    final newTransactions = <Map<String, dynamic>>[];

    if (fixedMonthlyIncome > 0) {
      newTransactions.add({
        'id': 'fixed_income_$currentMonth',
        'description': 'Fixed Monthly Income',
        'amount': fixedMonthlyIncome,
        'type': 'Income',
        'category': 'Salary',
        'date': transactionDate.toIso8601String(),
      });
    }

    if (fixedMonthlyExpenses > 0) {
      newTransactions.add({
        'id': 'fixed_expenses_$currentMonth',
        'description': 'Fixed Monthly Expenses',
        'amount': fixedMonthlyExpenses,
        'type': 'Expense',
        'category': 'Bills',
        'date': transactionDate.toIso8601String(),
      });
    }

    setState(() {
      transactions.addAll(newTransactions);
    });

    await saveTransactions();

    await prefs.setString(generatedKey, currentMonth);
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
        isCurrencyLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        baseCurrency = savedBaseCurrency;
        displayCurrency = savedDisplayCurrency;
        exchangeRates = {savedBaseCurrency: 1.0};
        isCurrencyLoading = false;
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

  Future<void> loadTransactions() async {
    final prefs = await SharedPreferences.getInstance();

    final savedTransactions = prefs.getStringList(transactionsKey);

    if (savedTransactions != null) {
      setState(() {
        transactions = savedTransactions
            .map((item) => Map<String, dynamic>.from(jsonDecode(item)))
            .toList();
      });
      return;
    }

    final alreadyMigrated =
        prefs.getBool('legacyTransactionsMigrated') ?? false;

    if (!alreadyMigrated) {
      final oldTransactions = prefs.getStringList('transactions');

      if (oldTransactions != null) {
        await prefs.setStringList(transactionsKey, oldTransactions);

        setState(() {
          transactions = oldTransactions
              .map((item) => Map<String, dynamic>.from(jsonDecode(item)))
              .toList();
        });
      }

      await prefs.setBool('legacyTransactionsMigrated', true);
      await prefs.remove('transactions');
    }
  }

  Future<void> loadStartingValues() async {
    final prefs = await SharedPreferences.getInstance();

    final balanceKey = 'startingBalance_$userId';
    final incomeKey = 'startingIncome_$userId';
    final expensesKey = 'startingExpenses_$userId';

    // Migrate the old shared values to the current account.
    if (!(prefs.getBool('legacyStartingValuesMigrated') ?? false)) {
      await prefs.setDouble(
        balanceKey,
        prefs.getDouble('startingBalance') ?? 0.00,
      );

      await prefs.setDouble(
        incomeKey,
        prefs.getDouble('startingIncome') ?? 0.00,
      );

      await prefs.setDouble(
        expensesKey,
        prefs.getDouble('startingExpenses') ?? 0.00,
      );

      await prefs.remove('startingBalance');
      await prefs.remove('startingIncome');
      await prefs.remove('startingExpenses');

      await prefs.setBool('legacyStartingValuesMigrated', true);
    }

    if (!mounted) return;

    setState(() {
      startingBalance = prefs.getDouble(balanceKey) ?? 0.00;
      startingIncome = prefs.getDouble(incomeKey) ?? 0.00;
      startingExpenses = prefs.getDouble(expensesKey) ?? 0.00;
    });
  }

  Future<void> loadFixedMonthlyValues() async {
    final prefs = await SharedPreferences.getInstance();

    if (!mounted) return;

    setState(() {
      fixedMonthlyIncome =
          prefs.getDouble('fixedMonthlyIncome_$userId') ?? 0.00;

      fixedMonthlyExpenses =
          prefs.getDouble('fixedMonthlyExpenses_$userId') ?? 0.00;
    });
  }

  Future<void> editFixedMonthlyValues({
    required bool isIncome,
  }) async {
    final controller = TextEditingController(text: '00.00');

    final result = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          isIncome
              ? 'Edit Fixed Monthly Income'
              : 'Edit Fixed Monthly Expenses',
        ),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          onChanged: (value) {
            String digits = value.replaceAll(RegExp(r'[^0-9]'), '');

            digits = digits.replaceFirst(
              RegExp(r'^0+(?=\d)'),
              '',
            );

            if (digits.isEmpty) {
              digits = '0';
            }

            digits = digits.padLeft(3, '0');

            final formatted = '${digits.substring(0, digits.length - 2)}.'
                '${digits.substring(digits.length - 2)}';

            controller.value = TextEditingValue(
              text: formatted,
              selection: TextSelection.collapsed(
                offset: formatted.length,
              ),
            );
          },
          decoration: InputDecoration(
            labelText: 'Amount ($displayCurrency)',
            prefixText:
                '${CurrencyService.getCurrencySymbol(displayCurrency)} ',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context, null);
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final amount = double.tryParse(controller.text.trim());

              if (amount == null || amount < 0) {
                return;
              }

              Navigator.pop(context, amount);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result == null) {
      return;
    }

    final rate = exchangeRates[displayCurrency] ?? 1.0;
    final baseAmount = result / rate;

    final prefs = await SharedPreferences.getInstance();

    if (isIncome) {
      await prefs.setDouble('fixedMonthlyIncome_$userId', baseAmount);
    } else {
      await prefs.setDouble('fixedMonthlyExpenses_$userId', baseAmount);
    }

    if (!mounted) return;

    setState(() {
      if (isIncome) {
        fixedMonthlyIncome = baseAmount;
      } else {
        fixedMonthlyExpenses = baseAmount;
      }
    });

    if (fixedMonthlyIncome > 0 && fixedMonthlyExpenses > 0) {
      await generateMonthlyTransactions();
    }
  }

  Future<void> saveTransactions() async {
    final prefs = await SharedPreferences.getInstance();

    final savedTransactions =
        transactions.map((transaction) => jsonEncode(transaction)).toList();

    await prefs.setStringList(transactionsKey, savedTransactions);

    await saveStartingValues();
  }

  Future<void> saveStartingValues() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setDouble('startingBalance_$userId', startingBalance);
    await prefs.setDouble('startingIncome_$userId', startingIncome);
    await prefs.setDouble('startingExpenses_$userId', startingExpenses);
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

  Widget getSelectedPage() {
    switch (selectedIndex) {
      case 1:
        return BudgetScreen(
          transactions: transactions,
        );

      case 2:
        return HistoryScreen(
          transactions: transactions,
          onEdit: (transaction) async {
            final result = await Navigator.push<Map<String, dynamic>>(
              context,
              MaterialPageRoute(
                builder: (context) => AddTransactionScreen(
                  transaction: transaction,
                  baseCurrency: baseCurrency,
                  displayCurrency: displayCurrency,
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
              await BudgetScreen.checkBudgetNotifications(
                transactions: transactions,
                userId: userId,
              );
            }
          },
          onDelete: (transaction) async {
            setState(() {
              transactions.remove(transaction);
            });

            await saveTransactions();
            await BudgetScreen.checkBudgetNotifications(
              transactions: transactions,
              userId: userId,
            );
          },
        );

      case 3:
        return const ProfileScreen();

      default:
        return buildHomePage();
    }
  }

  Widget buildHomePage() {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hello ${FirebaseAuth.instance.currentUser?.displayName ?? 'there'} 👋',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 5),
                    const Text(
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
                  backgroundImage:
                      FirebaseAuth.instance.currentUser?.photoURL != null
                          ? NetworkImage(
                              FirebaseAuth.instance.currentUser!.photoURL!,
                            )
                          : null,
                  child: FirebaseAuth.instance.currentUser?.photoURL == null
                      ? const Icon(Icons.person, color: blue)
                      : null,
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
                    const Text(
                      'Total Balance',
                      style: TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      formatDisplayAmount(totalBalance),
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Your current balance',
                      style: TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 16),
                    const Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        'View Monthly Overview →',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 25),

            // Fixed Monthly Income and Expenses
            Row(
              children: [
                Expanded(
                  child: SummaryCard(
                    title: 'Fixed Monthly Income',
                    amount: formatDisplayAmount(fixedMonthlyIncome),
                    icon: Icons.arrow_downward,
                    iconColor: Colors.greenAccent,
                    onEdit: () {
                      editFixedMonthlyValues(isIncome: true);
                    },
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: SummaryCard(
                    title: 'Fixed Monthly Expenses',
                    amount: formatDisplayAmount(fixedMonthlyExpenses),
                    icon: Icons.arrow_upward,
                    iconColor: Colors.redAccent,
                    onEdit: () {
                      editFixedMonthlyValues(isIncome: false);
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 25),

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
                final amount = (transaction['amount'] as num).toDouble();

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
                    await BudgetScreen.checkBudgetNotifications(
                      transactions: transactions,
                      userId: userId,
                    );
                  },
                  child: GestureDetector(
                    onTap: () async {
                      final result = await Navigator.push<Map<String, dynamic>>(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AddTransactionScreen(
                            transaction: transaction,
                            baseCurrency: baseCurrency,
                            displayCurrency: displayCurrency,
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
                        await BudgetScreen.checkBudgetNotifications(
                          transactions: transactions,
                          userId: userId,
                        );
                      }
                    },
                    child: TransactionTile(
                      title: transaction['description'] as String,
                      category: transaction['category'] as String,
                      amount:
                          '${isExpense ? '- ' : '+ '}${formatDisplayAmount(amount)}',
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: getSelectedPage(),
      floatingActionButton: selectedIndex == 0
          ? FloatingActionButton(
              backgroundColor: blue,
              foregroundColor: Colors.white,
              onPressed: () async {
                final result = await Navigator.push<Map<String, dynamic>>(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AddTransactionScreen(
                      baseCurrency: baseCurrency,
                      displayCurrency: displayCurrency,
                    ),
                  ),
                );

                if (result != null) {
                  setState(() {
                    transactions.add(result);
                  });

                  await saveTransactions();
                  await BudgetScreen.checkBudgetNotifications(
                    transactions: transactions,
                    userId: userId,
                  );
                }
              },
              child: const Icon(Icons.add, size: 30),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        backgroundColor: cardColor,
        indicatorColor: blue.withOpacity(0.25),
        selectedIndex: selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            selectedIndex = index;
          });

          // Refresh currency settings when leaving Profile.
          if (selectedIndex != 3) {
            loadCurrencySettings();
          }
        },
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
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

// Summary Card
// Summary Card
class SummaryCard extends StatelessWidget {
  final String title;
  final String amount;
  final IconData icon;
  final Color iconColor;
  final VoidCallback onEdit;

  const SummaryCard({
    super.key,
    required this.title,
    required this.amount,
    required this.icon,
    required this.iconColor,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 130,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 25),
          const SizedBox(height: 8),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 5),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              amount,
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const Spacer(),
          Align(
            alignment: Alignment.bottomRight,
            child: TextButton.icon(
              onPressed: onEdit,
              icon: const Icon(Icons.edit, size: 14),
              label: const Text(
                'Edit',
                style: TextStyle(fontSize: 13),
              ),
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
          InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ProfileScreen(),
                ),
              );
            },
            borderRadius: BorderRadius.circular(30),
            child: CircleAvatar(
              backgroundColor: cardColor,
              backgroundImage:
                  FirebaseAuth.instance.currentUser?.photoURL != null
                      ? NetworkImage(
                          FirebaseAuth.instance.currentUser!.photoURL!,
                        )
                      : null,
              child: FirebaseAuth.instance.currentUser?.photoURL == null
                  ? const Icon(Icons.person, color: blue)
                  : null,
            ),
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
