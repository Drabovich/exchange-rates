import 'dart:async';

import 'package:exchange_rates/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:exchange_rates/pages/home_page.dart';
import 'package:exchange_rates/pages/settings_page.dart';

/// Без растягивания контента при overscroll (Android stretch) и без сильного bounce.
class _NoStretchScrollBehavior extends MaterialScrollBehavior {
  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const ClampingScrollPhysics();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ),
  );
  runApp(const ExchangeRatesApp());
}

class ExchangeRatesApp extends StatefulWidget {
  const ExchangeRatesApp({super.key});

  @override
  State<ExchangeRatesApp> createState() => _ExchangeRatesAppState();
}

class _ExchangeRatesAppState extends State<ExchangeRatesApp> {
  bool _showHome = false;

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(milliseconds: 4800), () {
      if (!mounted) return;
      setState(() {
        _showHome = true;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Курсы валют',
      scrollBehavior: _NoStretchScrollBehavior(),
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF3B82F6)),
        useMaterial3: true,
      ),
      home: AnimatedSwitcher(
        duration: const Duration(milliseconds: 480),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        child: _showHome
            ? const HomePage(key: ValueKey('home'))
            : const AppSplashPage(key: ValueKey('splash')),
      ),
      routes: {
        AppRoutes.settings: (context) => const SettingsPage(),
      },
      debugShowCheckedModeBanner: false,
    );
  }
}

class AppSplashPage extends StatefulWidget {
  const AppSplashPage({super.key});

  @override
  State<AppSplashPage> createState() => _AppSplashPageState();
}

