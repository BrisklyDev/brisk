import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;
import 'package:window_manager/src/resize_edge.dart';
import 'package:window_manager/src/title_bar_style.dart';
import 'package:window_manager/src/utils/calc_window_position.dart';
import 'package:window_manager/src/window_listener.dart';
import 'package:window_manager/src/window_options.dart';

const kWindowEventClose = 'close';
const kWindowEventFocus = 'focus';
const kWindowEventBlur = 'blur';
const kWindowEventMaximize = 'maximize';
const kWindowEventUnmaximize = 'unmaximize';
const kWindowEventMinimize = 'minimize';
const kWindowEventRestore = 'restore';
const kWindowEventResize = 'resize';
const kWindowEventResized = 'resized';
const kWindowEventMove = 'move';
const kWindowEventMoved = 'moved';
const kWindowEventEnterFullScreen = 'enter-full-screen';
const kWindowEventLeaveFullScreen = 'leave-full-screen';

const kWindowEventDocked = 'docked';
const kWindowEventUndocked = 'undocked';

enum DockSide { left, right }

// WindowManager
class WindowManager {
  WindowManager._() {
    _channel.setMethodCallHandler(_methodCallHandler);
  }

  /// The shared instance of [WindowManager].
  static final WindowManager instance = WindowManager._();

  final MethodChannel _channel = const MethodChannel('window_manager');

  final ObserverList<WindowListener> _listeners =
      ObserverList<WindowListener>();

  Future<void> _methodCallHandler(MethodCall call) async {
    for (final WindowListener listener in listeners) {
      if (!_listeners.contains(listener)) {
        return;
      }

      if (call.method != 'onEvent') throw UnimplementedError();

      String eventName = call.arguments['eventName'];
      listener.onWindowEvent(eventName);
      Map<String, Function> funcMap = {
        kWindowEventClose: listener.onWindowClose,
        kWindowEventFocus: listener.onWindowFocus,
        kWindowEventBlur: listener.onWindowBlur,
        kWindowEventMaximize: listener.onWindowMaximize,
        kWindowEventUnmaximize: listener.onWindowUnmaximize,
        kWindowEventMinimize: listener.onWindowMinimize,
        kWindowEventRestore: listener.onWindowRestore,
        kWindowEventResize: listener.onWindowResize,
        kWindowEventResized: listener.onWindowResized,
        kWindowEventMove: listener.onWindowMove,
        kWindowEventMoved: listener.onWindowMoved,
        kWindowEventEnterFullScreen: listener.onWindowEnterFullScreen,
        kWindowEventLeaveFullScreen: listener.onWindowLeaveFullScreen,
        kWindowEventDocked: listener.onWindowDocked,
        kWindowEventUndocked: listener.onWindowUndocked,
      };
      funcMap[eventName]?.call();
    }
  }

  List<WindowListener> get listeners {
    final List<WindowListener> localListeners =
        List<WindowListener>.from(_listeners);
    return localListeners;
  }

  bool get hasListeners {
    return _listeners.isNotEmpty;
  }

  void addListener(WindowListener listener) {
    _listeners.add(listener);
  }

  void removeListener(WindowListener listener) {
    _listeners.remove(listener);
  }

  double getDevicePixelRatio() {
    // Subsequent version, remove this deprecated member.
    // ignore: deprecated_member_use
    return window.devicePixelRatio;
  }

  Future<void> ensureInitialized() async {
    await _channel.invokeMethod('ensureInitialized');
  }

  /// Returns `int` - The ID of the window.
  ///
  /// For macOS, the ID is the window number.
  /// For Windows, the ID is the window handle.
  ///
  /// @platforms macos,windows
  Future<int> getId() async {
    return await _channel.invokeMethod('getId') as int;
  }

  /// You can call this to remove the window frame (title bar, outline border, etc), which is basically everything except the Flutter view, also can call setTitleBarStyle(TitleBarStyle.normal) or setTitleBarStyle(TitleBarStyle.hidden) to restore it.
  Future<void> setAsFrameless() async {
    await _channel.invokeMethod('setAsFrameless');
  }

