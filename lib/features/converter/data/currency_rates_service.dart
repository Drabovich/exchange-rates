import 'dart:convert';

import 'package:http/http.dart' as http;

class CurrencyRatesSnapshot {
  CurrencyRatesSnapshot({
    required this.date,
    required this.ratesByCode,
  });

  final String date;
  final Map<String, double> ratesByCode;
}

class CurrencyRatesService {
  static const _apiUrl =
      'https://cdn.jsdelivr.net/npm/@fawazahmed0/currency-api@latest/v1/currencies/usd.json';

  Future<CurrencyRatesSnapshot> fetchUsdSnapshot() async {
    final uri = Uri.parse(_apiUrl);
    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw Exception('Failed to load rates: HTTP ${response.statusCode}');
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final date = decoded['date'] as String?;
    final usdMap = decoded['usd'] as Map<String, dynamic>?;

    if (date == null || usdMap == null) {
      throw Exception('Invalid response format');
    }

    final parsedRates = <String, double>{};
    for (final entry in usdMap.entries) {
      final value = entry.value;
      if (value is num) {
        parsedRates[entry.key.toUpperCase()] = value.toDouble();
      }
    }

    return CurrencyRatesSnapshot(date: date, ratesByCode: parsedRates);
  }
}
