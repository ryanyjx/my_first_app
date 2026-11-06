import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'currency_service.dart';

class TransactionDetailsScreen extends StatelessWidget {
  final Map<String, dynamic> transaction;
  final String baseCurrency;
  final String displayCurrency;
  final Map<String, double> exchangeRates;
  final Future<void> Function(Map<String, dynamic>) onEdit;
  final Future<void> Function(Map<String, dynamic>) onDelete;

  const TransactionDetailsScreen({
    super.key,
    required this.transaction,
    required this.baseCurrency,
    required this.displayCurrency,
    required this.exchangeRates,
    required this.onEdit,
    required this.onDelete,
  });

  String formatAmount(double amount) {
    final rate = exchangeRates[displayCurrency] ?? 1.0;

    return CurrencyService.formatAmount(
      amount * rate,
      displayCurrency,
    );
  }

  @override
  Widget build(BuildContext context) {
    final description = transaction['description']?.toString() ?? '';
    final category = transaction['category']?.toString() ?? 'Other';
    final type = transaction['type']?.toString() ?? '';
    final amount = (transaction['amount'] as num).toDouble();

    final date = DateTime.tryParse(
      transaction['date']?.toString() ?? '',
    );

    final receiptPath = transaction['receiptImagePath']?.toString();

    final isExpense = type == 'Expense';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaction Details'),
        backgroundColor: const Color(0xFF1E293B),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: CircleAvatar(
                radius: 35,
                backgroundColor: const Color(0xFF3D7BFF).withOpacity(0.15),
                child: const Icon(
                  Icons.receipt_long,
                  color: Color(0xFF3D7BFF),
                  size: 35,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Center(
              child: Text(
                '${isExpense ? '- ' : '+ '}${formatAmount(amount)}',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  color: isExpense ? Colors.redAccent : Colors.greenAccent,
                ),
              ),
            ),
            const SizedBox(height: 30),
            detailRow('Description', description),
            detailRow('Transaction Type', type),
            detailRow('Category', category),
            detailRow(
              'Date',
              date != null
                  ? DateFormat('dd MMMM yyyy').format(date)
                  : 'No date',
            ),
            if (receiptPath != null && File(receiptPath).existsSync()) ...[
              const SizedBox(height: 20),
              const Text(
                'Receipt Photo',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: Image.file(
                  File(receiptPath),
                  width: double.infinity,
                  fit: BoxFit.contain,
                ),
              ),
            ],
            const SizedBox(height: 30),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      await onEdit(transaction);
                    },
                    icon: const Icon(Icons.edit),
                    label: const Text('Edit'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (dialogContext) => AlertDialog(
                          title: const Text('Delete Transaction?'),
                          content: const Text(
                            'Are you sure you want to delete this transaction?',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () {
                                Navigator.pop(dialogContext, false);
                              },
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.pop(dialogContext, true);
                              },
                              child: const Text(
                                'Delete',
                                style: TextStyle(color: Colors.red),
                              ),
                            ),
                          ],
                        ),
                      );

                      if (confirmed == true) {
                        await onDelete(transaction);
                      }
                    },
                    icon: const Icon(Icons.delete),
                    label: const Text('Delete'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget detailRow(String title, String value) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 15),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.white12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
