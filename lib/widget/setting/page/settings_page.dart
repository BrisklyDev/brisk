import 'package:brisk/provider/settings_provider.dart';
import 'package:brisk/provider/theme_provider.dart';
import 'package:brisk/widget/setting/page/about/about_page.dart';
import 'package:brisk/widget/setting/page/bug_report/bug_report_page.dart';
import 'package:brisk/widget/setting/page/connection/connection_settings_page.dart';
import 'package:brisk/widget/setting/page/donate/donate_page.dart';
import 'package:brisk/widget/setting/page/extension/webextension_settings_page.dart';
import 'package:brisk/widget/setting/page/file/file_settings_page.dart';
import 'package:brisk/widget/setting/page/general/general_settings_page.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class SettingsPage extends StatelessWidget {
  final double height;
  final double width;

  const SettingsPage({super.key, this.height = 370, this.width = 550});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<SettingsProvider>(context);
    final theme = Provider.of<ThemeProvider>(context).activeTheme;
    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        color: theme.alertDialogTheme.backgroundColor,
      ),
      child: PageView(
        controller: provider.settingsPageController,
        physics: NeverScrollableScrollPhysics(),
        children: const [
          GeneralSettingsPage(),
          FileSettingsPage(),
          ConnectionSettingsPage(),
          WebExtensionSettingsPage(),
          AboutPage(),
          BugReportPage(),
          DonatePage(),
        ],
      ),
    );
  }
}
