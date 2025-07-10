import 'package:brisk/l10n/app_localizations.dart';
import 'package:brisk/setting/settings_cache.dart';
import 'package:brisk/widget/setting/base/settings_group.dart';
import 'package:brisk/widget/setting/base/switch_setting.dart';
import 'package:flutter/material.dart';

class LoggingGroup extends StatefulWidget {
  const LoggingGroup({super.key});

  @override
  State<LoggingGroup> createState() => _LoggingGroupState();
}

class _LoggingGroupState extends State<LoggingGroup> {
  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return SettingsGroup(
      title: loc.settings_logging,
      children: [
        SwitchSetting(
          text: loc.settings_logging_enableDownloadEngineLogging,
          switchValue: SettingsCache.loggerEnabled,
          onChanged: (val) =>
              setState(() => SettingsCache.loggerEnabled = val),
        ),
      ],
    );
  }
}
