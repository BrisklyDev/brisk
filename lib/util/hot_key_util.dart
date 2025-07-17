import 'dart:io';

import 'package:brisk/provider/search_bar_notifier_provider.dart';
import 'package:brisk/util/app_logger.dart';
import 'package:brisk/setting/settings_cache.dart';
import 'package:brisk/util/tray_handler.dart';
import 'package:clipboard/clipboard.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

import 'download_addition_ui_util.dart';

class HotKeyUtil {
  static bool _isDownloadHotkeyRegistered = false;
  static bool _isMacosWindowHotkeyRegistered = false;
  static bool _isSearchHotkeyRegistered = false;
  static HotKey? downloadAdditionHotkey;

  static void registerHotkeys(BuildContext context) async {
    await HotKeyUtil.registerDownloadAdditionHotKey(context);
    await HotKeyUtil.registerRowSearchHotkey(context);
    if (Platform.isMacOS) {
      await HotKeyUtil.registerMacOsDefaultWindowHotkeys(context);
    }
  }

  static Future<void> registerRowSearchHotkey(BuildContext context) async {
    if (_isSearchHotkeyRegistered) return;
    final searchHotkey = HotKey(
      key: LogicalKeyboardKey.keyF,
      modifiers: [HotKeyModifier.control],
      scope: HotKeyScope.inapp,
    );
    await hotKeyManager.register(
      searchHotkey,
      keyDownHandler: (_) => {
        Provider.of<SearchBarNotifierProvider>(
          context,
          listen: false,
        ).toggleShow()
      },
    );
  }

  static Future<void> registerMacOsDefaultWindowHotkeys(
      BuildContext context) async {
    if (_isMacosWindowHotkeyRegistered) return;
    //Show window thumbnail in dock, keep dock icon,
    // click window thumbnail or dock icon to restore window,
    // and the thumbnail disappears after restoration
    final hideHotkey = HotKey(
      key: LogicalKeyboardKey.keyH,
      modifiers: [HotKeyModifier.meta],
      scope: HotKeyScope.inapp,
    );
    //Hide window to tray, no dock icon, no thumbnail window
    final hideToTrayHotkey = HotKey(
      key: LogicalKeyboardKey.keyW,
      modifiers: [HotKeyModifier.meta],
      scope: HotKeyScope.inapp,
    );
    //Quit app / kill process
    final quitHotkey = HotKey(
      key: LogicalKeyboardKey.keyQ,
      modifiers: [HotKeyModifier.meta],
      scope: HotKeyScope.inapp,
    );

    await hotKeyManager.register(
      hideHotkey,
      keyDownHandler: (_) => windowManager.minimize(),
    );
    await hotKeyManager.register(
      hideToTrayHotkey,
      keyDownHandler: (_) => TrayHandler.setTray(context).then((_) async {
        await windowManager.hide();
        windowManager.setSkipTaskbar(true);
      }),
    );
    await hotKeyManager.register(
      quitHotkey,
      keyDownHandler: (_) => windowManager.destroy().then((_) => exit(0)),
    );
    _isMacosWindowHotkeyRegistered = true;
  }

  static Future<void> registerDownloadAdditionHotKey(
      BuildContext context) async {
    if (_isDownloadHotkeyRegistered) return;
    if (SettingsCache.downloadAdditionHotkeyLogicalKey == null ||
        (SettingsCache.downloadAdditionHotkeyModifierOne == null &&
            SettingsCache.downloadAdditionHotkeyModifierTwo == null)) {
      return;
    }
    List<HotKeyModifier?> modifiers = [
      SettingsCache.downloadAdditionHotkeyModifierOne,
      SettingsCache.downloadAdditionHotkeyModifierTwo
    ]..removeWhere((element) => element == null);
    downloadAdditionHotkey = HotKey(
      key: SettingsCache.downloadAdditionHotkeyLogicalKey!,
      modifiers: [...modifiers.map((e) => e!)],
      scope: SettingsCache.downloadAdditionHotkeyScope,
    );
    try {
      hotKeyManager.register(
        downloadAdditionHotkey!,
        keyDownHandler: (hotKey) async {
          String url = await FlutterClipboard.paste();
          DownloadAdditionUiUtil.handleDownloadAddition(context, url);
        },
      );
    } catch (e) {
      Logger.log(e);
    }
    _isDownloadHotkeyRegistered = true;
  }
}
