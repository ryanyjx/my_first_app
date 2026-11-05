import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

Future<DateTime?> showMonthYearPicker({
  required BuildContext context,
  required DateTime initialDate,
}) async {
  DateTime selectedYear = initialDate;

  return showDialog<DateTime>(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Select Month & Year'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      onPressed: () {
                        setDialogState(() {
                          selectedYear = DateTime(
                            selectedYear.year - 1,
                            selectedYear.month,
                          );
                        });
                      },
                      icon: const Icon(Icons.chevron_left),
                    ),
                    Text(
                      DateFormat('yyyy').format(selectedYear),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        setDialogState(() {
                          selectedYear = DateTime(
                            selectedYear.year + 1,
                            selectedYear.month,
                          );
                        });
                      },
                      icon: const Icon(Icons.chevron_right),
                    ),
                  ],
                ),
                const SizedBox(height: 15),
                SizedBox(
                  width: 280,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: List.generate(12, (index) {
                      final month = index + 1;
                      final isSelected = selectedYear.month == month;

                      return SizedBox(
                        width: 80,
                        height: 45,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () {
                            setDialogState(() {
                              selectedYear = DateTime(
                                selectedYear.year,
                                month,
                              );
                            });
                          },
                          child: Container(
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFF3D7BFF)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              DateFormat('MMM').format(
                                DateTime(selectedYear.year, month),
                              ),
                              style: TextStyle(
                                color: isSelected ? Colors.white : null,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context, selectedYear);
                },
                child: const Text('OK'),
              ),
            ],
          );
        },
      );
    },
  );
}
