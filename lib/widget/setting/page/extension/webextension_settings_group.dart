import 'package:brisk/l10n/app_localizations.dart';
import 'package:brisk/widget/setting/base/switch_setting.dart';
import 'package:flutter/material.dart';
import 'package:brisk/util/settings_cache.dart';
import 'package:brisk/widget/setting/base/settings_group.dart';
import 'package:brisk/widget/setting/base/text_field_setting.dart';

class PortSettingsGroup extends StatefulWidget {
  const PortSettingsGroup({super.key});

  @override
  State<PortSettingsGroup> createState() => _WebExtensionSettingsGroupState();
}

class _WebExtensionSettingsGroupState extends State<PortSettingsGroup> {
  final portController = TextEditingController(
    text: SettingsCache.extensionPort.toString(),
  );

  @override
  void dispose() {
    portController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final size = MediaQuery.of(context).size;
    return SettingsGroup(
      title: loc.settings_browserExtension,
      children: [
        TextFieldSetting(
          onChanged: (value) => _onChanged(
            value,
            (parsedValue) => SettingsCache.extensionPort = parsedValue,
          ),
          width: 75,
          textWidth: size.width * 0.6 * 0.32,
          text: loc.port,
          txtController: portController,
        ),
        SwitchSetting(
          text: loc.settings_downloadBrowserExtension_bringWindowToFront,
          switchValue: SettingsCache.enableWindowToFront,
          onChanged: (val) =>
              setState(() => SettingsCache.enableWindowToFront = val),
        ),
        Center(
          child: Text(
            '* ${loc.changesRequireRestart}',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
        )
      ],
    );
  }

  _onChanged(String value, Function(int parsedValue) setCache) {
    final numberValue = int.tryParse(value);
    if (numberValue == null) return;
    setState(() => setCache(numberValue));
  }
}
