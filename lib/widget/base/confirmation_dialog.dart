import 'package:brisk/l10n/app_localizations.dart';
import 'package:brisk/provider/theme_provider.dart';
import 'package:brisk/widget/base/rounded_outlined_button.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class ConfirmationDialog extends StatelessWidget {
  final String title;
  final String description;
  final VoidCallback onConfirmPressed;
  final double confirmButtonWidth;
  final String confirmButtonText;
  final double width;

  const ConfirmationDialog({
    super.key,
    required this.title,
    required this.description,
    required this.onConfirmPressed,
    required this.confirmButtonWidth,
    required this.confirmButtonText,
    this.width = 400,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context).activeTheme;
    final loc = AppLocalizations.of(context)!;
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      backgroundColor: theme.alertDialogTheme.backgroundColor,
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
            title,
            style: TextStyle(
                color: theme.textColor,
                fontWeight: FontWeight.bold,
                fontSize: 20),
          ),
        ],
      ),
      content: Container(
        width: width,
        child: Text(
          description,
          style: TextStyle(fontSize: 17, color: theme.textColor),
        ),
      ),
      actions: [
        RoundedOutlinedButton.fromButtonColor(
          theme.alertDialogTheme.deleteCancelColor,
          text: loc.btn_cancel,
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        RoundedOutlinedButton.fromButtonColor(
          theme.alertDialogTheme.acceptButtonColor,
          text: confirmButtonText,
          width: confirmButtonWidth,
          onPressed: () {
            Navigator.of(context).pop();
            onConfirmPressed();
          },
        ),
      ],
    );
  }
}
