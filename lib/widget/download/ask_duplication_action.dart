import 'package:brisk/l10n/app_localizations.dart';
import 'package:brisk/provider/theme_provider.dart';
import 'package:brisk/widget/base/rounded_outlined_button.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class AskDuplicationAction extends StatelessWidget {
  final bool fileDuplication;
  final VoidCallback onSkipPressed;
  final VoidCallback onCreateNewPressed;
  final VoidCallback onUpdateUrlPressed;

  const AskDuplicationAction({
    super.key,
    required this.fileDuplication,
    required this.onSkipPressed,
    required this.onCreateNewPressed,
    required this.onUpdateUrlPressed,
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
            loc.duplicateDownload_title,
            style: TextStyle(
              color: theme.alertDialogTheme.textColor,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
        ],
      ),
      content: Container(
        width: 400,
        child: Text(
          loc.duplicateDownload_description,
          style: TextStyle(fontSize: 17, color: theme.textColor),
        ),
      ),
      actions: [
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            RoundedOutlinedButton.fromButtonColor(
              theme.alertDialogTheme.declineButtonColor,
              text: loc.btn_cancel,
              onPressed: () => Navigator.of(context).pop(),
            ),
            const SizedBox(width: 5),
            RoundedOutlinedButton.fromButtonColor(
              theme.alertDialogTheme.secondaryMiscButtonColor,
              text: loc.btn_updateUrl,
              onPressed: onUpdateUrlPressed,
            ),
            const SizedBox(width: 5),
            RoundedOutlinedButton.fromButtonColor(
              theme.alertDialogTheme.acceptButtonColor,
              text: loc.btn_addNew,
              onPressed: onCreateNewPressed,
            ),
          ],
        )
      ],
    );
  }
}
