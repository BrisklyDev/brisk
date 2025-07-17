import 'package:brisk/l10n/app_localizations.dart';
import 'package:brisk/provider/theme_provider.dart';
import 'package:brisk/widget/base/rounded_outlined_button.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class AppExitDialog extends StatefulWidget {
  final Function(bool) onExitPressed;
  final Function(bool) onMinimizeToTrayPressed;

  const AppExitDialog({
    super.key,
    required this.onExitPressed,
    required this.onMinimizeToTrayPressed,
  });

  @override
  State<AppExitDialog> createState() => _AppExitDialogState();
}

class _AppExitDialogState extends State<AppExitDialog> {
  bool rememberChecked = false;

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context).activeTheme;
    final loc = AppLocalizations.of(context)!;
    return AlertDialog(
      backgroundColor: theme.alertDialogTheme.backgroundColor,
      surfaceTintColor: theme.alertDialogTheme.backgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      title: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: const BoxDecoration(
              color: Color.fromRGBO(245, 158, 11, 0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Align(
                alignment: const Alignment(0, -0.16),
                child: const Icon(
                  Icons.warning_rounded,
                  color: Color.fromRGBO(245, 158, 11, 1),
                  size: 35,
                ),
              ),
            ),
          ),
          SizedBox(width: 10),
          Text(
            loc.chooseAction,
            style: TextStyle(
              color: theme.textColor,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
        ],
      ),
      content: Container(
        height: 270,
        width: 500,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Text(
              loc.appChooseActionDescription,
              style: TextStyle(
                color: theme.textHintColor,
              ),
            ),
            const SizedBox(height: 20),
            Column(
              children: [
                RoundedOutlinedButton(
                  mainAxisAlignment: MainAxisAlignment.start,
                  text: loc.btn_exitApplication,
                  mainAxisSize: MainAxisSize.max,
                  iconHoverColor: theme.widgetTheme.iconColor,
                  icon: Icons.power_settings_new_rounded,
                  textColor: theme.textColor,
                  iconColor: theme.widgetTheme.iconColor,
                  borderColor: Colors.transparent,
                  backgroundColor: theme.alertDialogTheme.surfaceColor,
                  hoverBackgroundColor: Color.fromRGBO(220, 38, 38, 1),
                  height: 45,
                  width: 500,
                  onPressed: () {
                    Navigator.of(context).pop();
                    widget.onExitPressed(rememberChecked);
                  },
                ),
                SizedBox(height: 10),
                RoundedOutlinedButton(
                  mainAxisAlignment: MainAxisAlignment.start,
                  mainAxisSize: MainAxisSize.max,
                  text: loc.btn_minimizeToTray,
                  height: 45,
                  icon: Icons.minimize_rounded,
                  iconColor: theme.widgetTheme.iconColor,
                  textColor: theme.textColor,
                  borderColor: Colors.transparent,
                  hoverBackgroundColor: Color.fromRGBO(53, 89, 143, 1),
                  iconHoverColor: theme.widgetTheme.iconColor,
                  backgroundColor: theme.alertDialogTheme.surfaceColor,
                  width: 500,
                  onPressed: () {
                    Navigator.of(context).pop();
                    widget.onMinimizeToTrayPressed(rememberChecked);
                  },
                ),
                SizedBox(height: 10),
                RoundedOutlinedButton(
                  mainAxisAlignment: MainAxisAlignment.start,
                  mainAxisSize: MainAxisSize.max,
                  text: loc.btn_cancel,
                  height: 45,
                  icon: Icons.close_rounded,
                  iconColor: theme.widgetTheme.iconColor,
                  textColor: theme.textColor,
                  borderColor: Colors.transparent,
                  backgroundColor: theme.alertDialogTheme.surfaceColor,
                  iconHoverColor: theme.widgetTheme.iconColor,
                  hoverBackgroundColor:
                      theme.alertDialogTheme.cancelColor.hoverBackgroundColor,
                  hoverTextColor: theme.textColor,
                  width: 500,
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
                SizedBox(height: 10),
                Row(
                  children: [
                    Checkbox(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(2.0),
                      ),
                      side: WidgetStateBorderSide.resolveWith(
                        (states) => BorderSide(width: 1.0, color: Colors.grey),
                      ),
                      activeColor: Colors.blueGrey,
                      value: rememberChecked,
                      onChanged: (value) => setState(
                        () => rememberChecked = value!,
                      ),
                    ),
                    Text(
                      loc.rememberThisDecision,
                      style: TextStyle(color: theme.textColor),
                    ),
                  ],
                )
              ],
            )
          ],
        ),
      ),
      actionsAlignment: MainAxisAlignment.center,
    );
  }
}
