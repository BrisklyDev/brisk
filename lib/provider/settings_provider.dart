import 'package:flutter/material.dart';

import '../setting/settings_cache.dart';

class SettingsProvider with ChangeNotifier {
  static final SettingsProvider instance = SettingsProvider._internal();

  SettingsProvider._internal();

  factory SettingsProvider() => instance;

  final PageController settingsPageController = PageController(initialPage: 0);
  int? selectedTabId = 0;
  String? tempPath = SettingsCache.temporaryDir.path;
  String? savePath = SettingsCache.saveDir.path;
  String? ffmpegPath = SettingsCache.ffmpegPath;

  void setSavePath(String path) {
    savePath = path;
    notifyListeners();
  }

  void setTempPath(String path) {
    tempPath = path;
  }

  void setSelectedSettingsTab(int tabId) {
    selectedTabId = tabId;
    settingsPageController.jumpToPage(tabId);
    notifyListeners();
  }

  void resetSettingCache() {
    SettingsCache.setCachedSettings();
    notifyListeners();
  }
}
