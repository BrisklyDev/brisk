import 'package:brisk/provider/theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class DefaultTooltip extends StatelessWidget {
  final String message;
  final Widget child;

  const DefaultTooltip({super.key, required this.message, required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context)
        .activeTheme
        .widgetTheme
        .toolTipColor;
    return Tooltip(
      message: message,
      textStyle: TextStyle(color: theme.textColor),
      decoration: BoxDecoration(
        color: theme.backgroundColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: theme.borderColor),
      ),
      child: child,
    );
  }
}
