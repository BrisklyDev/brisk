import 'package:brisk/l10n/app_localizations.dart';
import 'package:brisk/provider/theme_provider.dart';
import 'package:brisk/widget/base/rounded_outlined_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:provider/provider.dart';

class FileInfoLoader extends StatelessWidget {
  final VoidCallback onCancelPressed;
  final String? message;

  const FileInfoLoader({
    super.key,
    required this.onCancelPressed,
    this.message,
  });

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
      content: SizedBox(
        width: 250,
        height: 60,
        child: Column(
          children: [
            SpinKitRing(color: Colors.blueAccent, size: 30),
            const SizedBox(height: 10),
            Text(
              message ?? loc.retrievingFileInformation,
              style: TextStyle(
                  color: theme.textColor,
                  fontSize: 15,
                  fontWeight: theme.fontWeight),
            ),
          ],
        ),
      ),
      actions: [
        RoundedOutlinedButton(
          text: loc.btn_cancel,
          textColor: Colors.white,
          backgroundColor: Colors.red,
          borderColor: Colors.red,
          onPressed: onCancelPressed,
        )
      ],
    );
  }
}
