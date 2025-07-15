import 'package:brisk/l10n/app_localizations.dart';
import 'package:brisk/provider/theme_provider.dart';
import 'package:brisk/widget/browser_extension/get_browser_extension_dialog.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../base/settings_group.dart';

class WebExtensionSettingsDownloadGroup extends StatelessWidget {
  const WebExtensionSettingsDownloadGroup({super.key});

  @override
  Widget build(BuildContext context) {
    // final textWidth = MediaQuery.of(context).size.width * 0.6 * 0.5;
    final theme = Provider.of<ThemeProvider>(context).activeTheme;
    final loc = AppLocalizations.of(context)!;
    return SettingsGroup(
      title: loc.settings_downloadBrowserExtension,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                loc.settings_downloadBrowserExtension_installExtension,
                style: TextStyle(
                  color: theme.settingTheme.pageTheme.titleTextColor,
                  fontSize: 14,
                  fontWeight: theme.fontWeight,
                ),
              ),
            ),
            IconButton(
              onPressed: () => showDialog(
                context: context,
                builder: (context) => GetBrowserExtensionDialog(),
              ),
              icon: Icon(
                Icons.install_desktop_rounded,
                color: theme.widgetTheme.iconColor,
                size: 28,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
