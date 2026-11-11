import 'package:brisk/l10n/app_localizations.dart';
import 'package:brisk/provider/theme_provider.dart';
import 'package:brisk/widget/base/rounded_outlined_button.dart';
import 'package:brisk/widget/base/scrollable_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_emoji/flutter_emoji.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';

/// Shown on the first launch after Brisk was updated, with the release notes of the new
/// version. Same layout as [UpdateAvailableDialog].
class BriskChangeLogDialog extends StatelessWidget {
  final String updatedVersion;
  final String changeLog;

  static const _notesHeight = 340.0;

  const BriskChangeLogDialog({
    super.key,
    required this.updatedVersion,
    required this.changeLog,
  });

  @override
  Widget build(BuildContext context) {
    final theme =
        Provider.of<ThemeProvider>(context, listen: false).activeTheme;
    final size = MediaQuery.of(context).size;
    final loc = AppLocalizations.of(context)!;
    final accent = theme.alertDialogTheme.acceptButtonColor.backgroundColor;
    return ScrollableDialog(
      // The buttons are outside of this height: release notes panel + 15px bottom gap
      height: _notesHeight + 15,
      width: 500,
      scrollviewHeight: _notesHeight,
      scrollViewWidth: 500,
      scrollButtonVisible: size.height < _notesHeight + 170,
      backgroundColor: theme.alertDialogTheme.backgroundColor,
      title: Padding(
        padding: const EdgeInsets.all(15),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.alertDialogTheme.surfaceColor,
              ),
              child: Icon(
                Icons.rocket_launch_rounded,
                size: 24,
                color: theme.widgetTheme.iconColor,
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  loc.briskUpdated,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: theme.textColor,
                  ),
                ),
                const SizedBox(height: 4),
                // Version as a small pill
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    "v$updatedVersion",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: theme.textColor,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      content: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 15),
        child: Container(
          width: 500,
          height: _notesHeight,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: theme.alertDialogTheme.surfaceColor,
          ),
          child: Markdown(
            data: EmojiParser().emojify(_withoutChangelogHeader(changeLog)),
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
            styleSheet: MarkdownStyleSheet(
              // Body slightly faded so headings and bold feature names stand out
              p: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: theme.textColor.withValues(alpha: 0.85),
              ),
              h1: TextStyle(
                fontSize: 18,
                color: theme.textColor,
                fontWeight: FontWeight.bold,
              ),
              h2: TextStyle(
                fontSize: 16,
                height: 2.2,
                color: theme.textColor,
                fontWeight: FontWeight.bold,
              ),
              h3: TextStyle(
                fontSize: 15,
                color: theme.textColor,
                fontWeight: FontWeight.w600,
              ),
              strong: TextStyle(
                color: theme.textColor,
                fontWeight: FontWeight.bold,
              ),
              listBullet: TextStyle(fontSize: 14, height: 1.5, color: accent),
              listIndent: 18,
              blockSpacing: 8,
              code: TextStyle(
                fontSize: 13,
                color: theme.textColor,
                backgroundColor: theme.textColor.withValues(alpha: 0.08),
              ),
              horizontalRuleDecoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: theme.textColor.withValues(alpha: 0.12),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      buttons: [
        RoundedOutlinedButton.fromButtonColor(
          theme.alertDialogTheme.acceptButtonColor,
          onPressed: () => Navigator.of(context).pop(),
          text: loc.btn_gotIt,
        ),
      ],
    );
  }

  /// The release notes start with a "# Changelog" heading, which is redundant in the dialog.
  static String _withoutChangelogHeader(String changeLog) {
    final lines = changeLog.trimLeft().split('\n');
    if (lines.isNotEmpty && lines.first.contains("Changelog")) {
      lines.removeAt(0);
    }
    return lines.join('\n').trim();
  }
}
