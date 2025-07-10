import 'package:brisk/constants/app_closure_behaviour.dart';
import 'package:brisk/l10n/app_localizations.dart';
import 'package:brisk/widget/setting/base/settings_group.dart';
import 'package:brisk/widget/setting/base/switch_setting.dart';
import 'package:flutter/material.dart';

import '../../../../constants/file_duplication_behaviour.dart';
import '../../../../setting/settings_cache.dart';
import '../../base/drop_down_setting.dart';

class BehaviourSettingsGroup extends StatefulWidget {
  const BehaviourSettingsGroup({super.key});

  @override
  State<BehaviourSettingsGroup> createState() => _BehaviourSettingsGroupState();
}

class _BehaviourSettingsGroupState extends State<BehaviourSettingsGroup> {
  late AppLocalizations loc;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    loc = AppLocalizations.of(context)!;
    return SettingsGroup(
      title: loc.settings_behavior,
      children: [
        SwitchSetting(
          text: loc.settings_behavior_launchAtStartup,
          switchValue: SettingsCache.launchOnStartUp,
          onChanged: (val) =>
              setState(() => SettingsCache.launchOnStartUp = val),
        ),
        const SizedBox(height: 5),
        const SizedBox(height: 5),
        SwitchSetting(
          text: loc.settings_behavior_showProgressOnNewDownload,
          switchValue: SettingsCache.openDownloadProgressWindow,
          onChanged: (val) =>
              setState(() => SettingsCache.openDownloadProgressWindow = val),
        ),
        const SizedBox(height: 5),
        DropDownSetting(
          dropDownItemTextWidth: size.width * 0.17,
          value:
              _appClosureActionToDropDownTxt(SettingsCache.appClosureBehaviour),
          text: loc.settings_behavior_appClosureBehavior,
          onChanged: _onAppClosureDropDownChanged,
          items: [
            loc.settings_behavior_appClosureBehavior_minimizeToTray,
            loc.settings_behavior_appClosureBehavior_exit,
            loc.settings_behavior_appClosureBehavior_alwaysAsk,
          ],
        ),
        const SizedBox(height: 5),
        DropDownSetting(
          dropDownItemTextWidth: size.width * 0.17,
          value: _fileDuplicationActionToDropDownTxt(
            SettingsCache.fileDuplicationBehaviour,
            loc,
          ),
          text: loc.settings_behavior_duplicateDownloadAction,
          onChanged: _onFileDuplicationDropDownChanged,
          items: [
            loc.settings_behavior_duplicateDownloadAction_addNew,
            loc.settings_behavior_duplicateDownloadAction_updateUrl,
            loc.settings_behavior_duplicateDownloadAction_skipDownload,
            loc.settings_behavior_duplicateDownloadAction_alwaysAsk,
          ],
        )
      ],
    );
  }

  String _fileDuplicationActionToDropDownTxt(
      FileDuplicationBehaviour behaviour, AppLocalizations loc) {
    switch (behaviour) {
      case FileDuplicationBehaviour.ask:
        return loc.settings_behavior_duplicateDownloadAction_alwaysAsk;
      case FileDuplicationBehaviour.skip:
        return loc.settings_behavior_duplicateDownloadAction_skipDownload;
      case FileDuplicationBehaviour.updateUrl:
        return loc.settings_behavior_duplicateDownloadAction_updateUrl;
      case FileDuplicationBehaviour.add:
        return loc.settings_behavior_duplicateDownloadAction_addNew;
    }
  }

  String _appClosureActionToDropDownTxt(AppClosureBehaviour behaviour) {
    switch (behaviour) {
      case AppClosureBehaviour.ask:
        return loc.settings_behavior_appClosureBehavior_alwaysAsk;
      case AppClosureBehaviour.exit:
        return loc.settings_behavior_appClosureBehavior_exit;
      case AppClosureBehaviour.minimizeToTray:
        return loc.settings_behavior_appClosureBehavior_minimizeToTray;
    }
  }

  void _onFileDuplicationDropDownChanged(String? value) {
    if (value == null || value.isEmpty) return;
    final behaviour = _fileDuplicationDropDownTxtToBehaviour(value);
    setState(() => SettingsCache.fileDuplicationBehaviour = behaviour);
  }

  void _onAppClosureDropDownChanged(String? value) {
    if (value == null || value.isEmpty) return;
    final behaviour = _appClosureDropDownTxtToBehaviour(value);
    setState(() => SettingsCache.appClosureBehaviour = behaviour);
  }

  AppClosureBehaviour _appClosureDropDownTxtToBehaviour(String txt) {
    if (txt == loc.settings_behavior_appClosureBehavior_alwaysAsk) {
      return AppClosureBehaviour.ask;
    } else if (txt == loc.settings_behavior_appClosureBehavior_exit) {
      return AppClosureBehaviour.exit;
    } else if (txt == loc.settings_behavior_appClosureBehavior_minimizeToTray) {
      return AppClosureBehaviour.minimizeToTray;
    } else {
      return AppClosureBehaviour.ask;
    }
  }

  FileDuplicationBehaviour _fileDuplicationDropDownTxtToBehaviour(String txt) {
    if (txt == loc.settings_behavior_duplicateDownloadAction_alwaysAsk) {
      return FileDuplicationBehaviour.ask;
    }
    if (txt == loc.settings_behavior_duplicateDownloadAction_skipDownload) {
      return FileDuplicationBehaviour.skip;
    } else if (txt == loc.settings_behavior_duplicateDownloadAction_addNew) {
      return FileDuplicationBehaviour.add;
    } else if (txt == loc.settings_behavior_duplicateDownloadAction_updateUrl) {
      return FileDuplicationBehaviour.updateUrl;
    } else {
      return FileDuplicationBehaviour.ask;
    }
  }
}