class _AppSplashPageState extends State<AppSplashPage>
    with TickerProviderStateMixin {
  static const _line1 = 'Люблю своего';
  static const _line2 = 'Ангела';
  static const _pulseCount = 4;

  late final AnimationController _lettersController;
  late final AnimationController _heartFadeController;
  late final AnimationController _heartBeatController;

  late final Animation<double> _heartFade;
  late final Animation<double> _heartBeat;

  @override
  void initState() {
    super.initState();

    final letterCount = _line1.length + _line2.length;
    _lettersController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 90 * letterCount + 200),
    );

    _heartFadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 480),
    );
    _heartFade = CurvedAnimation(
      parent: _heartFadeController,
      curve: Curves.easeOutCubic,
    );

    // Плавные удары: каждый цикл ~700ms.
    _heartBeatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700 * _pulseCount),
    );

    _heartBeat = TweenSequence<double>([
      for (var i = 0; i < _pulseCount; i++) ...[
        TweenSequenceItem(
          tween: Tween(begin: 1.0, end: 1.16)
              .chain(CurveTween(curve: Curves.easeOutCubic)),
          weight: 22,
        ),
        TweenSequenceItem(
          tween: Tween(begin: 1.16, end: 1.0)
              .chain(CurveTween(curve: Curves.easeInOutCubic)),
          weight: 28,
        ),
        TweenSequenceItem(
          tween: Tween(begin: 1.0, end: 1.08)
              .chain(CurveTween(curve: Curves.easeOutCubic)),
          weight: 16,
        ),
        TweenSequenceItem(
          tween: Tween(begin: 1.08, end: 1.0)
              .chain(CurveTween(curve: Curves.easeInOutCubic)),
          weight: 22,
        ),
        TweenSequenceItem(
          tween: ConstantTween(1.0),
          weight: 12,
        ),
      ],
    ]).animate(_heartBeatController);

    unawaited(_runSequence());
  }

  Future<void> _runSequence() async {
    await _lettersController.forward();
    if (!mounted) return;
    await _heartFadeController.forward();
    if (!mounted) return;
    await _heartBeatController.forward();
  }

  @override
  void dispose() {
    _lettersController.dispose();
    _heartFadeController.dispose();
    _heartBeatController.dispose();
    super.dispose();
  }

  double _letterProgress(int globalIndex, int total) {
    final start = globalIndex / (total + 1.5);
    final end = (globalIndex + 2.2) / (total + 1.5);
    final t = ((_lettersController.value - start) / (end - start))
        .clamp(0.0, 1.0);
    return Curves.easeOutCubic.transform(t);
  }

  Widget _animatedLine({
    required String text,
    required TextStyle style,
    required int indexOffset,
    required int totalLetters,
  }) {
    return AnimatedBuilder(
      animation: _lettersController,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < text.length; i++)
              Builder(
                builder: (context) {
                  final t = _letterProgress(indexOffset + i, totalLetters);
                  final ch = text[i];
                  return Opacity(
                    opacity: t,
                    child: Transform.translate(
                      offset: Offset(0, (1 - t) * 14),
                      child: Transform.scale(
                        scale: 0.92 + 0.08 * t,
                        child: Text(
                          ch,
                          style: style,
                        ),
                      ),
                    ),
                  );
                },
              ),
          ],
        );
      },
    );
  }

  List<Widget> _rippleRings() {
    final v = _heartBeatController.value;
    final fade = _heartFade.value;
    if (fade <= 0) return const [];

    final rings = <Widget>[];
    for (var beat = 0; beat < _pulseCount; beat++) {
      final beatStart = beat / _pulseCount;
      final beatEnd = (beat + 1) / _pulseCount;
      if (v < beatStart || v > beatEnd) continue;

      final local = (v - beatStart) / (beatEnd - beatStart);
      // Кольца уходят на фазе удара и растворяются.
      for (var ring = 0; ring < 2; ring++) {
        final delay = ring * 0.12;
        final raw = ((local - delay) / 0.7).clamp(0.0, 1.0);
        if (raw <= 0) continue;
        final t = Curves.easeOutCubic.transform(raw);
        final opacity = (1 - t) * fade * (ring == 0 ? 0.5 : 0.32);
        if (opacity <= 0.01) continue;

        rings.add(
          Transform.scale(
            scale: 0.55 + t * (1.55 + ring * 0.35),
            child: Opacity(
              opacity: opacity,
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFFE11D48),
                    width: 1.6 - t * 0.6,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFE11D48).withValues(
                        alpha: opacity * 0.35,
                      ),
                      blurRadius: 12 + t * 18,
                      spreadRadius: t * 2,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }
    }
    return rings;
  }

  @override
  Widget build(BuildContext context) {
    const totalLetters = _line1.length + _line2.length;

    const line1Style = TextStyle(
      fontSize: 22,
      height: 1.25,
      letterSpacing: 1.6,
      fontWeight: FontWeight.w400,
      color: Color(0xFF64748B),
    );
    const line2Style = TextStyle(
      fontSize: 52,
      height: 1.05,
      letterSpacing: 1.0,
      fontWeight: FontWeight.w700,
      color: Color(0xFF1E293B),
    );

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFFFF7F8),
                  Color(0xFFF3F0F4),
                  Color(0xFFE8EEF6),
                ],
                stops: [0.0, 0.45, 1.0],
              ),
            ),
          ),
          Positioned(
            top: -80,
            right: -60,
            child: _GlowOrb(
              size: 260,
              color: const Color(0xFFFFC9D4).withValues(alpha: 0.45),
            ),
          ),
          Positioned(
            bottom: -40,
            left: -50,
            child: _GlowOrb(
              size: 220,
              color: const Color(0xFFC7D7F0).withValues(alpha: 0.4),
            ),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 36),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _animatedLine(
                    text: _line1,
                    style: line1Style,
                    indexOffset: 0,
                    totalLetters: totalLetters,
                  ),
                  const SizedBox(height: 12),
                  _animatedLine(
                    text: _line2,
                    style: line2Style,
                    indexOffset: _line1.length,
                    totalLetters: totalLetters,
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: 168,
                    height: 168,
                    child: AnimatedBuilder(
                      animation: Listenable.merge([
                        _heartFadeController,
                        _heartBeatController,
                      ]),
                      builder: (context, _) {
                        return Stack(
                          alignment: Alignment.center,
                          children: [
                            ..._rippleRings(),
                            // Мягкое свечение под сердцем в такт.
                            Opacity(
                              opacity: ((_heartBeat.value - 1.0) / 0.16)
                                      .clamp(0.0, 1.0) *
                                  _heartFade.value *
                                  0.55,
                              child: Container(
                                width: 54,
                                height: 54,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: RadialGradient(
                                    colors: [
                                      const Color(0xFFE11D48)
                                          .withValues(alpha: 0.35),
                                      const Color(0xFFE11D48)
                                          .withValues(alpha: 0),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            FadeTransition(
                              opacity: _heartFade,
                              child: ScaleTransition(
                                scale: _heartBeat,
                                child: const Icon(
                                  Icons.favorite_rounded,
                                  size: 40,
                                  color: Color(0xFFE11D48),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color,
              color.withValues(alpha: 0),
            ],
          ),
        ),
      ),
    );
  }
}