  /// Wait until ready to show.
  Future<void> waitUntilReadyToShow([
    WindowOptions? options,
    VoidCallback? callback,
  ]) async {
    await _channel.invokeMethod('waitUntilReadyToShow');

    if (options?.titleBarStyle != null) {
      await setTitleBarStyle(
        options!.titleBarStyle!,
        windowButtonVisibility: options.windowButtonVisibility ?? true,
      );
    }

    if (await isFullScreen()) await setFullScreen(false);
    if (await isMaximized()) await unmaximize();
    if (await isMinimized()) await restore();

    if (options?.size != null) await setSize(options!.size!);
    if (options?.center == true) await setAlignment(Alignment.center);
    if (options?.minimumSize != null) {
      await setMinimumSize(options!.minimumSize!);
    }
    if (options?.maximumSize != null) {
      await setMaximumSize(options!.maximumSize!);
    }
    if (options?.alwaysOnTop != null) {
      await setAlwaysOnTop(options!.alwaysOnTop!);
    }
    if (options?.fullScreen != null) await setFullScreen(options!.fullScreen!);
    if (options?.backgroundColor != null) {
      await setBackgroundColor(options!.backgroundColor!);
    }
    if (options?.skipTaskbar != null) {
      await setSkipTaskbar(options!.skipTaskbar!);
    }
    if (options?.title != null) await setTitle(options!.title!);

    if (callback != null) {
      callback();
    }
  }

  /// Force closing the window.
  Future<void> destroy() async {
    await _channel.invokeMethod('destroy');
  }

  /// Try to close the window.
  Future<void> close() async {
    await _channel.invokeMethod('close');
  }

  /// Check if is intercepting the native close signal.
  Future<bool> isPreventClose() async {
    return await _channel.invokeMethod('isPreventClose');
  }

  /// Set if intercept the native close signal. May useful when combine with the onclose event listener.
  /// This will also prevent the manually triggered close event.
  Future<void> setPreventClose(bool isPreventClose) async {
    final Map<String, dynamic> arguments = {
      'isPreventClose': isPreventClose,
    };
    await _channel.invokeMethod('setPreventClose', arguments);
  }

  /// Focuses on the window.
  Future<void> focus() async {
    await _channel.invokeMethod('focus');
  }

  /// Removes focus from the window.
  ///
  /// @platforms macos,windows
  Future<void> blur() async {
    await _channel.invokeMethod('blur');
  }

  /// Returns `bool` - Whether window is focused.
  ///
  /// @platforms macos,windows
  Future<bool> isFocused() async {
    return await _channel.invokeMethod('isFocused');
  }

  /// Shows and gives focus to the window.
  Future<void> show({bool inactive = false}) async {
    bool isMinimized = await this.isMinimized();
    if (isMinimized) {
      await restore();
    }
    final Map<String, dynamic> arguments = {
      'inactive': inactive,
    };
    await _channel.invokeMethod('show', arguments);
  }

  /// Hides the window.
  Future<void> hide() async {
    await _channel.invokeMethod('hide');
  }

  /// Returns `bool` - Whether the window is visible to the user.
  Future<bool> isVisible() async {
    return await _channel.invokeMethod('isVisible');
  }

  /// Returns `bool` - Whether the window is maximized.
  Future<bool> isMaximized() async {
    return await _channel.invokeMethod('isMaximized');
  }

  /// Maximizes the window. `vertically` simulates aero snap, only works on Windows
  Future<void> maximize({bool vertically = false}) async {
    final Map<String, dynamic> arguments = {
      'vertically': vertically,
    };
    await _channel.invokeMethod('maximize', arguments);
  }

  /// Unmaximizes the window.
  Future<void> unmaximize() async {
    await _channel.invokeMethod('unmaximize');
  }

  /// Returns `bool` - Whether the window is minimized.
  Future<bool> isMinimized() async {
    return await _channel.invokeMethod('isMinimized');
  }

  /// Minimizes the window. On some platforms the minimized window will be shown in the Dock.
  Future<void> minimize() async {
    await _channel.invokeMethod('minimize');
  }

  /// Restores the window from minimized state to its previous state.
  Future<void> restore() async {
    await _channel.invokeMethod('restore');
  }

