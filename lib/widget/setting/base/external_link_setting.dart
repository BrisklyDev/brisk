import 'package:brisk/provider/theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class ExternalLinkSetting extends StatelessWidget {
  final String title;
  final String linkText;
  final VoidCallback onLinkPressed;
  final String? tooltipMessage;
  final double titleWidth;
  final double? width;
  final Widget? customIcon;

  const ExternalLinkSetting({
    super.key,
    required this.title,
    required this.linkText,
    required this.onLinkPressed,
    this.tooltipMessage,
    this.titleWidth = 100,
    this.width,
    this.customIcon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context).activeTheme;
    return Row(
      children: [
        SizedBox(
          width: width ?? MediaQuery.of(context).size.width * 0.5 * 0.5,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                title,
                style: TextStyle(
                  overflow: TextOverflow.ellipsis,
                  color: theme.settingTheme.pageTheme.titleTextColor,
                  fontWeight: theme.fontWeight,
                  fontSize: 14,
                ),
              ),
              if (tooltipMessage != null)
                Padding(
                  padding: const EdgeInsets.only(left: 4.0),
                  child: Tooltip(
                    message: tooltipMessage!,
                    child: Icon(
                      Icons.info,
                      size: 19,
                      color: theme.widgetTheme.tooltipIconColor,
                    ),
                    decoration: BoxDecoration(
                      color: Color.fromRGBO(33, 33, 33, 1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    textStyle: const TextStyle(color: Colors.white),
                  ),
                ),
            ],
          ),
        ),
        const Spacer(),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            IconButton(
              onPressed: onLinkPressed,
              icon: customIcon ??
                  const Icon(Icons.launch_rounded, color: Colors.white),
            ),
            Text(
              linkText,
              style: TextStyle(
                color: theme.settingTheme.pageTheme.titleTextColor,
                fontWeight: theme.fontWeight,
                fontSize: 11,
              ),
            ),
          ],
        )
      ],
    );
  }
}
