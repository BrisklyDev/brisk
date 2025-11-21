#include "include/window_manager/window_manager_plugin.h"

// This must be included before many other Windows headers.
#include <windows.h>

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <codecvt>
#include <map>
#include <memory>
#include <sstream>

#include "window_manager.cpp"

namespace {

bool IsWindows11OrGreater() {
  DWORD dwVersion = 0;
  DWORD dwBuild = 0;

#pragma warning(push)
#pragma warning(disable : 4996)
  dwVersion = GetVersion();
  // Get the build number.
  if (dwVersion < 0x80000000)
    dwBuild = (DWORD)(HIWORD(dwVersion));
#pragma warning(pop)

  return dwBuild < 22000;
}

class WindowManagerPlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows* registrar);

  WindowManagerPlugin(flutter::PluginRegistrarWindows* registrar);

  virtual ~WindowManagerPlugin();

 private:
  std::unique_ptr<
      flutter::MethodChannel<flutter::EncodableValue>,
      std::default_delete<flutter::MethodChannel<flutter::EncodableValue>>>
      channel = nullptr;

  WindowManager* window_manager;
  flutter::PluginRegistrarWindows* registrar;

  // The ID of the WindowProc delegate registration.
  int window_proc_id = -1;

  void WindowManagerPlugin::_EmitEvent(std::string eventName);
  // Called for top-level WindowProc delegation.
  std::optional<LRESULT> WindowManagerPlugin::HandleWindowProc(HWND hWnd,
                                                               UINT message,
                                                               WPARAM wParam,
                                                               LPARAM lParam);
  // Called when a method is called on this plugin's channel from Dart.
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue>& method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  void adjustNCCALCSIZE(HWND hwnd, NCCALCSIZE_PARAMS* sz) {
    LONG l = 8;
    LONG t = 8;

    // HMONITOR monitor = MonitorFromWindow(hwnd, MONITOR_DEFAULTTONEAREST);
    // Don't use `MonitorFromWindow(hwnd, MONITOR_DEFAULTTONEAREST)` above.
    // Because if the window is restored from minimized state, the window is not
    // in the correct monitor. The monitor is always the left-most monitor.
    // https://github.com/leanflutter/window_manager/issues/489
    HMONITOR monitor = MonitorFromRect(&sz->rgrc[0], MONITOR_DEFAULTTONEAREST);
    if (monitor != NULL) {
      MONITORINFO monitorInfo;
      monitorInfo.cbSize = sizeof(MONITORINFO);
      if (TRUE == GetMonitorInfo(monitor, &monitorInfo)) {
        l = sz->rgrc[0].left - monitorInfo.rcWork.left;
        t = sz->rgrc[0].top - monitorInfo.rcWork.top;
      } else {
        // GetMonitorInfo failed, use (8, 8) as default value
      }
    } else {
      // unreachable code
    }

    sz->rgrc[0].left -= l;
    sz->rgrc[0].top -= t;
    sz->rgrc[0].right += l;
    sz->rgrc[0].bottom += t;
  }
};

// static
void WindowManagerPlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows* registrar) {
  auto plugin = std::make_unique<WindowManagerPlugin>(registrar);

  registrar->AddPlugin(std::move(plugin));
}

WindowManagerPlugin::WindowManagerPlugin(
    flutter::PluginRegistrarWindows* registrar)
    : registrar(registrar) {
  window_manager = new WindowManager();
  window_proc_id = registrar->RegisterTopLevelWindowProcDelegate(
      [this](HWND hWnd, UINT message, WPARAM wParam, LPARAM lParam) {
        return HandleWindowProc(hWnd, message, wParam, lParam);
      });
  channel = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      registrar->messenger(), "window_manager",
      &flutter::StandardMethodCodec::GetInstance());

  channel->SetMethodCallHandler([this](const auto& call, auto result) {
    HandleMethodCall(call, std::move(result));
  });
}

WindowManagerPlugin::~WindowManagerPlugin() {
  registrar->UnregisterTopLevelWindowProcDelegate(window_proc_id);
  channel = nullptr;
}

