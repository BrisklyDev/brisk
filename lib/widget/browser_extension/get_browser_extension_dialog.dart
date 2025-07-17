import 'package:brisk/l10n/app_localizations.dart';
import 'package:brisk/provider/theme_provider.dart';
import 'package:brisk/theme/application_theme.dart';
import 'package:brisk/util/http_util.dart';
import 'package:brisk/widget/base/scrollable_dialog.dart';
import 'package:dartx/dartx.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher_string.dart';

import 'browser_extension_installation_guide_dialog.dart';

class GetBrowserExtensionDialog extends StatelessWidget {
  GetBrowserExtensionDialog({super.key});

  late ApplicationTheme theme;

  @override
  Widget build(BuildContext context) {
    theme = Provider.of<ThemeProvider>(context).activeTheme;
    final loc = AppLocalizations.of(context)!;
    return ScrollableDialog(
      width: 500,
      height: 260,
      scrollviewHeight: 300,
      backgroundColor: theme.alertDialogTheme.backgroundColor,
      scrollButtonVisible: false,
      buttons: [],
      title: Padding(
        padding: const EdgeInsets.all(15),
        child: Row(
          children: [
            Icon(Icons.extension, color: theme.widgetTheme.iconColor),
            const SizedBox(width: 10),
            Text(
              loc.installBrowserExtension_title,
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
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              loc.installTheBrowserExtension_description,
              style: TextStyle(
                color: theme.textColor,
                fontWeight: theme.fontWeight,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              loc.installTheBrowserExtension_description_subtitle,
              style: TextStyle(
                color: theme.textColor,
                // fontWeight: theme.fontWeight
              ),
            ),
            const SizedBox(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                browserIconButton(
                  "firefox",
                  () => launchUrlString(
                      "https://addons.mozilla.org/en-US/firefox/addon/brisk/"),
                ),
                const SizedBox(width: 25),
                browserIconButton(
                  "chrome",
                  () => onBrowserPressed(context, "chrome"),
                ),
                const SizedBox(width: 25),
                browserIconButton(
                  "edge",
                  () => onBrowserPressed(context, "edge"),
                ),
                const SizedBox(width: 25),
                browserIconButton(
                  "opera",
                  () => onBrowserPressed(context, "opera"),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  void onBrowserPressed(BuildContext context, String browserName) async {
    final downloadUrl = await getBrowserExtensionDownloadLink(browserName);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => BrowserExtensionInstallationGuideDialog(
        browserName: browserName,
        downloadUrl: downloadUrl,
      ),
    );
  }

  Widget browserIconButton(String browserName, VoidCallback onPressed) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        IconButton(
          iconSize: 40,
          splashRadius: 40,
          highlightColor: Colors.transparent,
          icon: SvgPicture.asset(
            width: 45,
            height: 45,
            "assets/icons/$browserName.svg",
          ),
          onPressed: onPressed,
        ),
        Text(
          browserName.capitalize(),
          style: TextStyle(
            fontSize: 14,
            color: theme.textColor,
            fontWeight: theme.fontWeight,
          ),
        ),
      ],
    );
  }
}