  /// Returns `bool` - Whether the window is in fullscreen mode.
  Future<bool> isFullScreen() async {
    return await _channel.invokeMethod('isFullScreen');
  }

  /// Sets whether the window should be in fullscreen mode.
  Future<void> setFullScreen(bool isFullScreen) async {
    final Map<String, dynamic> arguments = {
      'isFullScreen': isFullScreen,
    };
    await _channel.invokeMethod('setFullScreen', arguments);
    // (Windows) Force refresh the app so it 's back to the correct size
    // (see GitHub issue #311)
    // if (Platform.isWindows) {
    //   final size = await getSize();
    //   setSize(size + const Offset(1, 1));
    //   setSize(size);
    // }
  }

  /// Returns `bool` - Whether the window is dockable or not.
  ///
  /// @platforms windows
  Future<bool> isDockable() async {
    return await _channel.invokeMethod('isDockable');
  }

  /// Returns `bool` - Whether the window is docked.
  ///
  /// @platforms windows
  Future<DockSide?> isDocked() async {
    int? docked = await _channel.invokeMethod('isDocked');
    if (docked == 0) return null;
    if (docked == 1) return DockSide.left;
    if (docked == 2) return DockSide.right;
    return null;
  }

  /// Docks the window. only works on Windows
  ///
  /// @platforms windows
  Future<void> dock({required DockSide side, required int width}) async {
    final Map<String, dynamic> arguments = {
      'left': side == DockSide.left,
      'right': side == DockSide.right,
      'width': width,
    };
    await _channel.invokeMethod('dock', arguments);
  }

  /// Undocks the window. only works on Windows
  ///
  /// @platforms windows
  Future<bool> undock() async {
    return await _channel.invokeMethod('undock');
  }

  /// This will make a window maintain an aspect ratio.
  Future<void> setAspectRatio(double aspectRatio) async {
    final Map<String, dynamic> arguments = {
      'aspectRatio': aspectRatio,
    };
    await _channel.invokeMethod('setAspectRatio', arguments);
  }

  /// Sets the background color of the window.
  Future<void> setBackgroundColor(Color backgroundColor) async {
    final Map<String, dynamic> arguments = {
      'backgroundColorA': (backgroundColor.a * 255).round() & 0xff,
      'backgroundColorR': (backgroundColor.r * 255).round() & 0xff,
      'backgroundColorG': (backgroundColor.g * 255).round() & 0xff,
      'backgroundColorB': (backgroundColor.b * 255).round() & 0xff,
    };
    await _channel.invokeMethod('setBackgroundColor', arguments);
  }

  /// Move the window to a position aligned with the screen.
  Future<void> setAlignment(
    Alignment alignment, {
    bool animate = false,
  }) async {
    Size windowSize = await getSize();
    Offset position = await calcWindowPosition(windowSize, alignment);
    await setPosition(position, animate: animate);
  }

  /// Moves window to the center of the screen.
  Future<void> center({
    bool animate = false,
  }) async {
    Size windowSize = await getSize();
    Offset position = await calcWindowPosition(windowSize, Alignment.center);
    await setPosition(position, animate: animate);
  }

  /// Returns `Rect` - The bounds of the window as Object.
  Future<Rect> getBounds() async {
    final Map<String, dynamic> arguments = {
      'devicePixelRatio': getDevicePixelRatio(),
    };
    final Map<dynamic, dynamic> resultData = await _channel.invokeMethod(
      'getBounds',
      arguments,
    );

    return Rect.fromLTWH(
      resultData['x'],
      resultData['y'],
      resultData['width'],
      resultData['height'],
    );
  }

  /// Resizes and moves the window to the supplied bounds.
  Future<void> setBounds(
    Rect? bounds, {
    Offset? position,
    Size? size,
    bool animate = false,
  }) async {
    final Map<String, dynamic> arguments = {
      'devicePixelRatio': getDevicePixelRatio(),
      'x': bounds?.topLeft.dx ?? position?.dx,
      'y': bounds?.topLeft.dy ?? position?.dy,
      'width': bounds?.size.width ?? size?.width,
      'height': bounds?.size.height ?? size?.height,
      'animate': animate,
    }..removeWhere((key, value) => value == null);
    await _channel.invokeMethod('setBounds', arguments);
  }

