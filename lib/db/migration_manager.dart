import 'package:brisk/constants/setting_options.dart';
import 'package:brisk/db/hive_util.dart';
import 'package:brisk/model/general_data.dart';
import 'package:brisk/model/migration.dart';
import 'package:brisk/model/setting.dart';
import 'package:brisk/setting/settings_cache.dart';

class MigrationManager {
  static List<Migration> migrations = [
    Migration(0, "Add proxy Settings"),
    Migration(1, "Add m3u8 connection number"),
    Migration(2, "Add i10n"),
    Migration(3, "Add custom hotkey"),
    Migration(4, "Add github star checker"),
    Migration(5, "Add FFmpeg path"),
    Migration(6, "Add FFmpeg warning ignore"),
    Migration(7, "Add http client type"),
    Migration(8, "Add automaticFileSavePathCategorization"),
  ];

  static runMigrations() async {
    final migrationBox = HiveUtil.instance.migrationBox;
    for (final migration in migrations) {
      var existingMigration = migrationBox.get(migration.version);
      if (existingMigration != null) {
        continue;
      }
      await runMigration(migration);
    }
  }

  static runMigration(Migration migration) async {
    switch (migration.version) {
      case 0:
        await runMigrationV0();
        break;
      case 1:
        await runMigrationV1();
        break;
      case 2:
        await runMigrationV2();
        break;
      case 3:
        await runMigrationV3();
        break;
      case 4:
        await runMigrationV4();
        break;
      case 5:
        await runMigrationV5();
        break;
      case 6:
        await runMigrationV6();
        break;
      case 7:
        await runMigrationV7();
        break;
      case 8:
        await runMigrationV8();
        break;
      default:
        break;
    }
    await HiveUtil.instance.migrationBox.put(migration.version, migration);
  }

  static runMigrationV0() async {
    final newSettings = [
      Setting(
        name: SettingOptions.proxyEnabled.name,
        value:
            SettingsCache.defaultSettings[SettingOptions.proxyEnabled.name]![1],
        settingType:
            SettingsCache.defaultSettings[SettingOptions.proxyEnabled.name]![0],
      ),
      Setting(
        name: SettingOptions.proxyAddress.name,
        value:
            SettingsCache.defaultSettings[SettingOptions.proxyAddress.name]![1],
        settingType:
            SettingsCache.defaultSettings[SettingOptions.proxyAddress.name]![0],
      ),
      Setting(
        name: SettingOptions.proxyPort.name,
        value: SettingsCache.defaultSettings[SettingOptions.proxyPort.name]![1],
        settingType:
            SettingsCache.defaultSettings[SettingOptions.proxyPort.name]![0],
      ),
      Setting(
        name: SettingOptions.proxyUsername.name,
        value: SettingsCache
            .defaultSettings[SettingOptions.proxyUsername.name]![1],
        settingType: SettingsCache
            .defaultSettings[SettingOptions.proxyUsername.name]![0],
      ),
      Setting(
        name: SettingOptions.proxyPassword.name,
        value: SettingsCache
            .defaultSettings[SettingOptions.proxyPassword.name]![1],
        settingType: SettingsCache
            .defaultSettings[SettingOptions.proxyPassword.name]![0],
      ),
    ];
    for (final setting in newSettings) {
      await HiveUtil.instance.settingBox.add(setting);
    }
  }

  static runMigrationV1() async {
    final connNumSetting = Setting(
      name: SettingOptions.m3u8ConnectionsNumber.name,
      value: SettingsCache
          .defaultSettings[SettingOptions.m3u8ConnectionsNumber.name]![1],
      settingType: SettingsCache
          .defaultSettings[SettingOptions.m3u8ConnectionsNumber.name]![0],
    );
    await HiveUtil.instance.settingBox.add(connNumSetting);
  }

