#include "include/hotkey_manager_windows/hotkey_manager_windows_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "hotkey_manager_windows_plugin.h"

void HotkeyManagerWindowsPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  hotkey_manager_windows::HotkeyManagerWindowsPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
