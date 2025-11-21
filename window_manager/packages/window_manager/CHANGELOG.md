## 0.5.1

* fix: Fix PrivacyInfo.xcprivacy warning for macOS Desktop on Mac M1 macOS 15 (Sequoia) (#550)

### 0.5.0

* feat: Add `getId` method for retrieving window ID on macOS and Windows
* feat: Add `getWindowHandle` method (#548)
* feat: Add Swift Package Manager support
* fix: Crash when using window_manager by multi engine on Windows platform (#546)
* fix: [Windows] Use frameless window to implement fullscreen (#531)
* fix: Initialize window_hints to fix minimum size setting in release mode (#510)

### 0.4.3

* [windows] fix: scale ratio on dpi change (#496)
* [windows] fix: get window monitor from minimized state (#495)

### 0.4.2

* [windows] Update window_manager_plugin.cpp for fix #439 issue #486
* [windows] fix: win, adjustNCCALCSIZE with monitor coords #482

### 0.4.0

* chore: Use custom paint icons to replace png icons (#467)
* chore: Remove the deprecated isBezeled property (#468)
* fix: windows, window size, fullscree & maximized (#477)

### 0.3.9

* fix(windows): fix TitleBar buttons does not display correctly #415
* fix(windows): crash after deconstruction #423
* fix(windows): WindowManager.IsFocused() method (#461)

### 0.3.8

* Updates minimum supported SDK version to Flutter 3.3/Dart 3.0.
* [windows] fix #396 fullscreen/unfullscreen events, disable minimize on fullscreen #409
* setAlignment support custom Alignment #424

### 0.3.7

* [windows] Wrong window position in fullscreen mode with external monitor #405
* [windows] fix: incorrect window size before/after setTitleBarStyle #401
* [windows] Fix #389 setAsFrameless on titleBarStyle.normal #400

### 0.3.6

* [macos] Fix incorrect centering when multi-screen
* [windows] feat: restore Windows 7 support (#388)
* [windows] Better fullscreen implementation (#367)

### 0.3.5

* [macos] fixes setMinimumSize and setMaximumSize (#341)
* [windows] Remove app cut at the bottom and force refresh when back from fullscreen (#359), Fixes #311, #266, #228, #355, #237
* [linux] fix: on-close event handler not be triggered on flutter >= 3.10 (#343)
* [linux] feat: Dock Window to Screen like Taskbar (#347)

### 0.3.4

* [macos] Fix blur and focus events when the MainFlutterWindow extends from NSPanel

## 0.3.3

* [macos] feat: setTitleBarStyle() restores window frame on Linux (#323)
* [macos] Implement `isVisibleOnAllWorkspaces` & `setVisibleOnAllWorkspaces` methods

## 0.3.2

* [macos] Feature to set labeled badge on taskbar aka dock (#305)
* [linux] remove the margins of the window frame (#318)
* Add AlwaysOnBottom support for Windows (#306)
* [Windows] make setMinimum/MaximumSize() dpi change awareable (#231)
* remove frameless on set title bar style on macos (#240)
* chore: Add windowButtonVisibility to WindowOptions

## 0.3.1

* [linux] avoid removing shadows if no title is set (#297)
* [macos] Implement isMaximizable and setMaximizable (#290)
* Don't crash if an event doesn't have a dedicated handler (#286)
* Remove all subWindow related implementations

## 0.3.0

* Add integration test (#275)
* [windows] add show and hide events (#274)
* [linux] clean up state tracking (#273)
* Add missing future return values (#272)
* [linux] implement minimizable & maximizable (#270)
* [linux] fix getTitle() crash when null (#269)
* [linux] fix on_window_show and on_window_hide signatures (#268)

## 0.2.9

* [windows] Fix set maximizable throwing an error (#267)
* [linux] clean up unused includes (#260)
* [linux] fix window geometry hints (#257)
* [linux] pass the plugin instance around as user data (#256)
* [linux] fix `getOpacity()` (#255)
* [Linux] use g_strcmp0() (#254)
* [Linux] remove misleading C++-style default values (#253)
* [Linux] implement `setBrightness()` (#252)
* [Linux] fix frameless window & background color (#250)
* [Linux] make `setTitleBarStyle()` GTK/HDY/CSD/SSD compatible (#249)

## 0.2.8

* Bump screen_retriever from 0.1.2 to 0.1.4
* WindowOptions supports backgroundColor
* [linux] fix: offset lost after invoking gtk hide on linux #241
* [macos] Fix Unable to bridge NSNumber to Float #236
* [linux] Introduce grabKeyboard() and ungrabKeyboard() #229

## 0.2.7

* [linux] fix bottom edge resizing (#209)
* [linux] fix: cannot resize again after startResizing (#205)

## 0.2.6

* [windows] Added `vertically` param to the `maximize` method.
* [Linux] implementation of methods: setIcon, isFocused (#186)
* [macos] fix crash lead by fast clicks (#198)
* Remove decoration for maximized window (#191)
* [linux] fix: cannot drag again after startDragging (#203)
* [windows] Implement isMaximizable and setMaximizable (#200)
* [windows] Implement SetResizable for windows (#204)

## 0.2.5

* [linux] fix method response memory leaks (#159)
* [linux] Implement destroy #158
* [linux] Implement getOpacity & setOpacity #157
* [macos] Reimplement setBounds & getBounds method. #156
* Make WindowOptions constructor to const constructor. #147
* [windows] fix window overflow #131
* [macos] Add the animate parameter to setBounds method #142
* [linux] fix popUpWindowMenu() on Wayland #145

## 0.2.3

* Fixed cannot convert type Double to type CGFloat #138
* [linux & windows] Implement `popUpWindowMenu` metnod #141

## 0.2.2

* Fixed overflow error after minimize #55, #119, #125 
* Implement `isSkipTaskbar` method #117
* [windows] Implement setIcon method #129
* The `waitUntilReadyToShow` method adds options, callback parameters #111

## 0.2.1

* Compatible with lower versions of dart #98
* [macos & windows] Add `resized`, `moved` events. #28
* [linux] Implement `getTitleBarHeight` metnod #49
* [linux] Implement `getOpacity` metnod #44
* Add `TitleBarStyle` enum #99
* [linux] Implement `setAlwaysOnBottom` method #100
* [windows] Removes crazy jittering when resizing window #103
* [windows] Fix overflow on fullscreen and maximize #105
* [windows] Implement `setHasShadow` and `hasShadow` methods #110
* [windows] Fix setAlignment(Alignment.bottomRight) display position is not correct #112 #113

## 0.2.0

* [linux] Implement `setTitleBarStyle` method
* [linux] Implement `startResizing` method
* [windows] Implement `setProgressBar` method #42
* [macos & windows] Implement `setIgnoreMouseEvents` metnod #89
* Update `DragToResizeArea` widget
* Add `VirtualWindowFrame` widget
* Update `WindowCaption` widget

## 0.1.9

* Fixed Visual bug in fullScreen #83
* Update `WindowCaption` widget.

## 0.1.8

* Add `WindowCaption` widget. #81
* [macos & windows] Implement `destroy` method

## 0.1.7

* Implement `setAspectRatio` method #74
* [windows] Reimplement `getTitleBarHeight` method #33
* [windows] Implement `startResizing` method
* [windows] Add `DragToResizeArea` widget
* [windows] Fix maximize and minimize animation not working when there is title bar hidden

## 0.1.6

* Implement `isPreventClose` & `setPreventClose` methods #69
* Implement `close` event
* [macos & windows] Reimplement `close` method
* [windows] Fix Horizontal resizing not working on secondary display. #71
* [macos] Implement `isFocused` method
* Implement `setAlignment` method #52

## 0.1.5

* Implement `close` method #56
* Implement `center` method #59

## 0.1.4

* [macos & windows] Implemented getOpacity & setOpacity methods #37 #45
* [macos] Implement setProgressBar method #40
* [windows] Fix `focus`, `blur` event not responding
* [windows] Implement `focus` & `blur` methods
* [macos & windows] Implement getTitleBarHeight methods #34

## 0.1.3

* [windows] #31 Optimize setTitleBarStyle method.

## 0.1.2

* [macos] Add setTitleBarStyle method.
* [windows] Add setTitleBarStyle method (**Experiment**).
* [windows] #24 Updated windows fullscreen handling.
* [windows] #26 Make `maximize`, `unmaximize`, `minimize`, `restore` methods have native animation effects.

## 0.1.1

* [macos] Fixed `setSize` coordinate error.

## 0.1.0

* Implemented `isResizable`, `setResizable` Methods.
* Implemented `isClosable`, `setClosable` Methods.
* Removed `terminate` Method.
* [windows] Implemented `isMinimizable`, `setMinimizable` Methods.

## 0.0.5

* Implemented `setAsFrameless` Method.
* Implemented `setSkipTaskbar` Method.
* Implemented `focus`, `blur`, `maximize`, `unmaximize`, `minimize`, `restore`, `resize`, `move`, `enter-full-screen`, `leave-full-screen` Events.
* [macos] Implemented `hiddenWindowAtLaunch` Method.
* Fixed #10 

## 0.0.4

* Implemented `setCustomFrame`, `setBackgroundColor` Methods.

## 0.0.3

* Implemented `isMinimized`, `minimize`, `restore` Methods.
* Implemented `setMinimumSize`, `setMaximumSize` Methods.
* [windows] [#4](https://github.com/leanflutter/window_manager/issues/4) Do not set `HWND_TOPMOST` flag in `setFullScreen`

## 0.0.2

* Implemented `show`, `hide`, `isVisible` Methods.
* Implemented `isMaximized`, `maximize`, `unmaximize` Methods.
* Implemented `isFullScreen`, `setFullScreen` Methods.
* Implemented `getBounds`, `setBounds` Methods.
* Implemented `getPosition`, `setPosition` Methods.
* Implemented `getSize`, `setSize` Methods.
* Implemented `isAlwaysOnTop`, `setAlwaysOnTop` Methods.
* Implemented `terminate` Method.

## 0.0.1

* First release.
