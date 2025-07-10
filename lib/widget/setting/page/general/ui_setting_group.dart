import 'package:brisk/l10n/app_localizations.dart';
import 'package:brisk/provider/locale_provider.dart';
import 'package:brisk/provider/theme_provider.dart';
import 'package:brisk/theme/application_theme_holder.dart';
import 'package:brisk/setting/settings_cache.dart';
import 'package:brisk/widget/setting/base/drop_down_setting.dart';
import 'package:brisk/widget/setting/base/settings_group.dart';
import 'package:flutter/material.dart';

class UISettingGroup extends StatefulWidget {
  const UISettingGroup({super.key});

  @override
  State<UISettingGroup> createState() => _UISettingGroupState();
}

class _UISettingGroupState extends State<UISettingGroup> {
  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return SettingsGroup(
      title: loc.settings_userInterface,
      children: [
        DropDownSetting(
          items: ApplicationThemeHolder.themes
              .map((t) => t.themeId.toString())
              .toList(),
          text: loc.settings_userInterface_theme,
          value: SettingsCache.applicationThemeId,
          onChanged: _onThemeChanged,
        ),
        DropDownSetting(
          items: LocaleProvider.locales.values.toList(),
          text: loc.language,
          value: LocaleProvider.locales[SettingsCache.locale]!,
          onChanged: _onLocaleChanged,
        )
      ],
    );
  }

  void _onLocaleChanged(String? locale) {
    if (locale == null || locale.isEmpty) return;
    setState(
      () => SettingsCache.locale = LocaleProvider.locales.keys
          .firstWhere((key) => LocaleProvider.locales[key] == locale),
    );
  }

  void _onThemeChanged(String? value) {
    if (value == null || value.isEmpty) return;
    setState(() => SettingsCache.applicationThemeId = value);
  }
}
