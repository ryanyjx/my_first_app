import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'dart:convert';

class CurrencyService {
  static const List<String> supportedCurrencies = [
    'MYR',
    'SGD',
    'USD',
    'GBP',
    'EUR',
  ];

  static Future<Map<String, double>> getRates(
    String baseCurrency,
  ) async {
    final prefs = await SharedPreferences.getInstance();

    final cacheKey = 'exchangeRates_$baseCurrency';
    final dateKey = 'exchangeRatesDate_$baseCurrency';

    final today = DateTime.now().toIso8601String().substring(0, 10);

    // Use today's cached rates if available.
    final cachedRates = prefs.getString(cacheKey);
    final cachedDate = prefs.getString(dateKey);

    if (cachedRates != null && cachedDate == today) {
      final decoded = jsonDecode(cachedRates) as Map<String, dynamic>;

      return decoded.map(
        (key, value) => MapEntry(key, (value as num).toDouble()),
      );
    }

    try {
      final uri = Uri.https(
        'api.frankfurter.dev',
        '/v2/rates',
        {
          'base': baseCurrency,
          'quotes': 'MYR,SGD,USD,GBP,EUR',
        },
      );

      final response = await http.get(uri);

      if (response.statusCode != 200) {
        throw Exception('Unable to fetch exchange rates.');
      }

      final List<dynamic> data = jsonDecode(response.body);

      final Map<String, double> rates = {
        baseCurrency: 1.0,
      };

      for (final item in data) {
        rates[item['quote'] as String] = (item['rate'] as num).toDouble();
      }

      await prefs.setString(cacheKey, jsonEncode(rates));
      await prefs.setString(dateKey, today);

      return rates;
    } catch (e) {
      // Use previously cached rates if the internet is unavailable.
      if (cachedRates != null) {
        final decoded = jsonDecode(cachedRates) as Map<String, dynamic>;

        return decoded.map(
          (key, value) => MapEntry(key, (value as num).toDouble()),
        );
      }

      rethrow;
    }
  }

  static Future<double> convertAmount({
    required double amount,
    required String fromCurrency,
    required String toCurrency,
  }) async {
    // No conversion needed if both currencies are the same.
    if (fromCurrency == toCurrency) {
      return amount;
    }

    final rates = await getRates(fromCurrency);

    final exchangeRate = rates[toCurrency];

    if (exchangeRate == null) {
      throw Exception(
        'Exchange rate for $toCurrency is unavailable.',
      );
    }

    return amount * exchangeRate;
  }

  static String getCurrencySymbol(String currency) {
    switch (currency) {
      case 'MYR':
        return 'RM';
      case 'SGD':
        return 'S\$';
      case 'USD':
        return '\$';
      case 'GBP':
        return '£';
      case 'EUR':
        return '€';
      default:
        return currency;
    }
  }

  static String formatAmount(
    double amount,
    String currency,
  ) {
    final symbol = getCurrencySymbol(currency);

    return '$symbol${amount.toStringAsFixed(2)}';
  }
}
