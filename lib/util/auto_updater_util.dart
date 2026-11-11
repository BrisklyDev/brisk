import 'dart:convert';
import 'dart:io';
import 'package:brisk/constants/setting_options.dart';
import 'package:brisk/constants/setting_type.dart';
import 'package:brisk/db/hive_util.dart';
import 'package:brisk/l10n/app_localizations.dart';
import 'package:brisk/model/setting.dart';
import 'package:brisk/util/parse_util.dart';
import 'package:brisk/util/platform.dart';
import 'package:brisk/widget/base/confirmation_dialog.dart';
import 'package:brisk/widget/base/error_dialog.dart';
import 'package:brisk/widget/base/info_dialog.dart';
import 'package:brisk/widget/download/update_available_dialog.dart';
import 'package:brisk/widget/other/brisk_change_log_dialog.dart';
import 'package:brisk/widget/other/package_manager_update_dialog.dart';
import 'package:dartx/dartx.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:window_manager/window_manager.dart';
import 'package:http/http.dart';

import 'http_util.dart';

void handleBriskUpdateCheck(
  BuildContext context, {
  bool showUpdateNotAvailableDialog = false,
  bool ignoreLastUpdateCheck = false,
}) async {
  Pair<bool, String> versionCheckResult;
  try {
    versionCheckResult = await isNewBriskVersionAvailable(
      ignoreLastUpdateCheck: ignoreLastUpdateCheck,
    );
  } catch (e) {
    showDialog(
      context: context,
      builder: (context) => ErrorDialog(
        title: "Check for Update Failed",
        description: e.toString(),
        height: 100,
        width: 400,
      ),
    );
    return;
  }
  if (versionCheckResult.first) {
    final changeLog = await getLatestVersionChangeLog(
      removeChangeLogHeader: true,
    );
    showDialog(
      context: context,
      builder: (context) => UpdateAvailableDialog(
        newVersion: versionCheckResult.second,
        changeLog: changeLog,
        onUpdatePressed: () => handleUpdate(context),
      ),
    );
  } else {
    if (showUpdateNotAvailableDialog) {
      showDialog(
        context: context,
        builder: (context) => InfoDialog(
          titleIcon: Icon(
            Icons.info,
            color: Colors.blueAccent,
          ),
          titleIconBackgroundColor: Colors.black12,
          titleText: AppLocalizations.of(context)!.noUpdateAvailable,
        ),
      );
      return;
    }
  }

  final updateRequested = HiveUtil.getSetting(SettingOptions.updateRequested);
  final preUpdateVersion = HiveUtil.getSetting(SettingOptions.preUpdateVersion);
  if (updateRequested == null ||
      preUpdateVersion == null ||
      !parseBool(updateRequested.value)) return;

  final currentVersion = (await PackageInfo.fromPlatform()).version;
  // A successful update is handled by [handlePostUpdateChangeLog], which covers every update
  // method. Only a failed in-app update is reported here.
  if (preUpdateVersion.value == currentVersion) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => ConfirmationDialog(
        title: "Update Failed",
        width: 500,
        description:
            "Failed to automatically update brisk to the latest version!\nWould you like to manually download the latest version?",
        confirmButtonText: "Yes, Take me there",
        confirmButtonWidth: 150,
        onConfirmPressed: () => launchUrlString(
            "https://github.com/AminBhst/brisk/releases/latest"),
      ),
    );
  }
  await updateRequested
    ..value = "false"
    ..save();
}

Future<void> handlePostUpdateChangeLog(BuildContext context) async {
  final lastRunVersion = HiveUtil.getSetting(SettingOptions.lastRunVersion);
  final existingInstall =
      HiveUtil.getSetting(SettingOptions.lastUpdateCheck) != null;
  final currentVersion = (await PackageInfo.fromPlatform()).version;
  final updated = lastRunVersion == null
      ? existingInstall
      : _isNewerVersion(currentVersion, lastRunVersion.value);
  if (updated) {
    final String changeLog;
    try {
      changeLog = await getLatestVersionChangeLog();
    } catch (_) {
      return;
    }
    if (!context.mounted) return;
    showDialog(
      context: context,
      builder: (context) => BriskChangeLogDialog(
        updatedVersion: currentVersion,
        changeLog: changeLog,
      ),
      barrierDismissible: false,
    );
  }
  if (lastRunVersion == null) {
    await HiveUtil.instance.settingBox.add(
      Setting(
        name: SettingOptions.lastRunVersion.name,
        value: currentVersion,
        settingType: SettingType.system.name,
      ),
    );
  } else if (lastRunVersion.value != currentVersion) {
    lastRunVersion.value = currentVersion;
    await lastRunVersion.save();
  }
}

