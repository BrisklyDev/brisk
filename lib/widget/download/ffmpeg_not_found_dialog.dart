import 'package:brisk/db/hive_util.dart';
import 'package:brisk/l10n/app_localizations.dart';
import 'package:brisk/provider/theme_provider.dart';
import 'package:brisk/util/ffmpeg.dart';
import 'package:brisk/widget/base/rounded_outlined_button.dart';
import 'package:brisk/widget/base/scrollable_dialog.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class FFmpegNotFoundDialog extends StatelessWidget {
  const FFmpegNotFoundDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context).activeTheme;
    final loc = AppLocalizations.of(context)!;
    return ScrollableDialog(
      width: 550,
      height: 240,
      scrollviewHeight: 300,
      scrollButtonVisible: false,
      backgroundColor: theme.alertDialogTheme.backgroundColor,
      title: Padding(
        padding: const EdgeInsets.all(15),
        child: Row(
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
              loc.ffmpeg_notFound_title,
              style: TextStyle(
                color: theme.textColor,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
          ],
        ),
      ),
      content: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Text(
              loc.ffmpeg_notFound_description,
              style: TextStyle(
                color: theme.textColor,
              ),
            ),
            Text(
              loc.ffmpeg_notFound_descriptionHint,
              style: TextStyle(
                color: theme.textHintColor,
              ),
            ),
          ],
        ),
      ),
      buttons: [
        RoundedOutlinedButton.fromButtonColor(
          theme.alertDialogTheme.declineButtonColor,
          onPressed: () {
            final warningIgnore = HiveUtil.instance.generalDataBox.values
                .where(
                  (element) => element.fieldName == 'ffmpegWarningIgnore',
                )
                .first;
            warningIgnore.value = true;
            warningIgnore.save();
            Navigator.of(context).pop();
          },
          text: loc.btn_installLater,
        ),
        const SizedBox(width: 10),
        RoundedOutlinedButton.fromButtonColor(
          theme.alertDialogTheme.acceptButtonColor,
          onPressed: () {
            Navigator.of(context).pop();
            FFmpeg.install(context);
          },
          text: loc.btn_installAutomatically,
        ),
      ],
    );
  }
}
