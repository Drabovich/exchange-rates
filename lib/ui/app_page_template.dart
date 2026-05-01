import 'package:flutter/material.dart';

class AppPageTemplate extends StatelessWidget {
  const AppPageTemplate({
    super.key,
    required this.title,
    this.subtitle,
    required this.child,
    this.showBackButton = false,
    this.appBarActions,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final bool showBackButton;
  final List<Widget>? appBarActions;

  PreferredSizeWidget? _appBar(BuildContext context) {
    final hasActions = appBarActions != null && appBarActions!.isNotEmpty;
    if (!showBackButton && !hasActions) return null;

    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      automaticallyImplyLeading: showBackButton,
      actions: hasActions ? appBarActions : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEFF2F6),
      appBar: _appBar(context),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          padding: const EdgeInsets.all(12),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F8FA),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFDDE3EA)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1F2937),
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    subtitle!,
                    style: const TextStyle(
                      fontSize: 18,
                      height: 1.35,
                      color: Color(0xFF4B5563),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                child,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
