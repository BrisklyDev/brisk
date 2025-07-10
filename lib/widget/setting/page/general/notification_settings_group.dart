import 'package:brisk/l10n/app_localizations.dart';
import 'package:brisk/widget/setting/base/settings_group.dart';
import 'package:brisk/widget/setting/base/switch_setting.dart';
import 'package:flutter/material.dart';

import '../../../../setting/settings_cache.dart';

class NotificationSettingsGroup extends StatefulWidget {
  const NotificationSettingsGroup({super.key});

  @override
  State<NotificationSettingsGroup> createState() =>
      _NotificationSettingsGroupState();
}

class _NotificationSettingsGroupState extends State<NotificationSettingsGroup> {
  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return SettingsGroup(
      title: loc.settings_notification,
      children: [
        SwitchSetting(
          text: loc.settings_notification_onDownloadCompletion,
          switchValue: SettingsCache.notificationOnDownloadCompletion,
          onChanged: (val) => setState(
              () => SettingsCache.notificationOnDownloadCompletion = val),
        ),
        SwitchSetting(
          text: loc.settings_notification_onDownloadFailure,
          switchValue: SettingsCache.notificationOnDownloadFailure,
          onChanged: (val) =>
              setState(() => SettingsCache.notificationOnDownloadFailure = val),
        ),
      ],
    );
  }
}
