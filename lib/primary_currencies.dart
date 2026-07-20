import 'dart:convert';

import 'package:exchange_rates/myfin_cities.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CurrencyMeta {
  const CurrencyMeta({
    required this.id,
    required this.sefAlias,
    required this.multiplier,
  });

  /// ID валюты на myfin.by.
  final int id;
  final String sefAlias;

  /// За сколько единиц валюты котируется курс (как на myfin).
  final int multiplier;
}

/// Метаданные myfin для валют, кроме BYN.
const kMyfinCurrencyMeta = <String, CurrencyMeta>{
  'USD': CurrencyMeta(id: 1, sefAlias: 'usd', multiplier: 1),
  'EUR': CurrencyMeta(id: 4, sefAlias: 'eur', multiplier: 1),
  'RUB': CurrencyMeta(id: 5, sefAlias: 'rub', multiplier: 100),
  'UAH': CurrencyMeta(id: 7, sefAlias: 'uah', multiplier: 100),
  'PLN': CurrencyMeta(id: 8, sefAlias: 'pln', multiplier: 10),
  'CNY': CurrencyMeta(id: 13, sefAlias: 'cny', multiplier: 10),
  'KZT': CurrencyMeta(id: 14, sefAlias: 'kzt', multiplier: 1000),
  'TRY': CurrencyMeta(id: 31, sefAlias: 'try', multiplier: 10),
  'AED': CurrencyMeta(id: 39, sefAlias: 'aed', multiplier: 10),
};

const kPrimaryCurrencyCodes = <String>[
  'BYN',
  'USD',
  'EUR',
  'RUB',
  'PLN',
  'CNY',
  'TRY',
  'AED',
  'KZT',
  'UAH',
];

/// Включённые валюты после первой установки и после сброса настроек.
const Set<String> kDefaultEnabledCurrencyCodes = {
  'BYN',
  'USD',
  'EUR',
  'RUB',
};

const kCurrencyDisplayNames = <String, String>{
  'BYN': 'Белорусский рубль',
  'USD': 'Доллар США',
  'EUR': 'Евро',
  'RUB': 'Российский рубль',
  'PLN': 'Злотый',
  'CNY': 'Китайский юань',
  'TRY': 'Турецкая лира',
  'AED': 'Дирхам ОАЭ',
  'KZT': 'Казахстанский тенге',
  'UAH': 'Украинская гривна',
};

const _enabledCurrenciesKey = 'enabled_currency_codes';
const _displayOrderKey = 'currency_codes_display_order';
const _enabledSchemaKey = 'enabled_currency_codes_schema';
const _enabledSchemaVersion = 6;

/// Совпадают с ключами на главном экране — не менять раздельно.
const kPrefsSelectedBaseCurrency = 'selected_base_currency';
const kPrefsLastEnteredAmount = 'last_entered_amount';
const kPrefsSelectedCityId = 'selected_city_id';

/// Полный порядок строк в настройках и порядок включённых валют на главной.
class CurrencyUiConfig {
  const CurrencyUiConfig({
    required this.fullOrder,
    required this.enabled,
  });

  final List<String> fullOrder;
  final Set<String> enabled;
}

List<String> _normalizeFullOrder(Iterable<String> candidate) {
  final seen = <String>{};
  final out = <String>[];
  for (final raw in candidate) {
    final c = raw.toUpperCase();
    if (kPrimaryCurrencyCodes.contains(c) && seen.add(c)) {
      out.add(c);
    }
  }
  for (final c in kPrimaryCurrencyCodes) {
    if (seen.add(c)) {
      out.add(c);
    }
  }
  return out;
}

Set<String> _normalizeEnabled(Iterable<String> candidate) {
  return candidate
      .map((e) => e.toUpperCase())
      .where(kPrimaryCurrencyCodes.contains)
      .toSet();
}

/// Удаляет сохранённые настройки, как будто приложение только что установили.
Future<void> resetAppPreferencesToFreshInstall() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(_enabledCurrenciesKey);
  await prefs.remove(_displayOrderKey);
  await prefs.remove(_enabledSchemaKey);
  await prefs.remove(kPrefsSelectedBaseCurrency);
  await prefs.remove(kPrefsLastEnteredAmount);
  await prefs.remove(kPrefsSelectedCityId);
}

