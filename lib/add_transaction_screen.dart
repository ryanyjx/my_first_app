import 'package:flutter/material.dart';

class AddTransactionScreen extends StatefulWidget {
  final Map<String, dynamic>? transaction;

  const AddTransactionScreen({
    super.key,
    this.transaction,
  });

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  String transactionType = 'Expense';
  String selectedCategory = 'Food';

  final descriptionController = TextEditingController();
  final amountController = TextEditingController();

  @override
  void initState() {
    super.initState();

    final transaction = widget.transaction;

    if (transaction != null) {
      transactionType = transaction['type'];
      selectedCategory = transaction['category'];
      descriptionController.text = transaction['description'];
      amountController.text = transaction['amount'].toString();
    }
  }

  @override
  void dispose() {
    descriptionController.dispose();
    amountController.dispose();
    super.dispose();
  }

  void saveTransaction() {
    final description = descriptionController.text.trim();
    final amount = double.tryParse(amountController.text.trim());

    if (description.isEmpty || amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a description and a valid amount.'),
        ),
      );
      return;
    }

    final transaction = {
      'description': description,
      'amount': amount,
      'type': transactionType,
      'category': selectedCategory,
    };

    Navigator.pop(context, {
      ...?widget.transaction,
      ...transaction,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.transaction == null ? 'Add Transaction' : 'Edit Transaction',
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Transaction Type'),
            const SizedBox(height: 10),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'Expense',
                  label: Text('Expense'),
                  icon: Icon(Icons.arrow_upward),
                ),
                ButtonSegment(
                  value: 'Income',
                  label: Text('Income'),
                  icon: Icon(Icons.arrow_downward),
                ),
              ],
              selected: {transactionType},
              onSelectionChanged: (selection) {
                setState(() {
                  transactionType = selection.first;
                  selectedCategory =
                      transactionType == 'Income' ? 'Salary' : 'Food';
                });
              },
            ),
            const SizedBox(height: 25),
            const Text('Description'),
            const SizedBox(height: 8),
            TextField(
              controller: descriptionController,
              decoration: const InputDecoration(
                hintText: 'e.g. Lunch, Salary',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            const Text('Amount (RM)'),
            const SizedBox(height: 8),
            TextField(
              controller: amountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                hintText: '0.00',
                prefixText: 'RM ',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            const Text('Category'),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: selectedCategory,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
              ),
              items: (transactionType == 'Income'
                      ? ['Salary', 'Business', 'Gift', 'Other']
                      : ['Food', 'Transport', 'Shopping', 'Bills', 'Other'])
                  .map((category) {
                return DropdownMenuItem(
                  value: category,
                  child: Text(category),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    selectedCategory = value;
                  });
                }
              },
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: saveTransaction,
                child: Text(
                  widget.transaction == null
                      ? 'Save Transaction'
                      : 'Update Transaction',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
