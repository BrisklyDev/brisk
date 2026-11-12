import 'package:brisk/l10n/app_localizations.dart';
import 'package:brisk/provider/theme_provider.dart';
import 'package:brisk/widget/setting/base/settings_group.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:brisk/util/url_launcher_util.dart';

class BugReportPage extends StatelessWidget {
  const BugReportPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final theme =
        Provider.of<ThemeProvider>(context).activeTheme.settingTheme.pageTheme;
    final loc = AppLocalizations.of(context)!;
    return SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SettingsGroup(
            title: loc.settings_howToBugReport,
            children: [
              SizedBox(
                width: size.width * 0.6,
                height: 50,
                child: Text(
                  "${loc.settings_howToBugReport_description}\n\n",
                  style: TextStyle(color: theme.titleTextColor),
                ),
              ),
              InkWell(
                child: SizedBox(
                  width: size.width * 0.6,
                  child: Text(
                    loc.settings_howToBugReport_clickToOpenIssue,
                    style: TextStyle(color: Colors.blue),
                  ),
                ),
                onTap: () => openUrl(
                    "https://github.com/AminBhst/brisk/issues/new"),
              )
            ],
          ),
        ],
      ),
    );
  }
}
