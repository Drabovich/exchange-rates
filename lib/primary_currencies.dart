import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

const kPrimaryCurrencyCodes = <String>[
  'USD',
  'RUB',
  'BYN',
  'EUR',
  'TRY',
  'AED',
  'THB',
  'PLN',
  'KZT',
  'CNY',
  'UAH',
];

/// Включённые валюты после первой установки и после сброса настроек.
const Set<String> kDefaultEnabledCurrencyCodes = {
  'USD',
  'RUB',
  'EUR',
  'BYN',
};

const kCurrencyDisplayNames = <String, String>{
  'USD': 'Доллар США',
  'RUB': 'Российский рубль',
  'BYN': 'Белорусский рубль',
  'EUR': 'Евро',
  'TRY': 'Турецкая лира',
  'AED': 'Дирхам ОАЭ',
  'THB': 'Тайский бат',
  'PLN': 'Злотый',
  'KZT': 'Казахстанский тенге',
  'CNY': 'Китайский юань',
  'UAH': 'Украинская гривна',
};

const _enabledCurrenciesKey = 'enabled_currency_codes';
const _displayOrderKey = 'currency_codes_display_order';
const _enabledSchemaKey = 'enabled_currency_codes_schema';
const _enabledSchemaVersion = 5;

/// Совпадают с ключами на главном экране — не менять раздельно.
const kPrefsSelectedBaseCurrency = 'selected_base_currency';
const kPrefsLastEnteredAmount = 'last_entered_amount';

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

/// Удаляет сохранённые настройки, как будто приложение только что установили.
Future<void> resetAppPreferencesToFreshInstall() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(_enabledCurrenciesKey);
  await prefs.remove(_displayOrderKey);
  await prefs.remove(_enabledSchemaKey);
  await prefs.remove(kPrefsSelectedBaseCurrency);
  await prefs.remove(kPrefsLastEnteredAmount);
}

Future<CurrencyUiConfig> loadCurrencyUiConfig() async {
  final prefs = await SharedPreferences.getInstance();
  // Не вызываем prefs.reload(): на части Android/эмуляторов может зависнуть.

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
    enabled = list
        .map((e) => e.toString().toUpperCase())
        .where(kPrimaryCurrencyCodes.contains)
        .toSet();
  } catch (_) {
    enabled = Set<String>.from(kDefaultEnabledCurrencyCodes);
  }

  final schema = prefs.getInt(_enabledSchemaKey) ?? 1;
  if (schema < _enabledSchemaVersion) {
    if (schema < 2) {
      enabled = {...enabled, 'TRY', 'CNY'};
    }
    if (schema < 3) {
      enabled = {...enabled, 'UAH', 'KZT', 'AED'};
    }
    if (schema < 4) {
      enabled = {...enabled, 'THB'};
    }
    await prefs.setInt(_enabledSchemaKey, _enabledSchemaVersion);
    await saveCurrencyUiConfig(CurrencyUiConfig(fullOrder: order, enabled: enabled));
  }

  return CurrencyUiConfig(fullOrder: order, enabled: enabled);
}

Future<void> saveCurrencyUiConfig(CurrencyUiConfig config) async {
  final prefs = await SharedPreferences.getInstance();
  final order = _normalizeFullOrder(config.fullOrder);
  final normalizedEnabled = config.enabled
      .map((e) => e.toUpperCase())
      .where(kPrimaryCurrencyCodes.contains)
      .toSet();
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
