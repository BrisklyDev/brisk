import 'package:brisk/provider/theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class ErrorDialog extends StatelessWidget {
  final String text;
  final String? description;
  final String? descriptionHint;
  final double width;
  final double height;
  final String? title;
  final double textHeight;
  final double textSpaceBetween;

  const ErrorDialog({
    super.key,
    this.text = '',
    this.width = 300,
    this.height = 60,
    this.title = null,
    this.textHeight = 90,
    this.description,
    this.descriptionHint,
    this.textSpaceBetween = 0,
  });

  @override
  Widget build(BuildContext context) {
    final theme =
        Provider.of<ThemeProvider>(context).activeTheme.alertDialogTheme;
    return AlertDialog(
      insetPadding: const EdgeInsets.all(10),
      backgroundColor: theme.backgroundColor,
      surfaceTintColor: theme.backgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      content: SizedBox(
        width: width,
        height: height,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: const BoxDecoration(
                    color: Color.fromRGBO(253, 12, 12, 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Align(
                      alignment: const Alignment(0, -0.16),
                      child: const Icon(
                        Icons.warning_rounded,
                        color: Colors.red,
                        size: 35,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                if (title != null)
                  Text(
                    title!,
                    style: TextStyle(
                      color: Colors.red,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
            SizedBox(
              height: height - 50,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    SizedBox(height: 10),
                    if (description != null)
                      Text(
                        description!,
                        style: TextStyle(color: theme.textColor),
                      ),
                    const SizedBox(height: 10),
                    if (descriptionHint != null)
                      Text(
                        descriptionHint!,
                        style: TextStyle(color: theme.textHintColor),
                      )
                  ],
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}
