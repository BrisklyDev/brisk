import 'package:brisk/l10n/app_localizations.dart';
import 'package:brisk/provider/theme_provider.dart';
import 'package:brisk/widget/setting/base/settings_group.dart';
import 'package:brisk/widget/setting/base/text_field_setting.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../setting/settings_cache.dart';

class ConnectionRetryGroup extends StatefulWidget {
  const ConnectionRetryGroup({super.key});

  @override
  State<ConnectionRetryGroup> createState() => _ConnectionRetryGroupState();
}

class _ConnectionRetryGroupState extends State<ConnectionRetryGroup> {
  final connRetryCountController = TextEditingController(
    text: SettingsCache.connectionRetryCount.toString(),
  );

  @override
  void dispose() {
    connRetryCountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme =
        Provider.of<ThemeProvider>(context).activeTheme.settingTheme.pageTheme;
    final size = MediaQuery.of(context).size;
    final loc = AppLocalizations.of(context)!;
    return SettingsGroup(
      title: loc.settings_connectionRetry,
      children: [
        TextFieldSetting(
          onChanged: (value) => _onChanged(
            value,
            (parsedValue) => SettingsCache.connectionRetryCount = parsedValue,
          ),
          width: 50,
          textWidth: size.width * 0.6 * 0.32,
          icon: Text(
            "-1 = ${loc.infinite}",
            style: TextStyle(color: theme.titleTextColor, fontSize: 14),
          ),
          text: loc.settings_connectionRetry_maxConnectionRetryCount,
          keyboardType: const TextInputType.numberWithOptions(
            signed: true,
            decimal: false,
          ),
          txtController: connRetryCountController,
        ),
        const SizedBox(height: 10),
        TextFieldSetting(
          onChanged: (value) => _onChanged(
            value,
            (parsedValue) => SettingsCache.connectionRetryTimeout = parsedValue,
          ),
          width: 75,
          textWidth: size.width * 0.6 * 0.32,
          text: loc.settings_connectionRetry_connectionRetryTimeout,
          icon: Text(
            loc.seconds,
            style: TextStyle(color: theme.titleTextColor, fontSize: 14),
          ),
          txtController: TextEditingController(
              text: SettingsCache.connectionRetryTimeout.toString()),
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