  static runMigrationV2() async {
    final localeSetting = Setting(
      name: SettingOptions.locale.name,
      value: SettingsCache.defaultSettings[SettingOptions.locale.name]![1],
      settingType:
          SettingsCache.defaultSettings[SettingOptions.locale.name]![0],
    );
    await HiveUtil.instance.settingBox.add(localeSetting);
  }

  static runMigrationV3() async {
    final hotkeyModifierOne = Setting(
      name: SettingOptions.downloadAdditionHotkeyModifierOne.name,
      value: SettingsCache.defaultSettings[
          SettingOptions.downloadAdditionHotkeyModifierOne.name]![1],
      settingType: SettingsCache.defaultSettings[
          SettingOptions.downloadAdditionHotkeyModifierOne.name]![0],
    );
    final hotkeyModifierTwo = Setting(
      name: SettingOptions.downloadAdditionHotkeyModifierTwo.name,
      value: SettingsCache.defaultSettings[
          SettingOptions.downloadAdditionHotkeyModifierTwo.name]![1],
      settingType: SettingsCache.defaultSettings[
          SettingOptions.downloadAdditionHotkeyModifierTwo.name]![0],
    );
    final hotkeyLogicalKey = Setting(
      name: SettingOptions.downloadAdditionHotkeyLogicalKey.name,
      value: SettingsCache.defaultSettings[
          SettingOptions.downloadAdditionHotkeyLogicalKey.name]![1],
      settingType: SettingsCache.defaultSettings[
          SettingOptions.downloadAdditionHotkeyLogicalKey.name]![0],
    );
    final hotkeyScope = Setting(
      name: SettingOptions.downloadAdditionHotkeyScope.name,
      value: SettingsCache
          .defaultSettings[SettingOptions.downloadAdditionHotkeyScope.name]![1],
      settingType: SettingsCache
          .defaultSettings[SettingOptions.downloadAdditionHotkeyScope.name]![0],
    );
    await HiveUtil.instance.settingBox.addAll(
      [hotkeyModifierOne, hotkeyModifierTwo, hotkeyLogicalKey, hotkeyScope],
    );
  }

  static runMigrationV4() async {
    final githubStarNeverShowAgain = GeneralData(
      fieldName: "githubStar_neverShowAgain",
      value: false,
    );
    await HiveUtil.instance.generalDataBox.add(githubStarNeverShowAgain);
  }

  static runMigrationV5() async {
    final ffmpegPath = Setting(
      name: SettingOptions.ffmpegPath.name,
      value: SettingsCache.defaultSettings[SettingOptions.ffmpegPath.name]![1],
      settingType:
          SettingsCache.defaultSettings[SettingOptions.ffmpegPath.name]![0],
    );
    await HiveUtil.instance.settingBox.add(ffmpegPath);
  }

  static Future<void> runMigrationV6() async {
    final ffmpegWarningIgnore = GeneralData(
      fieldName: "ffmpegWarningIgnore",
      value: false,
    );
    await HiveUtil.instance.generalDataBox.add(ffmpegWarningIgnore);
  }

  static Future<void> runMigrationV7() async {
    final httpClientType = Setting(
      name: SettingOptions.httpClientType.name,
      value:
          SettingsCache.defaultSettings[SettingOptions.httpClientType.name]![1],
      settingType:
          SettingsCache.defaultSettings[SettingOptions.httpClientType.name]![0],
    );
    await HiveUtil.instance.settingBox.add(httpClientType);
  }

  static Future<void> runMigrationV8() async {
    final savePathCategorization = Setting(
      name: SettingOptions.automaticFileSavePathCategorization.name,
      value: SettingsCache.defaultSettings[
          SettingOptions.automaticFileSavePathCategorization.name]![1],
      settingType: SettingsCache.defaultSettings[
          SettingOptions.automaticFileSavePathCategorization.name]![0],
    );
    await HiveUtil.instance.settingBox.add(savePathCategorization);
  }
}