bool _isNewerVersion(String version, String previous) {
  try {
    final current = version.split(".").map(int.parse).toList();
    final last = previous.split(".").map(int.parse).toList();
    for (var i = 0; i < current.length || i < last.length; i++) {
      final a = i < current.length ? current[i] : 0;
      final b = i < last.length ? last[i] : 0;
      if (a != b) return a > b;
    }
    return false;
  } catch (_) {
    return false;
  }
}

void onUpdatePressed(String version) {
  final buildMethod = String.fromEnvironment(
    "BUILD_METHOD",
    defaultValue: "basic",
  );
  if (buildMethod == "basic" || buildMethod == "exe" || buildMethod == "tar") {
    launchAutoUpdater();
  } else if (buildMethod == "dmg") {
    launchUrlString(
        "https://github.com/AminBhst/brisk/releases/download/v$version/Brisk-v$version-macos.dmg");
  } else if (buildMethod == "flatpak") {
  } else if (buildMethod == "snap") {}
}

Future<String> getLatestVersionChangeLog({
  bool removeChangeLogHeader = false,
  bool browserExtension = false,
}) async {
  String url =
      "https://raw.githubusercontent.com/AminBhst/brisk/refs/heads/main/.github/${browserExtension ? "extension_release.md" : "release.md"}";
  final response = await Client().get(Uri.parse(url));
  final changeLog = utf8.decode(response.bodyBytes);
  if (removeChangeLogHeader) {
    final lines = changeLog.split('\n');
    if (lines.isNotEmpty && lines.first.contains("Changelog")) {
      lines.removeAt(0);
    }
    return lines.join('\n');
  }
  return changeLog;
}

void handleUpdate(BuildContext context) {
  if (isFlatpak) {
    showDialog(
      context: context,
      builder: (context) => PackageManagerUpdateDialog(
        target: "Flatpak",
        updateCommand: "flatpak update io.github.BrisklyDev.Brisk",
        logo: "assets/icons/flathub.svg",
      ),
      barrierDismissible: false,
    );
    return;
  }
  if (isSnap) {
    showDialog(
      context: context,
      builder: (context) => PackageManagerUpdateDialog(
        target: "Snap",
        updateCommand: "sudo snap refresh brisk",
        logo: "assets/icons/snapcraft.svg",
      ),
      barrierDismissible: false,
    );
    return;
  }
  if (isAur) {
    showDialog(
      context: context,
      builder: (context) => PackageManagerUpdateDialog(
        target: "AUR",
        updateCommand: "yay -S brisk  #If you're using yay",
        logo: "assets/icons/arch.svg",
      ),
      barrierDismissible: false,
    );
    return;
  }
  launchAutoUpdater();
}

void launchAutoUpdater() async {
  String executablePath = Platform.resolvedExecutable;
  if (Platform.isWindows) {
    await setUpdateRequested();
    final updaterPath = join(
      Directory(executablePath).parent.path,
      "updater",
      "brisk_auto_updater.exe",
    );
    String command = 'Start-Process -FilePath "$updaterPath" -Verb RunAs';
    Process.run('powershell', ['-command', command], runInShell: true).then(
      (_) {
        windowManager.destroy().then((value) => exit(0));
      },
    );
  } else if (Platform.isLinux) {
    await setUpdateRequested();
    final updaterPath = join(
      Directory(executablePath).parent.path,
      "updater",
      "brisk_auto_updater",
    );
    Process.start(
      updaterPath,
      [],
      mode: ProcessStartMode.detached,
    ).then((_) {
      windowManager.destroy().then((value) => exit(0));
    });
  } else {
    launchUrlString(
      "https://github.com/AminBhst/brisk/releases/latest",
    );
  }
}

Future<void> setUpdateRequested() async {
  var updateRequested = HiveUtil.getSetting(SettingOptions.updateRequested);
  var preUpdateVersion = HiveUtil.getSetting(SettingOptions.preUpdateVersion);
  final currentVersion = (await PackageInfo.fromPlatform()).version;
  if (updateRequested == null) {
    updateRequested = Setting(
      name: "updateRequested",
      value: "true",
      settingType: SettingType.system.name,
    );
    preUpdateVersion = Setting(
      name: "preUpdateVersion",
      value: currentVersion,
      settingType: SettingType.system.name,
    );
    await HiveUtil.instance.settingBox.add(updateRequested);
    await HiveUtil.instance.settingBox.add(preUpdateVersion);
    return;
  }
  updateRequested.value = "true";
  preUpdateVersion!.value = currentVersion;
  await updateRequested.save();
  await preUpdateVersion.save();
}
