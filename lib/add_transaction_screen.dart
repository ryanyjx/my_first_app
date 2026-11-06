// ignore_for_file: use_build_context_synchronously
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import 'currency_service.dart';

class AddTransactionScreen extends StatefulWidget {
  final Map<String, dynamic>? transaction;
  final String baseCurrency;
  final String displayCurrency;

  const AddTransactionScreen({
    super.key,
    this.transaction,
    this.baseCurrency = 'MYR',
    this.displayCurrency = 'MYR',
  });

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  String transactionType = 'Expense';
  String selectedCategory = 'Food';
  DateTime selectedDate = DateTime.now();
  String? receiptImagePath;

  final descriptionController = TextEditingController();
  final amountController = TextEditingController();

  @override
  void initState() {
    super.initState();

    final transaction = widget.transaction;

    if (transaction != null) {
      receiptImagePath = transaction['receiptImagePath'];
      transactionType = transaction['type'];
      selectedCategory = transaction['category'];
      descriptionController.text = transaction['description'];
      loadTransactionAmount(
        (transaction['amount'] as num).toDouble(),
      );
      selectedDate = transaction['date'] != null
          ? DateTime.parse(transaction['date'])
          : DateTime.now();
    }
  }

  Future<void> loadTransactionAmount(double amount) async {
    try {
      final convertedAmount = await CurrencyService.convertAmount(
        amount: amount,
        fromCurrency: widget.baseCurrency,
        toCurrency: widget.displayCurrency,
      );

      if (!mounted) return;

      amountController.text = convertedAmount.toStringAsFixed(2);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to load the converted transaction amount.'),
        ),
      );
    }
  }

  Future<void> pickReceiptImage(ImageSource source) async {
    final picker = ImagePicker();

    final pickedImage = await picker.pickImage(
      source: source,
      imageQuality: 80,
    );

    if (pickedImage == null) return;

    final directory = await getApplicationDocumentsDirectory();

    final savedPath =
        '${directory.path}/receipt_${DateTime.now().millisecondsSinceEpoch}.jpg';

    final savedImage = await File(pickedImage.path).copy(savedPath);

    if (!mounted) return;

    setState(() {
      receiptImagePath = savedImage.path;
    });
  }

  @override
  void dispose() {
    descriptionController.dispose();
    amountController.dispose();
    super.dispose();
  }

  Future<void> saveTransaction() async {
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

    double amountInBaseCurrency;

    try {
      amountInBaseCurrency = await CurrencyService.convertAmount(
        amount: amount,
        fromCurrency: widget.displayCurrency,
        toCurrency: widget.baseCurrency,
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to convert currency. Please try again.'),
        ),
      );
      return;
    }

    final transaction = {
      'description': description,
      'amount': amountInBaseCurrency,
      'type': transactionType,
      'category': selectedCategory,
      'date': selectedDate.toIso8601String(),
      'receiptImagePath': receiptImagePath,
    };

    Navigator.pop(context, {
      ...?widget.transaction,
      ...transaction,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: Text(
          widget.transaction == null ? 'Add Transaction' : 'Edit Transaction',
        ),
      ),
      body: SingleChildScrollView(
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
            Text('Amount (${widget.displayCurrency})'),
            const SizedBox(height: 8),
            TextField(
              controller: amountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                MoneyInputFormatter(),
              ],
              decoration: InputDecoration(
                hintText: '0.00',
                prefixText:
                    '${CurrencyService.getCurrencySymbol(widget.displayCurrency)} ',
                border: const OutlineInputBorder(),
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
            const SizedBox(height: 20),
            const Text('Transaction Date'),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () async {
                final pickedDate = await showDatePicker(
                  context: context,
                  initialDate: selectedDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                );

                if (pickedDate != null) {
                  setState(() {
                    selectedDate = pickedDate;
                  });
                }
              },
              icon: const Icon(Icons.calendar_today),
              label: Text(
                '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
              ),
            ),
            const Text('Add Photo'),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => pickReceiptImage(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Gallery'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => pickReceiptImage(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Camera'),
                  ),
                ),
              ],
            ),
            if (receiptImagePath != null) ...[
              const SizedBox(height: 15),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(
                  File(receiptImagePath!),
                  height: 180,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () {
                    setState(() {
                      receiptImagePath = null;
                    });
                  },
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  label: const Text(
                    'Remove Photo',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),
            const SizedBox(height: 8),
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

class MoneyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');

    if (digits.isEmpty) {
      return const TextEditingValue(
        text: '00.00',
        selection: TextSelection.collapsed(offset: 5),
      );
    }

    final amount = int.parse(digits);
    final formatted = (amount / 100).toStringAsFixed(2);

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
