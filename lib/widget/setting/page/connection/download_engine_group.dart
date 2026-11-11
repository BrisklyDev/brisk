import 'package:brisk/constants/speed_unit.dart';
import 'package:brisk/l10n/app_localizations.dart';
import 'package:brisk/setting/settings_cache.dart';
import 'package:brisk/widget/setting/base/drop_down_setting.dart';
import 'package:brisk/widget/setting/base/settings_group.dart';
import 'package:brisk/widget/setting/base/text_field_setting.dart';
import 'package:brisk/provider/theme_provider.dart';
import 'package:brisk/widget/base/default_tooltip.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:brisk_download_engine/brisk_download_engine.dart';
import 'package:flutter/material.dart';

class DownloadEngineGroup extends StatefulWidget {
  const DownloadEngineGroup({super.key});

  @override
  State<DownloadEngineGroup> createState() => _DownloadEngineGroupState();
}

class _DownloadEngineGroupState extends State<DownloadEngineGroup> {
  late AppLocalizations loc;
  SpeedUnit speedLimitUnit = SpeedUnit.forLimit(SettingsCache.speedLimit);
  late final speedLimitController = TextEditingController(
    // Empty when unlimited so the "Unlimited" hint shows, like the speed limit panel
    text: SettingsCache.speedLimit > 0
        ? (SettingsCache.speedLimit ~/ speedLimitUnit.bytes).toString()
        : "",
  );

  void updateSpeedLimit() {
    final value = int.tryParse(speedLimitController.text.trim()) ?? 0;
    SettingsCache.speedLimit = value * speedLimitUnit.bytes;
  }

  @override
  void dispose() {
    speedLimitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    loc = AppLocalizations.of(context)!;
    return SettingsGroup(
      title: loc.settings_engine,
      children: [
        DropDownSetting(
          tooltipMessage: loc.settings_engine_engineType_tooltip,
          items: [
            loc.settings_engine_engineType_default,
            loc.settings_engine_engineType_performance,
          ],
          text: loc.settings_engine_engineType,
          textWidth: 120,
          value: resolveEngineTypeTitle(),
          onChanged: onEngineTypeChanged,
        ),
        DropDownSetting(
          onChanged: (value) {
            if (value == null || value.isEmpty) return;
            setState(
              () => SettingsCache.connectionsNumber = int.parse(value),
            );
          },
          text: loc.settings_downloadConnections_regularConnNum,
          textWidth: size.width < 1683 ? size.width * 0.3 : 505,
          items: [1, 2, 4, 8, 16].map((e) => e.toString()).toList(),
          value: SettingsCache.connectionsNumber.toString(),
        ),
        DropDownSetting(
          onChanged: (value) {
            if (value == null || value.isEmpty) return;
            setState(
              () => SettingsCache.m3u8ConnectionNumber = int.parse(value),
            );
          },
          text: loc.settings_downloadConnections_videoStreamConnNum,
          textWidth: size.width < 1683 ? size.width * 0.3 : 505,
          items: [1, 2, 4, 8, 16].map((e) => e.toString()).toList(),
          value: SettingsCache.m3u8ConnectionNumber.toString(),
        ),
        speedLimitSetting(size),
      ],
    );
  }

  /// The global speed limit in KB/s or MB/s. Disabled unless the kasma engine is selected since the
  /// standard engine does not support speed limits.
  Widget speedLimitSetting(Size size) {
    final theme = Provider.of<ThemeProvider>(context).activeTheme;
    final supported = SettingsCache.downloadEngineType == EngineType.kasma;
    final setting = TextFieldSetting(
      enabled: supported,
      text: loc.settings_engine_speedLimit,
      textWidth: size.width < 1683 ? size.width * 0.3 : 505,
      width: 100,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      hintText: loc.unlimited,
      txtController: speedLimitController,
      onChanged: (_) => updateSpeedLimit(),
      icon: Opacity(
        opacity: supported ? 1 : 0.4,
        child: DropdownButton<SpeedUnit>(
          value: speedLimitUnit,
          isDense: true,
          iconEnabledColor: theme.widgetTheme.dropDownColor.iconColor,
          dropdownColor:
              theme.widgetTheme.dropDownColor.dropDownBackgroundColor,
          items: SpeedUnit.values
              .map(
                (unit) => DropdownMenuItem(
                  value: unit,
                  child: Text(
                    unit.label,
                    style: TextStyle(
                      color: theme.widgetTheme.dropDownColor.itemTextColor,
                    ),
                  ),
                ),
              )
              .toList(),
          onChanged: supported
              ? (unit) {
                  if (unit == null) return;
                  setState(() => speedLimitUnit = unit);
                  updateSpeedLimit();
                }
              : null,
        ),
      ),
    );
    if (supported) return setting;
    // A disabled field doesn't react to hover, so the whole row explains why it is disabled
    return DefaultTooltip(
      message: loc.settings_engine_speedLimit_unsupported,
      child: setting,
    );
  }

  void onEngineTypeChanged(String? val) {
    if (val == loc.settings_engine_engineType_performance) {
      setState(() => SettingsCache.downloadEngineType = EngineType.kasma);
      return;
    }
    setState(() => SettingsCache.downloadEngineType = EngineType.standard);
  }

  String resolveEngineTypeTitle() {
    return SettingsCache.downloadEngineType == EngineType.kasma
        ? loc.settings_engine_engineType_performance
        : loc.settings_engine_engineType_default;
  }
}
