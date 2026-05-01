import 'dart:async';

import 'package:exchange_rates/features/converter/data/currency_rates_service.dart';
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
  /// Общая высота контента строки (без padding карточки) — скелетон и данные совпадают, без прыжка.
  static const double _currencyRowInnerHeight = 52;

  final _amountController = TextEditingController(text: '100');
  final _service = CurrencyRatesService();

  AnimationController? _skeletonController;
  Animation<double>? _skeletonFade;

  String _baseCode = 'USD';
  bool _isLoading = true;
  String? _errorText;
  String? _date;
  Map<String, double> _rates = {};
  Set<String> _enabledCodes = Set<String>.from(kDefaultEnabledCurrencyCodes);
  List<String> _currencyOrder = List<String>.from(kPrimaryCurrencyCodes);

  List<String> get _displayCodes {
    return _currencyOrder
        .where((c) => _rates.containsKey(c) && _enabledCodes.contains(c))
        .toList();
  }

  /// Порядок включённых строк (скелетон и список на главной).
  List<String> get _enabledCodesOrdered {
    return _currencyOrder.where(_enabledCodes.contains).toList();
  }

  int get _skeletonRowCount => _enabledCodesOrdered.length;

  List<String> get _selectorCodes => _displayCodes;

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
    unawaited(_saveLastAmount(_amountController.text));
  }

  Future<void> _initialize() async {
    await _restorePreferences();
    await _loadRates();
  }

  Future<void> _restorePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final savedCode = prefs.getString(kPrefsSelectedBaseCurrency);
    final savedAmount = prefs.getString(kPrefsLastEnteredAmount);
    final config = await loadCurrencyUiConfig();
    if (!mounted) return;
    setState(() {
      _currencyOrder = List<String>.from(config.fullOrder);
      _enabledCodes = Set<String>.from(config.enabled);
      if (savedCode != null && savedCode.isNotEmpty) {
        _baseCode = savedCode.toUpperCase();
      } else {
        _baseCode = 'USD';
      }
      if (savedAmount != null && savedAmount.isNotEmpty) {
        _amountController.text = savedAmount;
      } else {
        _amountController.text = '100';
      }
    });
    _ensureBaseInSelector();
  }

  Future<void> _reloadEnabledFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final savedCode = prefs.getString(kPrefsSelectedBaseCurrency);
    final savedAmount = prefs.getString(kPrefsLastEnteredAmount);
    final config = await loadCurrencyUiConfig();
    if (!mounted) return;
    setState(() {
      _currencyOrder = List<String>.from(config.fullOrder);
      _enabledCodes = Set<String>.from(config.enabled);
      if (savedCode != null && savedCode.isNotEmpty) {
        _baseCode = savedCode.toUpperCase();
      } else {
        _baseCode = 'USD';
      }
      if (savedAmount != null && savedAmount.isNotEmpty) {
        _amountController.text = savedAmount;
      } else {
        _amountController.text = '100';
      }
    });
    _ensureBaseInSelector();
  }

  void _ensureBaseInSelector() {
    if (_selectorCodes.contains(_baseCode)) return;
    if (_selectorCodes.isEmpty) return;
    setState(() {
      _baseCode = _selectorCodes.contains('USD')
          ? 'USD'
          : _selectorCodes.first;
    });
    unawaited(_saveBaseCurrency(_baseCode));
  }

  Future<void> _saveBaseCurrency(String code) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kPrefsSelectedBaseCurrency, code);
  }

  Future<void> _saveLastAmount(String amount) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kPrefsLastEnteredAmount, amount);
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
      final snapshot = await _service.fetchUsdSnapshot();
      final next = Map<String, double>.from(snapshot.ratesByCode);

      if (!mounted) return;
      setState(() {
        _rates = next;
        _date = snapshot.date;
        if (!_selectorCodes.contains(_baseCode) && _selectorCodes.isNotEmpty) {
          _baseCode = _selectorCodes.contains('USD')
              ? 'USD'
              : _selectorCodes.first;
        }
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorText = 'Не удалось загрузить курсы. Попробуй обновить.';
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

  double _convertTo(String targetCode) {
    final baseRate = _rates[_baseCode];
    final targetRate = _rates[targetCode];
    if (baseRate == null || targetRate == null || baseRate == 0) return 0;
    return (_parseAmount() / baseRate) * targetRate;
  }

  String _format(double value) => value.toStringAsFixed(2).replaceAll('.', ',');

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
      title: 'Конвертер валют',
      subtitle:
          'Введи сумму и выбери валюту',
      appBarActions: [
        Padding(
          padding: const EdgeInsets.only(right: 4),
          child: IconButton(
            tooltip: 'Настройки',
            onPressed: () async {
              final updated = await Navigator.of(context).push<CurrencyUiConfig>(
                MaterialPageRoute(builder: (_) => const SettingsPage()),
              );
              if (!mounted) return;
              if (updated != null) {
                setState(() {
                  _currencyOrder = List<String>.from(updated.fullOrder);
                  _enabledCodes = Set<String>.from(updated.enabled);
                });
                _ensureBaseInSelector();
              } else {
                await _reloadEnabledFromPrefs();
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
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
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
                                  height: 1.25,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF1F2937),
                                ),
                              ),
                              Text(
                                code,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 14,
                                  height: 1.25,
                                  color: Color(0xFF6B7280),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          _format(_convertTo(code)),
                          style: const TextStyle(
                            fontSize: 28,
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
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF020617),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: _isLoading ? null : _loadRates,
              child: const Text('Обновить курсы'),
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
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
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
                    height: 14 * 1.25,
                    width: 168,
                    decoration: BoxDecoration(
                      color: _bone,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Container(
                    height: 14 * 1.25,
                    width: 52,
                    decoration: BoxDecoration(
                      color: _bone,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 96,
              height: 28,
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
