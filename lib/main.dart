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
    Future<void>.delayed(const Duration(milliseconds: 1800), () {
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
      home: _showHome ? const HomePage() : const AppSplashPage(),
      routes: {
        AppRoutes.settings: (context) => const SettingsPage(),
      },
      debugShowCheckedModeBanner: false,
    );
  }
}

class AppSplashPage extends StatelessWidget {
  const AppSplashPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFF8FAFF),
              Color(0xFFEAF0FB),
            ],
          ),
        ),
        child: Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 28),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE1E8F1)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x1A0F172A),
                  blurRadius: 30,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: const Text(
              'Люблю своего Ангела ❤️',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 30,
                height: 1.2,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E293B),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
