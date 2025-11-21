#ifndef FLUTTER_PLUGIN_HOTKEY_MANAGER_WINDOWS_PLUGIN_H_
#define FLUTTER_PLUGIN_HOTKEY_MANAGER_WINDOWS_PLUGIN_H_

#include <flutter/event_channel.h>
#include <flutter/event_stream_handler_functions.h>
#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>

#include <memory>

namespace hotkey_manager_windows {

class HotkeyManagerWindowsPlugin
    : public flutter::Plugin,
      flutter::StreamHandler<flutter::EncodableValue> {
 private:
  flutter::PluginRegistrarWindows* registrar_;
  std::unique_ptr<flutter::EventSink<flutter::EncodableValue>> event_sink_;

  std::unordered_map<std::string, int32_t> hotkey_id_map_ = {};
  int32_t last_registered_hotkey_id_ = 0;
  int32_t window_proc_id_ = -1;
  std::optional<LRESULT> HandleWindowProc(HWND hwnd,
                                          UINT message,
                                          WPARAM wparam,
                                          LPARAM lparam);

 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows* registrar);

  HotkeyManagerWindowsPlugin(flutter::PluginRegistrarWindows* registrar);

  virtual ~HotkeyManagerWindowsPlugin();

  // Disallow copy and assign.
  HotkeyManagerWindowsPlugin(const HotkeyManagerWindowsPlugin&) = delete;
  HotkeyManagerWindowsPlugin& operator=(const HotkeyManagerWindowsPlugin&) =
      delete;

  void Register(
      const flutter::MethodCall<flutter::EncodableValue>& method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void Unregister(
      const flutter::MethodCall<flutter::EncodableValue>& method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void UnregisterAll(
      const flutter::MethodCall<flutter::EncodableValue>& method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  UINT GetVirtualKeyCodeFromString(const std::string key_code);
  UINT GetFsModifiersFromString(const std::vector<std::string>& modifiers);

  // Called when a method is called on this plugin's channel from Dart.
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue>& method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  std::unique_ptr<flutter::StreamHandlerError<>> OnListenInternal(
      const flutter::EncodableValue* arguments,
      std::unique_ptr<flutter::EventSink<>>&& events) override;

  std::unique_ptr<flutter::StreamHandlerError<>> OnCancelInternal(
      const flutter::EncodableValue* arguments) override;
};

}  // namespace hotkey_manager_windows

#endif  // FLUTTER_PLUGIN_HOTKEY_MANAGER_WINDOWS_PLUGIN_H_
