import 'dart:convert';

import 'package:exchange_rates/myfin_cities.dart';
import 'package:exchange_rates/primary_currencies.dart';
import 'package:http/http.dart' as http;

/// Лучший банковский курс (myfin): BYN за [CurrencyMeta.multiplier] единиц валюты.
class BankCurrencyRate {
  const BankCurrencyRate({
    required this.code,
    required this.date,
    required this.buy,
    required this.sell,
    required this.multiplier,
  });

  final String code;
  final String date;

  /// Покупка банком (value0): я продаю валюту банку.
  final double buy;

  /// Продажа банком (value1): я покупаю валюту у банка.
  final double sell;

  final int multiplier;

  /// BYN за 1 единицу валюты (покупка).
  double get buyPerUnit => buy / multiplier;

  /// BYN за 1 единицу валюты (продажа).
  double get sellPerUnit => sell / multiplier;
}

class CurrencyRatesSnapshot {
  CurrencyRatesSnapshot({
    required this.date,
    required this.ratesByCode,
  });

  final String date;
  final Map<String, BankCurrencyRate> ratesByCode;
}

class CurrencyRatesService {
  static const _baseUrl =
      'https://myfin.by/ajaxnew/currency-best-chart';

  Future<CurrencyRatesSnapshot> fetchBankSnapshot({
    Iterable<String>? codes,
    int cityId = kDefaultMyfinCityId,
  }) async {
    final wanted = (codes ?? kPrimaryCurrencyCodes)
        .map((c) => c.toUpperCase())
        .where((c) => c != 'BYN')
        .where(kMyfinCurrencyMeta.containsKey)
        .toList();

    final results = await Future.wait(
      wanted.map((code) => _fetchOne(code, cityId)),
      eagerError: false,
    );

    final rates = <String, BankCurrencyRate>{
      'BYN': const BankCurrencyRate(
        code: 'BYN',
        date: '',
        buy: 1,
        sell: 1,
        multiplier: 1,
      ),
    };

    String? latestDate;
    for (final rate in results) {
      if (rate == null) continue;
      rates[rate.code] = rate;
      if (latestDate == null || rate.date.compareTo(latestDate) > 0) {
        latestDate = rate.date;
      }
    }

    if (rates.length <= 1) {
      throw Exception('Не удалось загрузить курсы банков');
    }

    return CurrencyRatesSnapshot(
      date: latestDate ?? '',
      ratesByCode: rates,
    );
  }

  Future<BankCurrencyRate?> _fetchOne(String code, int cityId) async {
    final meta = kMyfinCurrencyMeta[code];
    if (meta == null) return null;

    try {
      final uri = Uri.parse(_baseUrl).replace(
        queryParameters: {
          'currency_id': '${meta.id}',
          'days': '7',
          'city_id': '$cityId',
        },
      );

      // Без кастомных заголовков: иначе Chrome шлёт CORS preflight,
      // а myfin не отдаёт Access-Control-Allow-Headers.
      final response = await http.get(uri);

      if (response.statusCode != 200) return null;

      final decoded = jsonDecode(response.body);
      if (decoded is! List || decoded.isEmpty) return null;

      final last = decoded.last;
      if (last is! Map) return null;

      final date = last['date']?.toString();
      final buy = _asDouble(last['value0']);
      final sell = _asDouble(last['value1']);
      if (date == null || buy == null || sell == null || buy <= 0 || sell <= 0) {
        return null;
      }

      return BankCurrencyRate(
        code: code,
        date: date,
        buy: buy,
        sell: sell,
        multiplier: meta.multiplier,
      );
    } catch (_) {
      return null;
    }
  }

  static double? _asDouble(Object? value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value.replaceAll(',', '.'));
    return null;
  }
}