Future<CurrencyUiConfig> loadCurrencyUiConfig() async {
  final prefs = await SharedPreferences.getInstance();

  List<String> order = List<String>.from(kPrimaryCurrencyCodes);
  final orderRaw = prefs.getString(_displayOrderKey);
  if (orderRaw != null && orderRaw.isNotEmpty) {
    try {
      final list = jsonDecode(orderRaw) as List<dynamic>;
      order = _normalizeFullOrder(list.map((e) => e.toString()));
    } catch (_) {}
  }

  if (!prefs.containsKey(_enabledCurrenciesKey)) {
    return CurrencyUiConfig(
      fullOrder: order,
      enabled: Set<String>.from(kDefaultEnabledCurrencyCodes),
    );
  }

  final raw = prefs.getString(_enabledCurrenciesKey);
  if (raw == null || raw.isEmpty) {
    return CurrencyUiConfig(
      fullOrder: order,
      enabled: Set<String>.from(kDefaultEnabledCurrencyCodes),
    );
  }

  Set<String> enabled;
  try {
    final list = jsonDecode(raw) as List<dynamic>;
    enabled = _normalizeEnabled(list.map((e) => e.toString()));
  } catch (_) {
    enabled = Set<String>.from(kDefaultEnabledCurrencyCodes);
  }

  final schema = prefs.getInt(_enabledSchemaKey) ?? 1;
  if (schema < _enabledSchemaVersion) {
    // v6: убраны THB; список привязан к myfin. Старые коды отфильтруются.
    if (enabled.isEmpty) {
      enabled = Set<String>.from(kDefaultEnabledCurrencyCodes);
    }
    await prefs.setInt(_enabledSchemaKey, _enabledSchemaVersion);
    await saveCurrencyUiConfig(
      CurrencyUiConfig(fullOrder: order, enabled: enabled),
    );
  }

  return CurrencyUiConfig(fullOrder: order, enabled: enabled);
}

Future<void> saveCurrencyUiConfig(CurrencyUiConfig config) async {
  final prefs = await SharedPreferences.getInstance();
  final order = _normalizeFullOrder(config.fullOrder);
  final normalizedEnabled = _normalizeEnabled(config.enabled);
  await prefs.setString(_displayOrderKey, jsonEncode(order));
  final enabledInOrder = order.where(normalizedEnabled.contains).toList();
  await prefs.setString(_enabledCurrenciesKey, jsonEncode(enabledInOrder));
  await prefs.setInt(_enabledSchemaKey, _enabledSchemaVersion);
}

/// Совместимость: только множество включённых (порядок на главной — из [loadCurrencyUiConfig]).
Future<Set<String>> loadEnabledCurrencyCodes() async {
  final c = await loadCurrencyUiConfig();
  return c.enabled;
}

/// Совместимость: сохраняет включённые, не меняя текущий порядок из хранилища.
Future<void> saveEnabledCurrencyCodes(Set<String> enabled) async {
  final prefs = await SharedPreferences.getInstance();
  List<String> order = List<String>.from(kPrimaryCurrencyCodes);
  final orderRaw = prefs.getString(_displayOrderKey);
  if (orderRaw != null && orderRaw.isNotEmpty) {
    try {
      final list = jsonDecode(orderRaw) as List<dynamic>;
      order = _normalizeFullOrder(list.map((e) => e.toString()));
    } catch (_) {}
  }
  await saveCurrencyUiConfig(
    CurrencyUiConfig(fullOrder: order, enabled: enabled),
  );
}

String currencyDisplayName(String code) =>
    kCurrencyDisplayNames[code] ?? code;

Future<int> loadSelectedCityId() async {
  final prefs = await SharedPreferences.getInstance();
  final id = prefs.getInt(kPrefsSelectedCityId);
  if (id == null) return kDefaultMyfinCityId;
  // Невалидный id → Минск.
  for (final city in kMyfinCities) {
    if (city.id == id) return id;
  }
  return kDefaultMyfinCityId;
}

Future<void> saveSelectedCityId(int cityId) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setInt(kPrefsSelectedCityId, cityId);
}