  /// Returns `Size` - Contains the window's width and height.
  Future<Size> getSize() async {
    Rect bounds = await getBounds();
    return bounds.size;
  }

  /// Resizes the window to `width` and `height`.
  Future<void> setSize(Size size, {bool animate = false}) async {
    await setBounds(
      null,
      size: size,
      animate: animate,
    );
  }

  /// Returns `Offset` - Contains the window's current position.
  Future<Offset> getPosition() async {
    Rect bounds = await getBounds();
    return bounds.topLeft;
  }

  /// Moves window to position.
  Future<void> setPosition(Offset position, {bool animate = false}) async {
    await setBounds(
      null,
      position: position,
      animate: animate,
    );
  }

  /// Sets the minimum size of window to `width` and `height`.
  Future<void> setMinimumSize(Size size) async {
    final Map<String, dynamic> arguments = {
      'devicePixelRatio': getDevicePixelRatio(),
      'width': size.width,
      'height': size.height,
    };
    await _channel.invokeMethod('setMinimumSize', arguments);
  }

  /// Sets the maximum size of window to `width` and `height`.
  Future<void> setMaximumSize(Size size) async {
    final Map<String, dynamic> arguments = {
      'devicePixelRatio': getDevicePixelRatio(),
      'width': size.width,
      'height': size.height,
    };
    await _channel.invokeMethod('setMaximumSize', arguments);
  }

  /// Returns `bool` - Whether the window can be manually resized by the user.
  Future<bool> isResizable() async {
    return await _channel.invokeMethod('isResizable');
  }

  /// Sets whether the window can be manually resized by the user.
  Future<void> setResizable(bool isResizable) async {
    final Map<String, dynamic> arguments = {
      'isResizable': isResizable,
    };
    await _channel.invokeMethod('setResizable', arguments);
  }

  /// Returns `bool` - Whether the window can be moved by user.
  ///
  /// @platforms macos
  Future<bool> isMovable() async {
    return await _channel.invokeMethod('isMovable');
  }

  /// Sets whether the window can be moved by user.
  ///
  /// @platforms macos
  Future<void> setMovable(bool isMovable) async {
    final Map<String, dynamic> arguments = {
      'isMovable': isMovable,
    };
    await _channel.invokeMethod('setMovable', arguments);
  }

  /// Returns `bool` - Whether the window can be manually minimized by the user.
  ///
  /// @platforms macos,windows
  Future<bool> isMinimizable() async {
    return await _channel.invokeMethod('isMinimizable');
  }

  /// Sets whether the window can be manually minimized by user.
  ///
  /// @platforms macos,windows
  Future<void> setMinimizable(bool isMinimizable) async {
    final Map<String, dynamic> arguments = {
      'isMinimizable': isMinimizable,
    };
    await _channel.invokeMethod('setMinimizable', arguments);
  }

  /// Returns `bool` - Whether the window can be manually closed by user.
  ///
  /// @platforms windows
  Future<bool> isClosable() async {
    return await _channel.invokeMethod('isClosable');
  }

  /// Returns `bool` - Whether the window can be manually maximized by the user.
  ///
  /// @platforms macos,windows
  Future<bool> isMaximizable() async {
    return await _channel.invokeMethod('isMaximizable');
  }

  /// Sets whether the window can be manually maximized by the user.
  Future<void> setMaximizable(bool isMaximizable) async {
    final Map<String, dynamic> arguments = {
      'isMaximizable': isMaximizable,
    };
    await _channel.invokeMethod('setMaximizable', arguments);
  }

  /// Sets whether the window can be manually closed by user.
  ///
  /// @platforms macos,windows
  Future<void> setClosable(bool isClosable) async {
    final Map<String, dynamic> arguments = {
      'isClosable': isClosable,
    };
    await _channel.invokeMethod('setClosable', arguments);
  }

  /// Returns `bool` - Whether the window is always on top of other windows.
  Future<bool> isAlwaysOnTop() async {
    return await _channel.invokeMethod('isAlwaysOnTop');
  }