void WindowManagerPlugin::_EmitEvent(std::string eventName) {
  if (channel == nullptr)
    return;
  flutter::EncodableMap args = flutter::EncodableMap();
  args[flutter::EncodableValue("eventName")] =
      flutter::EncodableValue(eventName);
  channel->InvokeMethod("onEvent",
                        std::make_unique<flutter::EncodableValue>(args));
}

std::optional<LRESULT> WindowManagerPlugin::HandleWindowProc(HWND hWnd,
                                                             UINT message,
                                                             WPARAM wParam,
                                                             LPARAM lParam) {
  std::optional<LRESULT> result = std::nullopt;

  if (message == WM_DPICHANGED) {
    window_manager->pixel_ratio_ =
        (float)LOWORD(wParam) / USER_DEFAULT_SCREEN_DPI;
    window_manager->ForceChildRefresh();
  }

  if (wParam && message == WM_NCCALCSIZE) {
    if (window_manager->IsFullScreen() &&
        window_manager->title_bar_style_ != "normal") {
      if (window_manager->is_frameless_) {
        adjustNCCALCSIZE(hWnd, reinterpret_cast<NCCALCSIZE_PARAMS*>(lParam));
      }
      return 0;
    }
    // This must always be before handling title_bar_style_ == "hidden" so
    // the `if TitleBarStyle.hidden` doesn't get executed.
    if (window_manager->is_frameless_) {
      if (window_manager->IsMaximized()) {
        adjustNCCALCSIZE(hWnd, reinterpret_cast<NCCALCSIZE_PARAMS*>(lParam));
      }
      return 0;
    }

    // This must always be last.
    if (wParam && window_manager->title_bar_style_ == "hidden") {
      if (window_manager->IsMaximized()) {
        // Adjust the borders when maximized so the app isn't cut off
        adjustNCCALCSIZE(hWnd, reinterpret_cast<NCCALCSIZE_PARAMS*>(lParam));
      } else {
        NCCALCSIZE_PARAMS* sz = reinterpret_cast<NCCALCSIZE_PARAMS*>(lParam);
        // on windows 10, if set to 0, there's a white line at the top
        // of the app and I've yet to find a way to remove that.
        sz->rgrc[0].top += IsWindows11OrGreater() ? 0 : 1;
        // The following lines are required for resizing the window.
        // https://github.com/leanflutter/window_manager/issues/483
        sz->rgrc[0].right -= 8;
        sz->rgrc[0].bottom -= 8;
        sz->rgrc[0].left -= -8;
      }

      // Previously (WVR_HREDRAW | WVR_VREDRAW), but returning 0 or 1 doesn't
      // actually break anything so I've set it to 0. Unless someone pointed a
      // problem in the future.
      return 0;
    }
  } else if (message == WM_NCHITTEST) {
    if (!window_manager->is_resizable_) {
      return HTNOWHERE;
    }
  } else if (message == WM_GETMINMAXINFO) {
    MINMAXINFO* info = reinterpret_cast<MINMAXINFO*>(lParam);
    // For the special "unconstrained" values, leave the defaults.
    if (window_manager->minimum_size_.x != 0)
      info->ptMinTrackSize.x = static_cast<LONG>(
          window_manager->minimum_size_.x * window_manager->pixel_ratio_);
    if (window_manager->minimum_size_.y != 0)
      info->ptMinTrackSize.y = static_cast<LONG>(
          window_manager->minimum_size_.y * window_manager->pixel_ratio_);
    if (window_manager->maximum_size_.x != -1)
      info->ptMaxTrackSize.x = static_cast<LONG>(
          window_manager->maximum_size_.x * window_manager->pixel_ratio_);
    if (window_manager->maximum_size_.y != -1)
      info->ptMaxTrackSize.y = static_cast<LONG>(
          window_manager->maximum_size_.y * window_manager->pixel_ratio_);
    result = 0;
  } else if (message == WM_NCACTIVATE) {
    if (wParam != 0) {
      _EmitEvent("focus");
    } else {
      _EmitEvent("blur");
    }

    if (window_manager->title_bar_style_ == "hidden" ||
        window_manager->is_frameless_)
      return 1;
  } else if (message == WM_EXITSIZEMOVE) {
    if (window_manager->is_resizing_) {
      _EmitEvent("resized");
      window_manager->is_resizing_ = false;
    }
    if (window_manager->is_moving_) {
      _EmitEvent("moved");
      window_manager->is_moving_ = false;
    }
    return false;
  } else if (message == WM_MOVING) {
    window_manager->is_moving_ = true;
    _EmitEvent("move");
    return false;
  } else if (message == WM_SIZING) {
    window_manager->is_resizing_ = true;
    _EmitEvent("resize");

    if (window_manager->aspect_ratio_ > 0) {
      RECT* rect = (LPRECT)lParam;

      double aspect_ratio = window_manager->aspect_ratio_;

      int new_width = static_cast<int>(rect->right - rect->left);
      int new_height = static_cast<int>(rect->bottom - rect->top);

      bool is_resizing_horizontally =
          wParam == WMSZ_LEFT || wParam == WMSZ_RIGHT ||
          wParam == WMSZ_TOPLEFT || wParam == WMSZ_BOTTOMLEFT;

      if (is_resizing_horizontally) {
        new_height = static_cast<int>(new_width / aspect_ratio);
      } else {
        new_width = static_cast<int>(new_height * aspect_ratio);
      }

      int left = rect->left;
      int top = rect->top;
      int right = rect->right;
      int bottom = rect->bottom;

      switch (wParam) {
        case WMSZ_RIGHT:
        case WMSZ_BOTTOM:
          right = new_width + left;
          bottom = top + new_height;
          break;
        case WMSZ_TOP:
          right = new_width + left;
          top = bottom - new_height;
          break;
        case WMSZ_LEFT:
        case WMSZ_TOPLEFT:
          left = right - new_width;
          top = bottom - new_height;
          break;
        case WMSZ_TOPRIGHT:
          right = left + new_width;
          top = bottom - new_height;
          break;
        case WMSZ_BOTTOMLEFT:
          left = right - new_width;
          bottom = top + new_height;
          break;
        case WMSZ_BOTTOMRIGHT:
          right = left + new_width;
          bottom = top + new_height;
          break;
      }

      rect->left = left;
      rect->top = top;
      rect->right = right;
      rect->bottom = bottom;
    }
  } else if (message == WM_SIZE) {
    if (window_manager->IsFullScreen() && wParam == SIZE_MAXIMIZED &&
        window_manager->last_state != STATE_FULLSCREEN_ENTERED) {
      _EmitEvent("enter-full-screen");
      window_manager->last_state = STATE_FULLSCREEN_ENTERED;
    } else if (!window_manager->IsFullScreen() && wParam == SIZE_RESTORED &&
               window_manager->last_state == STATE_FULLSCREEN_ENTERED) {
      window_manager->ForceChildRefresh();
      _EmitEvent("leave-full-screen");
      window_manager->last_state = STATE_NORMAL;
    } else if (window_manager->last_state != STATE_FULLSCREEN_ENTERED) {
      if (wParam == SIZE_MAXIMIZED) {
        _EmitEvent("maximize");
        window_manager->last_state = STATE_MAXIMIZED;
      } else if (wParam == SIZE_MINIMIZED) {
        _EmitEvent("minimize");
        window_manager->last_state = STATE_MINIMIZED;
        return 0;
      } else if (wParam == SIZE_RESTORED) {
        if (window_manager->last_state == STATE_MAXIMIZED) {
          _EmitEvent("unmaximize");
          window_manager->last_state = STATE_NORMAL;
        } else if (window_manager->last_state == STATE_MINIMIZED) {
          _EmitEvent("restore");
          window_manager->last_state = STATE_NORMAL;
        }
      }
    }
  } else if (message == WM_CLOSE) {
    _EmitEvent("close");
    if (window_manager->IsPreventClose()) {
      return -1;
    }
  } else if (message == WM_SHOWWINDOW) {
    if (wParam == TRUE) {
      _EmitEvent("show");
    } else {
      _EmitEvent("hide");
    }
  } else if (message == WM_WINDOWPOSCHANGED) {
    if (window_manager->IsAlwaysOnBottom()) {
      const flutter::EncodableMap& args = {
          {flutter::EncodableValue("isAlwaysOnBottom"),
           flutter::EncodableValue(true)}};
      window_manager->SetAlwaysOnBottom(args);
    }
  }

  return result;
}

