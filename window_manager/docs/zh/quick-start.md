# 快速开始

按照以下步骤快速开始使用 `window_manager` 插件：

## 安装

将以下内容添加到您的软件包的 `pubspec.yaml` 文件中：

```yaml
dependencies:
  window_manager: ^0.5.0
```

或者

```yaml
dependencies:
  window_manager:
    git:
      url: https://github.com/leanflutter/window_manager.git
      ref: main
```

## 使用方法

```dart
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 必须添加这一行
  await windowManager.ensureInitialized();

  WindowOptions windowOptions = WindowOptions(
    size: Size(800, 600),
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.hidden,
  );
  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  runApp(MyApp());
}

```

> 完整示例请参见此插件的示例应用。

### 监听事件

```dart
import 'package:flutter/cupertino.dart';
import 'package:window_manager/window_manager.dart';

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WindowListener {
  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ...
  }

  @override
  void onWindowEvent(String eventName) {
    print('[WindowManager] onWindowEvent: $eventName');
  }

  @override
  void onWindowClose() {
    // 做些什么
  }

  @override
  void onWindowFocus() {
    // 做些什么
  }

  @override
  void onWindowBlur() {
    // 做些什么
  }

  @override
  void onWindowMaximize() {
    // 做些什么
  }

  @override
  void onWindowUnmaximize() {
    // 做些什么
  }

  @override
  void onWindowMinimize() {
    // 做些什么
  }

  @override
  void onWindowRestore() {
    // 做些什么
  }

  @override
  void onWindowResize() {
    // 做些什么
  }

  @override
  void onWindowMove() {
    // 做些什么
  }

  @override
  void onWindowEnterFullScreen() {
    // 做些什么
  }

  @override
  void onWindowLeaveFullScreen() {
    // 做些什么
  }
}
```

### 关闭时退出

如果您需要使用隐藏方法，您需要禁用 `QuitOnClose`。

#### macOS

按如下方式更改文件 `macos/Runner/AppDelegate.swift`：

```diff
import Cocoa
import FlutterMacOS

@NSApplicationMain
class AppDelegate: FlutterAppDelegate {
  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
-    return true
+    return false
  }
}
```

### 关闭前确认

```dart
import 'package:flutter/cupertino.dart';
import 'package:window_manager/window_manager.dart';

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WindowListener {
  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _init();
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  void _init() async {
    // 添加此行以覆盖默认的关闭处理程序
    await windowManager.setPreventClose(true);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    // ...
  }

  @override
  void onWindowClose() async {
    bool _isPreventClose = await windowManager.isPreventClose();
    if (_isPreventClose) {
      showDialog(
        context: context,
        builder: (_) {
          return AlertDialog(
            title: Text('您确定要关闭此窗口吗？'),
            actions: [
              TextButton(
                child: Text('否'),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
              TextButton(
                child: Text('是'),
                onPressed: () {
                  Navigator.of(context).pop();
                  await windowManager.destroy();
                },
              ),
            ],
          );
        },
      );
    }
  }
}
```

### 启动时隐藏

在启动 Flutter 桌面应用程序时，可能会有一个短暂的时刻，其中显示未样式化的窗口，然后才应用自定义样式。这可能会为用户创造一种不连贯的视觉体验。

为了防止这种情况，我们可以最初隐藏窗口，只有在 Flutter 完全初始化并应用所有样式后才显示它。这创造了更平滑的启动体验。

以下是如何实现这一点：

#### Linux

按如下方式更改文件 `linux/my_application.cc`：

```diff

...

// Implements GApplication::activate.
static void my_application_activate(GApplication* application) {

  ...

  gtk_window_set_default_size(window, 1280, 720);
-  gtk_widget_show(GTK_WIDGET(window));
+  gtk_widget_realize(GTK_WIDGET(window));

  g_autoptr(FlDartProject) project = fl_dart_project_new();
  fl_dart_project_set_dart_entrypoint_arguments(project, self->dart_entrypoint_arguments);

  FlView* view = fl_view_new(project);
  gtk_widget_show(GTK_WIDGET(view));
  gtk_container_add(GTK_CONTAINER(window), GTK_WIDGET(view));

  fl_register_plugins(FL_PLUGIN_REGISTRY(view));

  gtk_widget_grab_focus(GTK_WIDGET(view));
}

...

```

#### macOS

按如下方式更改文件 `macos/Runner/MainFlutterWindow.swift`：

```diff
import Cocoa
import FlutterMacOS
+import window_manager

class MainFlutterWindow: NSWindow {
    override func awakeFromNib() {
        let flutterViewController = FlutterViewController.init()
        let windowFrame = self.frame
        self.contentViewController = flutterViewController
        self.setFrame(windowFrame, display: true)

        RegisterGeneratedPlugins(registry: flutterViewController)

        super.awakeFromNib()
    }

+    override public func order(_ place: NSWindow.OrderingMode, relativeTo otherWin: Int) {
+        super.order(place, relativeTo: otherWin)
+        hiddenWindowAtLaunch()
+    }
}

```

#### Windows

按如下方式更改文件 `windows/runner/win32_window.cpp`：

```diff
bool Win32Window::CreateAndShow(const std::wstring& title,
                                const Point& origin,
                                const Size& size) {
  ...
  HWND window = CreateWindow(
-      window_class, title.c_str(), WS_OVERLAPPEDWINDOW | WS_VISIBLE,
+      window_class, title.c_str(),
+      WS_OVERLAPPEDWINDOW, // 不要添加 WS_VISIBLE，因为窗口将在稍后显示
      Scale(origin.x, scale_factor), Scale(origin.y, scale_factor),
      Scale(size.width, scale_factor), Scale(size.height, scale_factor),
      nullptr, nullptr, GetModuleHandle(nullptr), this);
```

自 flutter 3.7 新的 windows 项目以来
按如下方式更改文件 `windows/runner/flutter_window.cpp`：

```diff
bool FlutterWindow::OnCreate() {
  ...
  flutter_controller_->engine()->SetNextFrameCallback([&]() {
-   this->Show();
+   "" //删除 this->Show()
  });
```

确保在 `onWindowFocus` 事件上调用一次 `setState`。

```dart
import 'package:flutter/cupertino.dart';
import 'package:window_manager/window_manager.dart';

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WindowListener {
  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ...
  }

  @override
  void onWindowFocus() {
    // 确保只调用一次
    setState(() {});
    // 做些什么
  }
}

```

## 相关链接

- [关闭窗口后点击dock图标恢复](https://leanflutter.dev/blog/click-dock-icon-to-restore-after-closing-the-window/)
- [使应用程序单实例化](https://leanflutter.dev/blog/making-the-app-single-instanced/)
