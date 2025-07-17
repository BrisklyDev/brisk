import 'package:brisk/l10n/app_localizations.dart';
import 'package:brisk/provider/theme_provider.dart';
import 'package:brisk/setting/rule/file_rule.dart';
import 'package:brisk/widget/setting/base/external_link_setting.dart';
import 'package:brisk/widget/setting/base/rule/extension_skip_capture_rule_editor_dialog.dart';
import 'package:brisk/widget/setting/base/settings_group.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class BrowserExtensionRulesGroup extends StatelessWidget {
  const BrowserExtensionRulesGroup({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final loc = AppLocalizations.of(context)!;
    final theme = Provider.of<ThemeProvider>(context).activeTheme;
    return SettingsGroup(
      title: loc.settings_rules,
      children: [
        ExternalLinkSetting(
          title: loc.settings_rules_extensionSkipCaptureRules,
          width: resolveLinkWidth(size),
          titleWidth: resolveTitleWidth(size),
          linkText: loc.settings_rules_edit,
          customIcon: Icon(
            Icons.edit_note_rounded,
            color: theme.widgetTheme.iconColor,
          ),
          onLinkPressed: () => showDialog(
            builder: (context) => ExtensionSkipCaptureRuleEditorDialog(),
            barrierDismissible: false,
            context: context,
          ),
          tooltipMessage: loc.settings_rules_extensionSkipCaptureRules_tooltip,
        ),
      ],
    );
  }

  Widget buildRuleRow(FileRule rule) {
    return Row(
      children: [
        Text(rule.condition.toReadable()),
        const SizedBox(width: 5),
        SizedBox(
          width: 90,
          child: rule.readableValue.length > 10
              ? Tooltip(
                  decoration: BoxDecoration(
                    color: Color.fromRGBO(33, 33, 33, 1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  textStyle: TextStyle(color: Colors.white),
                  child:
                      Text(rule.readableValue, overflow: TextOverflow.ellipsis),
                  message: rule.readableValue,
                )
              : Text(rule.readableValue, overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }

  double resolveLinkWidth(Size size) {
    double width = 300;
    if (size.width < 754) {
      width = 230;
    }
    if (size.width < 666) {
      width = 200;
    }
    if (size.width < 630) {
      width = 180;
    }
    return width;
  }

  double resolveTitleWidth(Size size) {
    double width = 220;
    if (size.width < 754) {
      width = 170;
    }
    if (size.width < 666) {
      width = 120;
    }
    return width;
  }
}