void WindowManagerPlugin::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue>& method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  std::string method_name = method_call.method_name();

  if (method_name.compare("ensureInitialized") == 0) {
    window_manager->native_window =
        ::GetAncestor(registrar->GetView()->GetNativeWindow(), GA_ROOT);
    result->Success(flutter::EncodableValue(true));
  } else if (method_name.compare("waitUntilReadyToShow") == 0) {
    window_manager->WaitUntilReadyToShow();
    result->Success(flutter::EncodableValue(true));
  } else if (method_name.compare("getId") == 0) {
    result->Success(flutter::EncodableValue(
        reinterpret_cast<__int64>(window_manager->GetMainWindow())));
  } else if (method_name.compare("setAsFrameless") == 0) {
    window_manager->SetAsFrameless();
    result->Success(flutter::EncodableValue(true));
  } else if (method_name.compare("destroy") == 0) {
    window_manager->Destroy();
    result->Success(flutter::EncodableValue(true));
  } else if (method_name.compare("close") == 0) {
    window_manager->Close();
    result->Success(flutter::EncodableValue(true));
  } else if (method_name.compare("isPreventClose") == 0) {
    auto value = window_manager->IsPreventClose();
    result->Success(flutter::EncodableValue(value));
  } else if (method_name.compare("setPreventClose") == 0) {
    const flutter::EncodableMap& args =
        std::get<flutter::EncodableMap>(*method_call.arguments());
    window_manager->SetPreventClose(args);
    result->Success(flutter::EncodableValue(true));
  } else if (method_name.compare("focus") == 0) {
    window_manager->Focus();
    result->Success(flutter::EncodableValue(true));
  } else if (method_name.compare("blur") == 0) {
    window_manager->Blur();
    result->Success(flutter::EncodableValue(true));
  } else if (method_name.compare("isFocused") == 0) {
    bool value = window_manager->IsFocused();
    result->Success(flutter::EncodableValue(value));
  } else if (method_name.compare("show") == 0) {
    window_manager->Show();
    result->Success(flutter::EncodableValue(true));
  } else if (method_name.compare("hide") == 0) {
    window_manager->Hide();
    result->Success(flutter::EncodableValue(true));
  } else if (method_name.compare("isVisible") == 0) {
    bool value = window_manager->IsVisible();
    result->Success(flutter::EncodableValue(value));
  } else if (method_name.compare("isMaximized") == 0) {
    bool value = window_manager->IsMaximized();
    result->Success(flutter::EncodableValue(value));
  } else if (method_name.compare("maximize") == 0) {
    const flutter::EncodableMap& args =
        std::get<flutter::EncodableMap>(*method_call.arguments());
    window_manager->Maximize(args);
    result->Success(flutter::EncodableValue(true));
  } else if (method_name.compare("unmaximize") == 0) {
    window_manager->Unmaximize();
    result->Success(flutter::EncodableValue(true));
  } else if (method_name.compare("isMinimized") == 0) {
    bool value = window_manager->IsMinimized();
    result->Success(flutter::EncodableValue(value));
  } else if (method_name.compare("minimize") == 0) {
    window_manager->Minimize();
    result->Success(flutter::EncodableValue(true));
  } else if (method_name.compare("restore") == 0) {
    window_manager->Restore();
    result->Success(flutter::EncodableValue(true));
  } else if (method_name.compare("isDockable") == 0) {
    bool value = window_manager->IsDockable();
    result->Success(flutter::EncodableValue(value));
  } else if (method_name.compare("isDocked") == 0) {
    int value = window_manager->IsDocked();
    result->Success(flutter::EncodableValue(value));
  } else if (method_name.compare("dock") == 0) {
    const flutter::EncodableMap& args =
        std::get<flutter::EncodableMap>(*method_call.arguments());
    window_manager->Dock(args);
    result->Success(flutter::EncodableValue(true));
  } else if (method_name.compare("undock") == 0) {
    bool value = window_manager->Undock();
    result->Success(flutter::EncodableValue(value));
  } else if (method_name.compare("isFullScreen") == 0) {
    bool value = window_manager->IsFullScreen();
    result->Success(flutter::EncodableValue(value));
  } else if (method_name.compare("setFullScreen") == 0) {
    const flutter::EncodableMap& args =
        std::get<flutter::EncodableMap>(*method_call.arguments());
    window_manager->SetFullScreen(args);
    result->Success(flutter::EncodableValue(true));
  } else if (method_name.compare("setAspectRatio") == 0) {
    const flutter::EncodableMap& args =
        std::get<flutter::EncodableMap>(*method_call.arguments());
    window_manager->SetAspectRatio(args);
    result->Success(flutter::EncodableValue(true));
  } else if (method_name.compare("setBackgroundColor") == 0) {
    const flutter::EncodableMap& args =
        std::get<flutter::EncodableMap>(*method_call.arguments());
    window_manager->SetBackgroundColor(args);
    result->Success(flutter::EncodableValue(true));
  } else if (method_name.compare("getBounds") == 0) {
    const flutter::EncodableMap& args =
        std::get<flutter::EncodableMap>(*method_call.arguments());
    flutter::EncodableMap value = window_manager->GetBounds(args);
    result->Success(flutter::EncodableValue(value));
  } else if (method_name.compare("setBounds") == 0) {
    const flutter::EncodableMap& args =
        std::get<flutter::EncodableMap>(*method_call.arguments());
    window_manager->SetBounds(args);
    result->Success(flutter::EncodableValue(true));
  } else if (method_name.compare("setMinimumSize") == 0) {
    const flutter::EncodableMap& args =
        std::get<flutter::EncodableMap>(*method_call.arguments());
    window_manager->SetMinimumSize(args);
    result->Success(flutter::EncodableValue(true));
  } else if (method_name.compare("setMaximumSize") == 0) {
    const flutter::EncodableMap& args =
        std::get<flutter::EncodableMap>(*method_call.arguments());
    window_manager->SetMaximumSize(args);
    result->Success(flutter::EncodableValue(true));
  } else if (method_name.compare("isResizable") == 0) {
    bool value = window_manager->IsResizable();
    result->Success(flutter::EncodableValue(value));
  } else if (method_name.compare("setResizable") == 0) {
    const flutter::EncodableMap& args =
        std::get<flutter::EncodableMap>(*method_call.arguments());
    window_manager->SetResizable(args);
    result->Success(flutter::EncodableValue(true));
  } else if (method_name.compare("isMinimizable") == 0) {
    bool value = window_manager->IsMinimizable();
    result->Success(flutter::EncodableValue(value));
  } else if (method_name.compare("setMinimizable") == 0) {
    const flutter::EncodableMap& args =
        std::get<flutter::EncodableMap>(*method_call.arguments());
    window_manager->SetMinimizable(args);
    result->Success(flutter::EncodableValue(true));
  } else if (method_name.compare("isMaximizable") == 0) {
    bool value = window_manager->IsMaximizable();
    result->Success(flutter::EncodableValue(value));
  } else if (method_name.compare("setMaximizable") == 0) {
    const flutter::EncodableMap& args =
        std::get<flutter::EncodableMap>(*method_call.arguments());
    window_manager->SetMaximizable(args);
    result->Success(flutter::EncodableValue(true));
  } else if (method_name.compare("isClosable") == 0) {
    bool value = window_manager->IsClosable();
    result->Success(flutter::EncodableValue(value));
  } else if (method_name.compare("setClosable") == 0) {
    const flutter::EncodableMap& args =
        std::get<flutter::EncodableMap>(*method_call.arguments());
    window_manager->SetClosable(args);
    result->Success(flutter::EncodableValue(true));
  } else if (method_name.compare("isAlwaysOnTop") == 0) {
    bool value = window_manager->IsAlwaysOnTop();
    result->Success(flutter::EncodableValue(value));
  } else if (method_name.compare("setAlwaysOnTop") == 0) {
    const flutter::EncodableMap& args =
        std::get<flutter::EncodableMap>(*method_call.arguments());
    window_manager->SetAlwaysOnTop(args);
    result->Success(flutter::EncodableValue(true));
  } else if (method_name.compare("isAlwaysOnBottom") == 0) {
    bool value = window_manager->IsAlwaysOnBottom();
    result->Success(flutter::EncodableValue(value));
  } else if (method_name.compare("setAlwaysOnBottom") == 0) {
    const flutter::EncodableMap& args =
        std::get<flutter::EncodableMap>(*method_call.arguments());
    window_manager->SetAlwaysOnBottom(args);
    result->Success(flutter::EncodableValue(true));
  } else if (method_name.compare("getTitle") == 0) {
    std::string value = window_manager->GetTitle();
    result->Success(flutter::EncodableValue(value));
  } else if (method_name.compare("setTitle") == 0) {
    const flutter::EncodableMap& args =
        std::get<flutter::EncodableMap>(*method_call.arguments());
    window_manager->SetTitle(args);
    result->Success(flutter::EncodableValue(true));
  } else if (method_name.compare("setTitleBarStyle") == 0) {
    const flutter::EncodableMap& args =
        std::get<flutter::EncodableMap>(*method_call.arguments());
    window_manager->SetTitleBarStyle(args);
    result->Success(flutter::EncodableValue(true));
  } else if (method_name.compare("getTitleBarHeight") == 0) {
    int value = window_manager->GetTitleBarHeight();
    result->Success(flutter::EncodableValue(value));
  } else if (method_name.compare("isSkipTaskbar") == 0) {
    bool value = window_manager->IsSkipTaskbar();
    result->Success(flutter::EncodableValue(value));
  } else if (method_name.compare("setSkipTaskbar") == 0) {
    const flutter::EncodableMap& args =
        std::get<flutter::EncodableMap>(*method_call.arguments());
    window_manager->SetSkipTaskbar(args);
    result->Success(flutter::EncodableValue(true));
  } else if (method_name.compare("setProgressBar") == 0) {
    const flutter::EncodableMap& args =
        std::get<flutter::EncodableMap>(*method_call.arguments());
    window_manager->SetProgressBar(args);
    result->Success(flutter::EncodableValue(true));
  } else if (method_name.compare("setIcon") == 0) {
    const flutter::EncodableMap& args =
        std::get<flutter::EncodableMap>(*method_call.arguments());
    window_manager->SetIcon(args);
    result->Success(flutter::EncodableValue(true));
  } else if (method_name.compare("hasShadow") == 0) {
    bool value = window_manager->HasShadow();
    result->Success(flutter::EncodableValue(value));
  } else if (method_name.compare("setHasShadow") == 0) {
    const flutter::EncodableMap& args =
        std::get<flutter::EncodableMap>(*method_call.arguments());
    window_manager->SetHasShadow(args);
    result->Success(flutter::EncodableValue(true));
  } else if (method_name.compare("getOpacity") == 0) {
    double value = window_manager->GetOpacity();
    result->Success(flutter::EncodableValue(value));
  } else if (method_name.compare("setOpacity") == 0) {
    const flutter::EncodableMap& args =
        std::get<flutter::EncodableMap>(*method_call.arguments());
    window_manager->SetOpacity(args);
    result->Success(flutter::EncodableValue(true));
  } else if (method_name.compare("setBrightness") == 0) {
    const flutter::EncodableMap& args =
        std::get<flutter::EncodableMap>(*method_call.arguments());
    window_manager->SetBrightness(args);
    result->Success(flutter::EncodableValue(true));
  } else if (method_name.compare("setIgnoreMouseEvents") == 0) {
    const flutter::EncodableMap& args =
        std::get<flutter::EncodableMap>(*method_call.arguments());
    window_manager->SetIgnoreMouseEvents(args);
    result->Success(flutter::EncodableValue(true));
  } else if (method_name.compare("popUpWindowMenu") == 0) {
    const flutter::EncodableMap& args =
        std::get<flutter::EncodableMap>(*method_call.arguments());
    window_manager->PopUpWindowMenu(args);
    result->Success(flutter::EncodableValue(true));
  } else if (method_name.compare("startDragging") == 0) {
    window_manager->StartDragging();
    result->Success(flutter::EncodableValue(true));
  } else if (method_name.compare("startResizing") == 0) {
    const flutter::EncodableMap& args =
        std::get<flutter::EncodableMap>(*method_call.arguments());
    window_manager->StartResizing(args);
    result->Success(flutter::EncodableValue(true));
  } else {
    result->NotImplemented();
  }
}

}  // namespace

void WindowManagerPluginRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  WindowManagerPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
