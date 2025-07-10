import 'package:brisk/l10n/app_localizations.dart';
import 'package:brisk/setting/settings_cache.dart';
import 'package:brisk/widget/setting/base/drop_down_setting.dart';
import 'package:brisk/widget/setting/base/settings_group.dart';
import 'package:brisk_download_engine/brisk_download_engine.dart';
import 'package:flutter/material.dart';

class DownloadEngineGroup extends StatefulWidget {
  const DownloadEngineGroup({super.key});

  @override
  State<DownloadEngineGroup> createState() => _DownloadEngineGroupState();
}

class _DownloadEngineGroupState extends State<DownloadEngineGroup> {
  late AppLocalizations loc;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    loc = AppLocalizations.of(context)!;
    return SettingsGroup(
      title: loc.settings_engine,
      children: [
        DropDownSetting(
          tooltipMessage: loc.settings_engine_clientType_tooltip,
            items: [
              loc.settings_engine_clientType_standard,
              loc.settings_engine_clientType_performance,
            ],
            text: loc.settings_engine_clientType,
            textWidth: 120,
            value: resolveClientTypeTitle(),
            onChanged: onClientTypeChanged,
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
      ],
    );
  }

  void onClientTypeChanged(val) {
    if (val == loc.settings_engine_clientType_performance) {
      setState(() => SettingsCache.httpClientType = ClientType.rHttp);
      return;
    }
    if (val == loc.settings_engine_clientType_standard) {
      setState(() => SettingsCache.httpClientType = ClientType.dartHttp);
      return;
    }
    setState(() => SettingsCache.httpClientType = ClientType.dartHttp);
  }

  String resolveClientTypeTitle() {
    if (SettingsCache.httpClientType == ClientType.rHttp) {
      return loc.settings_engine_clientType_performance;
    }
    if (SettingsCache.httpClientType == ClientType.dartHttp) {
      return loc.settings_engine_clientType_standard;
    }
    return loc.settings_engine_clientType_standard;
  }
}
