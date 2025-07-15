import 'package:brisk/provider/theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class InfoDialog extends StatelessWidget {
  final Widget titleIcon;
  final Color titleIconBackgroundColor;
  final String titleText;

  const InfoDialog({
    super.key,
    required this.titleIcon,
    required this.titleIconBackgroundColor,
    required this.titleText,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context).activeTheme;
    return AlertDialog(
      contentPadding: EdgeInsets.zero,
      insetPadding: EdgeInsets.zero,
      actionsPadding: EdgeInsets.zero,
      iconPadding: EdgeInsets.zero,
      buttonPadding: EdgeInsets.zero,
      titlePadding: EdgeInsets.zero,
      backgroundColor: theme.alertDialogTheme.backgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      title: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            Container(
              width: 35,
              height: 35,
              decoration: BoxDecoration(
                color: titleIconBackgroundColor,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: titleIcon,
              ),
            ),
            SizedBox(width: 10),
            Padding(
              padding: const EdgeInsets.only(right: 10.0),
              child: Text(
                titleText,
                style: TextStyle(fontSize: 18, color: theme.textColor),
              ),
            ),
          ],
        ),
      ),
      content: Container(
        height: 0,
        width: 200,
      ),
    );
  }
}
