import 'package:flutter/material.dart';

class AppPageTemplate extends StatelessWidget {
  const AppPageTemplate({
    super.key,
    required this.title,
    this.subtitle,
    required this.child,
    this.showBackButton = false,
    this.headerActions,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final bool showBackButton;
  final List<Widget>? headerActions;

  static ButtonStyle get _iconButtonStyle => IconButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF334155),
        elevation: 0,
        shadowColor: Colors.transparent,
        side: const BorderSide(color: Color(0xFFDCE3EA)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      );

  List<Widget> _buildHeaderActions(BuildContext context) {
    final actions = <Widget>[];
    if (showBackButton) {
      actions.add(
        IconButton(
          tooltip: 'Назад',
          onPressed: () => Navigator.of(context).maybePop(),
          style: _iconButtonStyle,
          icon: const Icon(Icons.arrow_back_rounded, size: 24),
        ),
      );
    }
    if (headerActions != null) {
      for (final action in headerActions!) {
        actions.add(action);
      }
    }
    return actions;
  }

  @override
  Widget build(BuildContext context) {
    final actions = _buildHeaderActions(context);

    return Scaffold(
      backgroundColor: const Color(0xFFEFF2F6),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F8FA),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFDDE3EA)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
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
                            ],
                          ),
                        ),
                        if (actions.isNotEmpty) ...[
                          const SizedBox(width: 12),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              for (var i = 0; i < actions.length; i++) ...[
                                if (i > 0) const SizedBox(width: 8),
                                actions[i],
                              ],
                            ],
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 24),
                    child,
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
