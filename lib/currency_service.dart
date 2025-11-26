import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class CurrencyService {
  static const String _apiUrl = 'https://api.exchangerate-api.com/v4/latest/INR';
  static const String _cacheKey = 'exchange_rates';
  static const String _timestampKey = 'rates_timestamp';
  static const Duration _cacheDuration = Duration(hours: 1);

  static Future<Map<String, double>> getExchangeRates() async {
    final prefs = await SharedPreferences.getInstance();
    final cachedRates = prefs.getString(_cacheKey);
    final timestamp = prefs.getInt(_timestampKey);

    // Check if cache is valid
    if (cachedRates != null && timestamp != null) {
      final cacheTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
      if (DateTime.now().difference(cacheTime) < _cacheDuration) {
        final rawCached = json.decode(cachedRates) as Map<String, dynamic>;
        final rates = <String, double>{};
        rawCached.forEach((key, value) {
          rates[key] = (value is int) ? value.toDouble() : value as double;
        });
        return rates;
      }
    }

    // Fetch from API
    try {
      final response = await http.get(Uri.parse(_apiUrl));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final rawRates = data['rates'] as Map<String, dynamic>;
        // Safely convert to double
        final rates = <String, double>{};
        rawRates.forEach((key, value) {
          rates[key] = (value is int) ? value.toDouble() : value as double;
        });
        // Cache the rates
        await prefs.setString(_cacheKey, json.encode(rates));
        await prefs.setInt(_timestampKey, DateTime.now().millisecondsSinceEpoch);
        return rates;
      } else {
        throw Exception('API Error: ${response.statusCode}');
      }
    } catch (e) {
      // Fall back to cached rates
      if (cachedRates != null) {
        final rawCached = json.decode(cachedRates) as Map<String, dynamic>;
        final rates = <String, double>{};
        rawCached.forEach((key, value) {
          rates[key] = (value is int) ? value.toDouble() : value as double;
        });
        return rates;
      }
      throw Exception('Failed to fetch rates: $e');
    }
  }

  static double convertAmount(double amount, String fromCurrency, String toCurrency, Map<String, double> rates) {
    if (fromCurrency == toCurrency || rates.isEmpty) return amount;
    if (!rates.containsKey(fromCurrency) || !rates.containsKey(toCurrency)) return amount;  // Fallback if currency not in rates
    final inrAmount = fromCurrency == 'INR' ? amount : amount / rates[fromCurrency]!;
    return toCurrency == 'INR' ? inrAmount : inrAmount * rates[toCurrency]!;
  }
}
