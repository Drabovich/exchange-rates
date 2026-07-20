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
    Future<void>.delayed(const Duration(milliseconds: 2400), () {
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
  late final AnimationController _enterController;
  late final AnimationController _heartController;

  late final Animation<double> _fadeIn;
  late final Animation<Offset> _slideUp;
  late final Animation<double> _scaleIn;
  late final Animation<double> _heartBeat;

  @override
  void initState() {
    super.initState();

    _enterController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _heartController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _fadeIn = CurvedAnimation(
      parent: _enterController,
      curve: const Interval(0.0, 0.7, curve: Curves.easeOutCubic),
    );
    _slideUp = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _enterController,
        curve: const Interval(0.05, 0.85, curve: Curves.easeOutCubic),
      ),
    );
    _scaleIn = Tween<double>(begin: 0.96, end: 1).animate(
      CurvedAnimation(
        parent: _enterController,
        curve: const Interval(0.0, 0.8, curve: Curves.easeOutCubic),
      ),
    );

    // Мягкий «heartbeat»: чуть сильнее удар, затем пауза.
    _heartBeat = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 1.14)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 18,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.14, end: 1.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 16,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 1.08)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 14,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.08, end: 1.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 16,
      ),
      TweenSequenceItem(
        tween: ConstantTween(1.0),
        weight: 36,
      ),
    ]).animate(_heartController);

    _enterController.forward();
    Future<void>.delayed(const Duration(milliseconds: 450), () {
      if (!mounted) return;
      _heartController.repeat();
    });
  }

  @override
  void dispose() {
    _enterController.dispose();
    _heartController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
          // Мягкие световые пятна — атмосфера, без «карточки».
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
            child: FadeTransition(
              opacity: _fadeIn,
              child: SlideTransition(
                position: _slideUp,
                child: ScaleTransition(
                  scale: _scaleIn,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 36),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Люблю своего',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 22,
                            height: 1.25,
                            letterSpacing: 1.4,
                            fontWeight: FontWeight.w400,
                            color: const Color(0xFF64748B).withValues(alpha: 0.95),
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Ангела',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 48,
                            height: 1.05,
                            letterSpacing: 0.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 22),
                        ScaleTransition(
                          scale: _heartBeat,
                          child: const Icon(
                            Icons.favorite_rounded,
                            size: 36,
                            color: Color(0xFFE11D48),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
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