  /// Sets whether the window should show always on top of other windows.
  Future<void> setAlwaysOnTop(bool isAlwaysOnTop) async {
    final Map<String, dynamic> arguments = {
      'isAlwaysOnTop': isAlwaysOnTop,
    };
    await _channel.invokeMethod('setAlwaysOnTop', arguments);
  }

  /// Returns `bool` - Whether the window is always below other windows.
  Future<bool> isAlwaysOnBottom() async {
    return await _channel.invokeMethod('isAlwaysOnBottom');
  }

  /// Sets whether the window should show always below other windows.
  ///
  /// @platforms linux,windows
  Future<void> setAlwaysOnBottom(bool isAlwaysOnBottom) async {
    final Map<String, dynamic> arguments = {
      'isAlwaysOnBottom': isAlwaysOnBottom,
    };
    await _channel.invokeMethod('setAlwaysOnBottom', arguments);
  }

  /// Returns `String` - The title of the native window.
  Future<String> getTitle() async {
    return await _channel.invokeMethod('getTitle');
  }

  /// Changes the title of native window to title.
  Future<void> setTitle(String title) async {
    final Map<String, dynamic> arguments = {
      'title': title,
    };
    await _channel.invokeMethod('setTitle', arguments);
  }

  /// Changes the title bar style of native window.
  Future<void> setTitleBarStyle(
    TitleBarStyle titleBarStyle, {
    bool windowButtonVisibility = true,
  }) async {
    final Map<String, dynamic> arguments = {
      'titleBarStyle': titleBarStyle.name,
      'windowButtonVisibility': windowButtonVisibility,
    };
    await _channel.invokeMethod('setTitleBarStyle', arguments);
  }

  /// Returns `int` - The title bar height of the native window.
  Future<int> getTitleBarHeight() async {
    return await _channel.invokeMethod('getTitleBarHeight');
  }

  /// Returns `bool` - Whether skipping taskbar is enabled.
  Future<bool> isSkipTaskbar() async {
    return await _channel.invokeMethod('isSkipTaskbar');
  }

  /// Makes the window not show in the taskbar / dock.
  Future<void> setSkipTaskbar(bool isSkipTaskbar) async {
    final Map<String, dynamic> arguments = {
      'isSkipTaskbar': isSkipTaskbar,
    };
    await _channel.invokeMethod('setSkipTaskbar', arguments);
  }

  /// Sets progress value in progress bar. Valid range is [0, 1.0].
  ///
  /// @platforms macos,windows
  Future<void> setProgressBar(double progress) async {
    final Map<String, dynamic> arguments = {
      'progress': progress,
    };
    await _channel.invokeMethod('setProgressBar', arguments);
  }

  /// Sets window/taskbar icon.
  ///
  /// @platforms windows
  Future<void> setIcon(String iconPath) async {
    final Map<String, dynamic> arguments = {
      'iconPath': path.joinAll([
        path.dirname(Platform.resolvedExecutable),
        'data/flutter_assets',
        iconPath,
      ]),
    };

    await _channel.invokeMethod('setIcon', arguments);
  }

  /// Returns `bool` - Whether the window is visible on all workspaces.
  ///
  /// @platforms macos
  Future<bool> isVisibleOnAllWorkspaces() async {
    return await _channel.invokeMethod('isVisibleOnAllWorkspaces');
  }

  /// Sets whether the window should be visible on all workspaces.
  ///
  /// Note: If you need to support dragging a window on top of a fullscreen
  /// window on another screen, you need to modify MainFlutterWindow
  /// to inherit from NSPanel
  ///
  /// ```swift
  /// class MainFlutterWindow: NSPanel {
  ///     // ...
  /// }
  /// ```
  ///
  /// @platforms macos
  Future<void> setVisibleOnAllWorkspaces(
    bool visible, {
    bool? visibleOnFullScreen,
  }) async {
    final Map<String, dynamic> arguments = {
      'visible': visible,
      'visibleOnFullScreen': visibleOnFullScreen ?? false,
    };
    await _channel.invokeMethod('setVisibleOnAllWorkspaces', arguments);
  }

