import 'dart:async';

import 'package:exchange_rates/features/converter/data/currency_rates_service.dart';
import 'package:exchange_rates/myfin_cities.dart';
import 'package:exchange_rates/pages/settings_page.dart';
import 'package:exchange_rates/primary_currencies.dart';
import 'package:exchange_rates/ui/app_page_template.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {
  static const _fieldBorderColor = Color(0xFFE1E8F1);

  /// Общая высота контента строки (без padding карточки).
  static const double _currencyRowInnerHeight = 56;

  final _amountController = TextEditingController();
  final _service = CurrencyRatesService();

  AnimationController? _skeletonController;
  Animation<double>? _skeletonFade;

  String _baseCode = 'BYN';
  int _cityId = kDefaultMyfinCityId;
  bool _isLoading = true;
  String? _errorText;
  String? _date;
  Map<String, BankCurrencyRate> _rates = {};
  Set<String> _enabledCodes = Set<String>.from(kDefaultEnabledCurrencyCodes);
  List<String> _currencyOrder = List<String>.from(kPrimaryCurrencyCodes);

  List<String> get _displayCodes {
    return _currencyOrder
        .where((c) => _rates.containsKey(c) && _enabledCodes.contains(c))
        .toList();
  }

  List<String> get _enabledCodesOrdered {
    return _currencyOrder.where(_enabledCodes.contains).toList();
  }

  int get _skeletonRowCount => _enabledCodesOrdered.length;

  List<String> get _selectorCodes => _displayCodes;

  String get _cityName => myfinCityById(_cityId).name;

  void _ensureSkeletonController() {
    if (_skeletonController == null) {
      final c = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1000),
      );
      _skeletonController = c;
      _skeletonFade = Tween<double>(begin: 0.5, end: 0.92).animate(
        CurvedAnimation(parent: c, curve: Curves.easeInOut),
      );
      if (_isLoading) {
        c.repeat(reverse: true);
      }
      return;
    }
    _skeletonFade ??= Tween<double>(begin: 0.5, end: 0.92).animate(
      CurvedAnimation(
        parent: _skeletonController!,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _ensureSkeletonController();
    if (_isLoading) {
      _skeletonController?.repeat(reverse: true);
    }
    _amountController.addListener(_onInputChanged);
    unawaited(_initialize());
  }

  @override
  void reassemble() {
    super.reassemble();
    _ensureSkeletonController();
    if (_isLoading &&
        _skeletonController != null &&
        !_skeletonController!.isAnimating) {
      _skeletonController!.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _skeletonController?.dispose();
    _skeletonController = null;
    _skeletonFade = null;
    _amountController.removeListener(_onInputChanged);
    _amountController.dispose();
    super.dispose();
  }

  void _onInputChanged() {
    setState(() {});
  }

  Future<void> _initialize() async {
    await _restorePreferences();
    await _loadRates();
  }

  Future<void> _restorePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    // Старый ключ суммы больше не используем.
    await prefs.remove(kPrefsLastEnteredAmount);
    final savedCode = prefs.getString(kPrefsSelectedBaseCurrency);
    final cityId = await loadSelectedCityId();
    final config = await loadCurrencyUiConfig();
    if (!mounted) return;
    setState(() {
      _currencyOrder = List<String>.from(config.fullOrder);
      _enabledCodes = Set<String>.from(config.enabled);
      _cityId = cityId;
      if (savedCode != null && savedCode.isNotEmpty) {
        _baseCode = savedCode.toUpperCase();
      } else {
        _baseCode = 'BYN';
      }
    });
    _ensureBaseInSelector();
  }

  Future<void> _reloadEnabledFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final savedCode = prefs.getString(kPrefsSelectedBaseCurrency);
    final cityId = await loadSelectedCityId();
    final config = await loadCurrencyUiConfig();
    if (!mounted) return;
    setState(() {
      _currencyOrder = List<String>.from(config.fullOrder);
      _enabledCodes = Set<String>.from(config.enabled);
      _cityId = cityId;
      if (savedCode != null && savedCode.isNotEmpty) {
        _baseCode = savedCode.toUpperCase();
      } else {
        _baseCode = 'BYN';
      }
    });
    _ensureBaseInSelector();
  }

  void _ensureBaseInSelector() {
    if (_selectorCodes.contains(_baseCode)) return;
    if (_selectorCodes.isEmpty) return;
    setState(() {
      _baseCode = _selectorCodes.contains('BYN')
          ? 'BYN'
          : _selectorCodes.first;
    });
    unawaited(_saveBaseCurrency(_baseCode));
  }

  Future<void> _saveBaseCurrency(String code) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kPrefsSelectedBaseCurrency, code);
  }

  Future<void> _pickBaseCurrency() async {
    if (_selectorCodes.isEmpty) return;

    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _selectorCodes.length,
            itemBuilder: (context, index) {
              final code = _selectorCodes[index];
              final isActive = code == _baseCode;
              return ListTile(
                title: Text('${_currencyName(code)} ($code)'),
                trailing: isActive ? const Icon(Icons.check) : null,
                onTap: () => Navigator.pop(context, code),
              );
            },
          ),
        );
      },
    );

    if (selected == null || selected == _baseCode) return;
    setState(() => _baseCode = selected);
    unawaited(_saveBaseCurrency(selected));
  }

  Future<void> _loadRates() async {
    setState(() {
      _isLoading = true;
      _errorText = null;
    });
    _ensureSkeletonController();
    _skeletonController?.repeat(reverse: true);

    try {
      final snapshot = await _service.fetchBankSnapshot(
        codes: _enabledCodesOrdered,
        cityId: _cityId,
      );
      final next = Map<String, BankCurrencyRate>.from(snapshot.ratesByCode);

      if (!mounted) return;
      setState(() {
        _rates = next;
        _date = snapshot.date.isEmpty ? null : snapshot.date;
        if (!_selectorCodes.contains(_baseCode) && _selectorCodes.isNotEmpty) {
          _baseCode = _selectorCodes.contains('BYN')
              ? 'BYN'
              : _selectorCodes.first;
        }
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorText = 'Не удалось загрузить курсы банков. Попробуй обновить.';
        _isLoading = false;
      });
    } finally {
      _skeletonController?.stop();
    }
  }

  double _parseAmount() {
    final raw = _amountController.text.trim().replaceAll(',', '.');
    return double.tryParse(raw) ?? 0;
  }

  /// Банковский путь: валюта → BYN по покупке, BYN → валюта по продаже.
  double _convertTo(String targetCode) {
    final amount = _parseAmount();
    if (amount == 0) return 0;
    if (_baseCode == targetCode) return amount;

    final byn = _toByn(amount, _baseCode);
    if (byn == null) return 0;
    if (targetCode == 'BYN') return byn;

    final target = _rates[targetCode];
    if (target == null || target.sellPerUnit == 0) return 0;
    return byn / target.sellPerUnit;
  }

  double? _toByn(double amount, String code) {
    if (code == 'BYN') return amount;
    final rate = _rates[code];
    if (rate == null) return null;
    return amount * rate.buyPerUnit;
  }

  /// Обрезка без округления: до 1 знака, если целая часть < 10, иначе до 3.
  /// Хвостовые нули убираем.
  String _format(double value) {
    if (value == 0) return '0';

    final negative = value < 0;
    final abs = value.abs();
    final decimals = abs < 10 ? 1 : 3;
    final factor = decimals == 1 ? 10.0 : 1000.0;
    final truncated = (abs * factor).truncateToDouble() / factor;

    var text = truncated.toStringAsFixed(decimals);
    text = text.replaceFirst(RegExp(r'\.?0+$'), '');
    if (text.isEmpty || text == '-') text = '0';
    text = text.replaceAll('.', ',');
    return negative ? '-$text' : text;
  }

  String _formatRate(double value) =>
      value.toStringAsFixed(value >= 10 ? 2 : 3).replaceAll('.', ',');

  String _rateLine(String code, BankCurrencyRate rate) {
    final line =
        'buy ${_formatRate(rate.buy)} · sell ${_formatRate(rate.sell)}';
    if (rate.multiplier <= 1) return line;
    return '$line / ${rate.multiplier} $code';
  }

  String _currencyName(String code) => currencyDisplayName(code);

  String _formatDate(String apiDate) {
    final parts = apiDate.split('-');
    if (parts.length != 3) return apiDate;
    return '${parts[2]}.${parts[1]}.${parts[0]}';
  }

  InputDecoration _fieldDecoration(String label) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: _fieldBorderColor),
    );

    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Color(0xFF64748B)),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: border,
      enabledBorder: border,
      focusedBorder: border,
      disabledBorder: border,
    );
  }

  @override
  Widget build(BuildContext context) {
    _ensureSkeletonController();
    return AppPageTemplate(
      title: 'Курсы банков',
      subtitle: 'Лучшие курсы $_cityName: покупка и продажа',
      headerActions: [
        IconButton(
          tooltip: 'Настройки',
          onPressed: () async {
            final updated = await Navigator.of(context).push<CurrencyUiConfig>(
              MaterialPageRoute(builder: (_) => const SettingsPage()),
            );
            if (!mounted) return;
            final cityId = await loadSelectedCityId();
            if (!mounted) return;
            if (updated != null) {
              setState(() {
                _currencyOrder = List<String>.from(updated.fullOrder);
                _enabledCodes = Set<String>.from(updated.enabled);
                _cityId = cityId;
              });
              _ensureBaseInSelector();
              unawaited(_loadRates());
            } else {
              await _reloadEnabledFromPrefs();
              unawaited(_loadRates());
            }
          },
          style: IconButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xFF334155),
            elevation: 0,
            shadowColor: Colors.transparent,
            side: const BorderSide(color: Color(0xFFDCE3EA)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          icon: const Icon(Icons.settings_rounded, size: 24),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_date != null)
            Text(
              'Дата курсов: ${_formatDate(_date!)}',
              style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: _fieldDecoration('Сумма'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: _isLoading ? null : _pickBaseCurrency,
                  child: InputDecorator(
                    decoration: _fieldDecoration('Валюта суммы'),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            _currencyName(_baseCode),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            softWrap: false,
                          ),
                        ),
                        const Icon(Icons.keyboard_arrow_down_rounded),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Обмен через банк: продаёшь банку по покупке, покупаешь у банка по продаже.',
            style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8), height: 1.35),
          ),
          const SizedBox(height: 16),
          if (_isLoading)
            _skeletonRowCount > 0
                ? FadeTransition(
                    opacity: _skeletonFade ??
                        AlwaysStoppedAnimation<double>(
                          _isLoading ? 0.72 : 1.0,
                        ),
                    child: Column(
                      children: List<Widget>.generate(
                        _skeletonRowCount,
                        (_) => const _CurrencyRowSkeleton(),
                      ),
                    ),
                  )
                : const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
          else if (_errorText != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF1F2),
                border: Border.all(color: const Color(0xFFFDA4AF)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _errorText!,
                style: const TextStyle(color: Color(0xFF9F1239)),
              ),
            )
          else if (_rates.isNotEmpty && _displayCodes.isEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Ни одна валюта не выбрана. Включи нужные в настройках (шестерёнка справа).',
                style: TextStyle(color: Color(0xFF64748B), height: 1.35),
              ),
            )
          else
            Column(
              children: _displayCodes.map((code) {
                final rate = _rates[code];
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFDCE3ED)),
                  ),
                  child: SizedBox(
                    height: _currencyRowInnerHeight,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _currencyName(code),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 14,
                                  height: 1.2,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF1F2937),
                                ),
                              ),
                              Text(
                                code,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  height: 1.2,
                                  color: Color(0xFF6B7280),
                                ),
                              ),
                              if (rate != null && code != 'BYN') ...[
                                const SizedBox(height: 2),
                                Text(
                                  _rateLine(code, rate),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    height: 1.15,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        Text(
                          _format(_convertTo(code)),
                          style: const TextStyle(
                            fontSize: 24,
                            height: 1.0,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF111827),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF020617),
                foregroundColor: Colors.white,
                elevation: 0,
                minimumSize: const Size(0, 48),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: _isLoading ? null : _loadRates,
              icon: const Icon(Icons.refresh_rounded, size: 22),
              label: const Text('Обновить курсы'),
            ),
          ),
        ],
      ),
    );
  }
}

class _CurrencyRowSkeleton extends StatelessWidget {
  const _CurrencyRowSkeleton();

  static const _bone = Color(0xFFCBD5E1);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDCE3ED)),
      ),
      child: SizedBox(
        height: _HomePageState._currencyRowInnerHeight,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    height: 14 * 1.2,
                    width: 168,
                    decoration: BoxDecoration(
                      color: _bone,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Container(
                    height: 12 * 1.2,
                    width: 52,
                    decoration: BoxDecoration(
                      color: _bone,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    height: 11,
                    width: 180,
                    decoration: BoxDecoration(
                      color: _bone,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 88,
              height: 24,
              decoration: BoxDecoration(
                color: _bone,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
