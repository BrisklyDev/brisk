import 'package:brisk/l10n/app_localizations.dart';
import 'package:brisk/setting/rule/file_condition.dart';
import 'package:brisk/setting/rule/file_save_path_rule.dart';
import 'package:brisk/setting/rule/rule_value_type.dart';
import 'package:brisk/util/settings_cache.dart';
import 'package:brisk/widget/base/default_tooltip.dart';

import 'package:brisk/widget/setting/base/external_link_setting.dart';
import 'package:brisk/widget/setting/base/rule/file_save_path_rule_editor_dialog.dart';
import 'package:brisk/widget/setting/base/settings_group.dart';
import 'package:flutter/material.dart';

class FileRulesGroup extends StatelessWidget {
  const FileRulesGroup({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final loc = AppLocalizations.of(context)!;
    return SettingsGroup(
      title: loc.settings_rules,
      children: [
        ExternalLinkSetting(
          title: loc.settings_rules_fileSavePathRules,
          titleWidth: resolveWidth(size),
          linkText: loc.settings_rules_edit,
          customIcon: Icon(Icons.edit_note_rounded, color: Colors.white70),
          onLinkPressed: () => showDialog(
            builder: (context) => FileSavePathRuleEditorDialog(),
            context: context,
          ),
          tooltipMessage: loc.settings_rules_fileSavePathRules_tooltip,
        )
      ],
    );
  }

  double resolveWidth(Size size) {
    double width = 140;
    if (size.width < 688) {
      width = 120;
    }
    if (size.width < 608) {
      width = 90;
    }
    return width;
  }
}
