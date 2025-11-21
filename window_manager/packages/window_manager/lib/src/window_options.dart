import 'dart:ui';

import 'package:window_manager/src/title_bar_style.dart';

/// WindowOptions
class WindowOptions {
  const WindowOptions({
    this.size,
    this.center,
    this.minimumSize,
    this.maximumSize,
    this.alwaysOnTop,
    this.fullScreen,
    this.backgroundColor,
    this.skipTaskbar,
    this.title,
    this.titleBarStyle,
    this.windowButtonVisibility,
  });

  final Size? size;
  final bool? center;
  final Size? minimumSize;
  final Size? maximumSize;
  final bool? alwaysOnTop;
  final bool? fullScreen;
  final Color? backgroundColor;
  final bool? skipTaskbar;
  final String? title;
  final TitleBarStyle? titleBarStyle;
  final bool? windowButtonVisibility;
}