  /// Set/unset label on taskbar(dock) app icon
  ///
  /// Note that it's required to request access at your AppDelegate.swift like this:
  /// UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge])
  ///
  /// @platforms macos
  Future<void> setBadgeLabel([String? label]) async {
    final Map<String, dynamic> arguments = {
      'label': label ?? '',
    };
    await _channel.invokeMethod('setBadgeLabel', arguments);
  }

  /// Returns `bool` - Whether the window has a shadow. On Windows, always returns true unless window is frameless.
  ///
  /// @platforms macos,windows
  Future<bool> hasShadow() async {
    return await _channel.invokeMethod('hasShadow');
  }

  /// Sets whether the window should have a shadow. On Windows, doesn't do anything unless window is frameless.
  ///
  /// @platforms macos,windows
  Future<void> setHasShadow(bool hasShadow) async {
    final Map<String, dynamic> arguments = {
      'hasShadow': hasShadow,
    };
    await _channel.invokeMethod('setHasShadow', arguments);
  }

  /// Returns `double` - between 0.0 (fully transparent) and 1.0 (fully opaque).
  Future<double> getOpacity() async {
    return await _channel.invokeMethod('getOpacity');
  }

  /// Sets the opacity of the window.
  Future<void> setOpacity(double opacity) async {
    final Map<String, dynamic> arguments = {
      'opacity': opacity,
    };
    await _channel.invokeMethod('setOpacity', arguments);
  }

  /// Sets the brightness of the window.
  Future<void> setBrightness(Brightness brightness) async {
    final Map<String, dynamic> arguments = {
      'brightness': brightness.name,
    };
    await _channel.invokeMethod('setBrightness', arguments);
  }

  /// Makes the window ignore all mouse events.
  ///
  /// All mouse events happened in this window will be passed to the window below this window, but if this window has focus, it will still receive keyboard events.
  Future<void> setIgnoreMouseEvents(bool ignore, {bool forward = false}) async {
    final Map<String, dynamic> arguments = {
      'ignore': ignore,
      'forward': forward,
    };
    await _channel.invokeMethod('setIgnoreMouseEvents', arguments);
  }

  Future<void> popUpWindowMenu() async {
    final Map<String, dynamic> arguments = {};
    await _channel.invokeMethod('popUpWindowMenu', arguments);
  }

  /// Starts a window drag based on the specified mouse-down event.
  /// On Windows, this is disabled during full screen mode.
  Future<void> startDragging() async {
    if (Platform.isWindows && await isFullScreen()) return;
    await _channel.invokeMethod('startDragging');
  }

  /// Starts a window resize based on the specified mouse-down & mouse-move event.
  /// On Windows, this is disabled during full screen mode.
  ///
  /// @platforms linux,windows
  Future<void> startResizing(ResizeEdge resizeEdge) async {
    if (Platform.isWindows && await isFullScreen()) return;
    await _channel.invokeMethod<bool>(
      'startResizing',
      {
        'resizeEdge': resizeEdge.name,
        'top': resizeEdge == ResizeEdge.top ||
            resizeEdge == ResizeEdge.topLeft ||
            resizeEdge == ResizeEdge.topRight,
        'bottom': resizeEdge == ResizeEdge.bottom ||
            resizeEdge == ResizeEdge.bottomLeft ||
            resizeEdge == ResizeEdge.bottomRight,
        'right': resizeEdge == ResizeEdge.right ||
            resizeEdge == ResizeEdge.topRight ||
            resizeEdge == ResizeEdge.bottomRight,
        'left': resizeEdge == ResizeEdge.left ||
            resizeEdge == ResizeEdge.topLeft ||
            resizeEdge == ResizeEdge.bottomLeft,
      },
    );
  }

  /// Grabs the keyboard.
  /// @platforms linux
  Future<bool> grabKeyboard() async {
    return await _channel.invokeMethod('grabKeyboard');
  }

  /// Ungrabs the keyboard.
  /// @platforms linux
  Future<bool> ungrabKeyboard() async {
    return await _channel.invokeMethod('ungrabKeyboard');
  }
}

final windowManager = WindowManager.instance;
