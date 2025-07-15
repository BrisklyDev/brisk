import 'package:brisk/provider/theme_provider.dart';
import 'package:brisk/widget/base/default_tooltip.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class SettingsGroup extends StatelessWidget {
  final double width;
  final String title;
  final List<Widget> children;
  final double? containerWidth;
  final double? containerHeight;
  final String? tooltipMessage;

  const SettingsGroup({
    super.key,
    this.width = 650,
    required this.children,
    this.title = "",
    this.containerWidth,
    this.containerHeight,
    this.tooltipMessage,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context).activeTheme;
    final size = MediaQuery.of(context).size;
    return SizedBox(
      width: resolveWidth(size),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title.isNotEmpty)
            Row(
              children: [
                Padding(
                  padding: const EdgeInsets.all(10.0),
                  child: Text(
                    title,
                    style: TextStyle(
                      color: theme.settingTheme.pageTheme.groupTitleTextColor,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (tooltipMessage != null)
                  DefaultTooltip(
                    message: tooltipMessage!,
                    child: Icon(
                      size: 19,
                      Icons.info,
                      color: theme.widgetTheme.tooltipIconColor,
                    ),
                  ),
              ],
            ),
          Container(
            width: containerWidth,
            // Don't set height unless explicitly passed
            height: containerHeight,
            decoration: BoxDecoration(
              color: theme.settingTheme.pageTheme.groupBackgroundColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: children,
              ),
            ),
          )
        ],
      ),
    );
  }

  double resolveWidth(Size size) {
    if (size.width < 809) {
      return size.width * 0.85;
    }
    return width;
  }
}
