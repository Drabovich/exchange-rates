import 'dart:async';
import 'dart:ui' show lerpDouble;

import 'package:exchange_rates/primary_currencies.dart';
import 'package:exchange_rates/ui/app_page_template.dart';
import 'package:flutter/material.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  List<String> _order = List<String>.from(kPrimaryCurrencyCodes);
  Set<String> _enabled = Set<String>.from(kDefaultEnabledCurrencyCodes);
  bool _loading = true;
  int? _draggingIndex;
  Future<void> _persistChain = Future.value();

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final config = await loadCurrencyUiConfig();
    if (!mounted) return;
    setState(() {
      _order = List<String>.from(config.fullOrder);
      _enabled = Set<String>.from(config.enabled);
      _loading = false;
    });
  }

  Future<void> _persist() async {
    final snapshot = CurrencyUiConfig(
      fullOrder: List<String>.from(_order),
      enabled: Set<String>.from(_enabled),
    );
    _persistChain = _persistChain.then((_) => saveCurrencyUiConfig(snapshot));
    await _persistChain;
  }

  Future<void> _toggle(String code, bool enabled) async {
    final next = Set<String>.from(_enabled);
    if (enabled) {
      next.add(code);
    } else {
      next.remove(code);
    }
    setState(() => _enabled = next);
    await _persist();
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      final code = _order.removeAt(oldIndex);
      _order.insert(newIndex, code);
      _draggingIndex = null;
    });
    unawaited(_persist());
  }

  Widget _reorderProxyDecorator(
    Widget child,
    int index,
    Animation<double> animation,
    double listWidth,
  ) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final t = Curves.easeOut.transform(animation.value);
        final blur = lerpDouble(6, 18, t)!;
        final dy = lerpDouble(2, 8, t)!;
        final a = lerpDouble(0.07, 0.18, t)!;
        return Transform.translate(
          offset: Offset(0, lerpDouble(0, -4, t)!),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Color(0xFF0F172A).withValues(alpha: a),
                  blurRadius: blur,
                  offset: Offset(0, dy),
                  spreadRadius: lerpDouble(0, 0.5, t)!,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Material(
                color: Colors.transparent,
                shadowColor: Colors.transparent,
                child: SizedBox(
                  width: listWidth,
                  child: child,
                ),
              ),
            ),
          ),
        );
      },
      child: child,
    );
  }

  Future<void> _waitForPendingSave() async {
    await _persistChain;
  }

  Future<void> _onResetToFreshInstall() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Сброс настроек приложения'),
          content: const Text(
            'Вы уверены, что хотите сбросить настройки приложения до заводских?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Отмена'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF020617),
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Сбросить'),
            ),
          ],
        );
      },
    );
    if (ok != true || !mounted) return;
    await _waitForPendingSave();
    await resetAppPreferencesToFreshInstall();
    if (!mounted) return;
    setState(() {
      _order = List<String>.from(kPrimaryCurrencyCodes);
      _enabled = Set<String>.from(kDefaultEnabledCurrencyCodes);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Настройки сброшены')),
    );
  }

  Future<void> _leaveWithResult() async {
    await _waitForPendingSave();
    if (!mounted) return;
    Navigator.of(context).pop<CurrencyUiConfig>(
      CurrencyUiConfig(
        fullOrder: List<String>.from(_order),
        enabled: Set<String>.from(_enabled),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        unawaited(_leaveWithResult());
      },
      child: AppPageTemplate(
        title: 'Настройки',
        subtitle:
            'Отметь валюты для главной. Порядок меняется перетаскиванием за значок слева и сохраняется',
        showBackButton: true,
        child: _loading
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: CircularProgressIndicator(),
                ),
              )
            : CheckboxTheme(
                data: CheckboxThemeData(
                  fillColor: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.selected)) {
                      return const Color(0xFF020617);
                    }
                    if (states.contains(WidgetState.disabled)) {
                      return const Color(0xFFE2E8F0);
                    }
                    return Colors.white;
                  }),
                  checkColor: WidgetStateProperty.all(Colors.white),
                  side: const BorderSide(color: Color(0xFF94A3B8)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final listW = constraints.maxWidth;
                        return ReorderableListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          buildDefaultDragHandles: false,
                          itemCount: _order.length,
                          onReorder: _onReorder,
                          onReorderStart: (index) {
                            setState(() => _draggingIndex = index);
                          },
                          onReorderEnd: (_) {
                            setState(() => _draggingIndex = null);
                          },
                          proxyDecorator: (child, index, anim) =>
                              _reorderProxyDecorator(
                                child,
                                index,
                                anim,
                                listW,
                              ),
                          itemBuilder: (context, index) {
                            final code = _order[index];
                            final grabbed = _draggingIndex == index;
                            return Material(
                              key: ValueKey<String>(code),
                              color: Colors.transparent,
                              shadowColor: Colors.transparent,
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                padding:
                                    const EdgeInsets.fromLTRB(8, 8, 4, 8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: const Color(0xFFDCE3ED),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    ReorderableDragStartListener(
                                      index: index,
                                      child: _SettingsDragGrip(
                                        grabbed: grabbed,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            currencyDisplayName(code),
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF1F2937),
                                            ),
                                          ),
                                          Text(
                                            code,
                                            style: const TextStyle(
                                              color: Color(0xFF6B7280),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Checkbox(
                                      value: _enabled.contains(code),
                                      onChanged: (v) {
                                        if (v == null) return;
                                        unawaited(_toggle(code, v));
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 8),
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
                        onPressed: _loading
                            ? null
                            : () => unawaited(_onResetToFreshInstall()),
                        child: const Text('Сбросить настройки'),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

/// Ручка перетаскивания: три полоски «как бургер», в тон интерфейсу.
class _SettingsDragGrip extends StatelessWidget {
  const _SettingsDragGrip({this.grabbed = false});

  final bool grabbed;

  static const _stripeColorIdle = Color(0xFF94A3B8);
  static const _stripeColorGrabbed = Color(0xFF475569);

  @override
  Widget build(BuildContext context) {
    final color = grabbed ? _stripeColorGrabbed : _stripeColorIdle;
    final w = grabbed ? 24.0 : 22.0;
    final h = grabbed ? 3.0 : 2.5;
    final gap = grabbed ? 3.0 : 4.0;

    return Semantics(
      label: 'Изменить порядок',
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < 3; i++) ...[
                if (i > 0) SizedBox(height: gap),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 140),
                  curve: Curves.easeOutCubic,
                  width: w,
                  height: h,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(h / 2),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
