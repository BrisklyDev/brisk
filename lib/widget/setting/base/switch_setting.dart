import 'package:brisk/provider/theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class SwitchSetting extends StatelessWidget {
  final String text;
  final bool switchValue;
  final Function(bool value)? onChanged;

  const SwitchSetting(
      {super.key,
      required this.text,
      this.onChanged,
      required this.switchValue});

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context).activeTheme;
    final size = MediaQuery.of(context).size;
    return Row(
      children: [
        SizedBox(
          width: resolveWidth(size),
          child: Text(
            text,
            style: TextStyle(
              overflow: TextOverflow.clip,
              color: theme.settingTheme.pageTheme.titleTextColor,
              fontWeight: theme.fontWeight,
              fontSize: 14,
            ),
          ),
        ),
        const Spacer(),
        Switch(
          value: switchValue,
          onChanged: onChanged,
          inactiveTrackColor: theme.widgetTheme.switchColor.inactiveTrackColor,
          hoverColor: theme.widgetTheme.switchColor.hoverColor,
          activeColor: theme.widgetTheme.switchColor.activeColor,
          focusColor: theme.widgetTheme.switchColor.focusColor,
        ),
      ],
    );
  }

  double resolveWidth(Size size) {
    double width = 400;
    if (size.width < 849) {
      width = size.width * 0.4;
    }
    if (size.width < 698) {
      width = size.width * 0.3;
    }
    if (size.width < 558) {
      width = size.width * 0.25;
    }
    return width;
  }
}
