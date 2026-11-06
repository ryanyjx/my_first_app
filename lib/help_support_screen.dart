import 'package:flutter/material.dart';

const Color helpBackground = Color(0xFF121826);
const Color helpCard = Color(0xFF1E293B);
const Color helpBlue = Color(0xFF3D7BFF);

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  Widget buildHelpSection({
    required IconData icon,
    required String title,
    required List<String> instructions,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: helpCard,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ExpansionTile(
        leading: Icon(icon, color: helpBlue),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconColor: helpBlue,
        collapsedIconColor: Colors.white60,
        childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        children: instructions.map((instruction) {
          return Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.check_circle_outline,
                  color: helpBlue,
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    instruction,
                    style: const TextStyle(
                      color: Colors.white70,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: helpBackground,
      appBar: AppBar(
        title: const Text('Help & Support'),
        backgroundColor: helpBackground,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Welcome to BudgetBuddy!',
              style: TextStyle(
                fontSize: 23,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Learn how to use the different features of BudgetBuddy. '
              'Tap each section below to view its instructions.',
              style: TextStyle(
                color: Colors.white60,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 25),
            buildHelpSection(
              icon: Icons.home_outlined,
              title: 'Home Page',
              instructions: [
                'Your Total Balance shows your overall income minus expenses. '
                    'Tap it to open the Monthly Overview.',
                'Fixed Monthly Income and Fixed Monthly Expenses show your '
                    'recurring amounts. Tap Edit to change them.',
                'Recent Transactions displays your latest transactions for '
                    'the selected month.',
                'Tap a recent transaction to view its details, including '
                    'its receipt photo if one was attached.',
                'Tap the + button to add a new transaction.',
                'Swipe a recent transaction to the left to delete it.',
              ],
            ),
            buildHelpSection(
              icon: Icons.add_circle_outline,
              title: 'Adding Transactions',
              instructions: [
                'Tap the + button on the Home page to add a transaction.',
                'Choose whether the transaction is Income or Expense.',
                'Enter the description, amount, category and date.',
                'You can attach a receipt photo when adding a transaction.',
                'Save the transaction to add it to your records.',
              ],
            ),
            buildHelpSection(
              icon: Icons.receipt_long,
              title: 'Transaction Details',
              instructions: [
                'Tap a transaction from Home or History to view its details.',
                'The details page displays information such as description, '
                    'amount, category and date.',
                'If a receipt photo was attached, you can view it on this page.',
                'Tap Edit to update the transaction.',
                'Tap Delete to remove the transaction.',
              ],
            ),
            buildHelpSection(
              icon: Icons.edit,
              title: 'Editing and Deleting Transactions',
              instructions: [
                'Open a transaction and tap Edit to change its information.',
                'Update the details and save your changes.',
                'To delete a transaction, tap Delete and confirm your choice.',
                'You can also swipe a transaction to the left in History '
                    'to delete it.',
                'Deleted transactions are removed from your saved records.',
              ],
            ),
            buildHelpSection(
              icon: Icons.account_balance_wallet_outlined,
              title: 'Budgets',
              instructions: [
                'Open the Budgets tab from the bottom navigation bar.',
                'Use the budget features to manage your spending limits.',
                'Check your budget progress to see how much of your budget '
                    'has been used.',
                'Review your transactions regularly to keep track of spending.',
              ],
            ),
            buildHelpSection(
              icon: Icons.calendar_month,
              title: 'Monthly Overview',
              instructions: [
                'Tap Total Balance on the Home page to open Monthly Overview.',
                'Use the overview to review your monthly financial activity.',
                'Compare your income and expenses to understand your '
                    'spending patterns.',
              ],
            ),
            buildHelpSection(
              icon: Icons.history,
              title: 'Transaction History',
              instructions: [
                'Open the History tab to view your saved transactions.',
                'Use the search bar to find a transaction by its description.',
                'Use the month selector to view transactions from a '
                    'specific month.',
                'Use the Type filter to show Income or Expense transactions.',
                'Use the Category filter to narrow down your transactions.',
                'Tap a transaction to view its details.',
                'Swipe a transaction to the left to delete it.',
                'Pull down to refresh your transaction history.',
              ],
            ),
            buildHelpSection(
              icon: Icons.currency_exchange,
              title: 'Currency Settings',
              instructions: [
                'Open your Profile page.',
                'Find the Currency section and tap its Edit button.',
                'Choose your preferred display currency.',
                'Transaction amounts will be displayed using your selected '
                    'currency.',
              ],
            ),
            buildHelpSection(
              icon: Icons.person_outline,
              title: 'Profile Settings',
              instructions: [
                'Upload a profile picture using Change Picture.',
                'Choose Delete Profile Picture to remove your uploaded picture.',
                'Tap the Edit button beside Username to change your username.',
                'Tap the Edit button beside Email to request an email change.',
                'Changing your email requires your current password and '
                    'email verification.',
                'The Password option is not available yet in this version.',
                'Tap Log Out to sign out of your account.',
              ],
            ),
            const SizedBox(height: 15),
            const Center(
              child: Text(
                'BudgetBuddy • Help & Support',
                style: TextStyle(
                  color: Colors.white38,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
