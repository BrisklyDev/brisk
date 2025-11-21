# hotkey_manager_platform_interface

[![pub version][pub-image]][pub-url]

[pub-image]: https://img.shields.io/pub/v/hotkey_manager_platform_interface.svg
[pub-url]: https://pub.dev/packages/hotkey_manager_platform_interface

A common platform interface for the [hotkey_manager](https://pub.dev/packages/hotkey_manager) plugin.

## Usage

To implement a new platform-specific implementation of hotkey_manager, extend `HotKeyManagerPlatform` with an implementation that performs the platform-specific behavior, and when you register your plugin, set the default `HotKeyManagerPlatform` by calling `HotKeyManagerPlatform.instance = MyPlatformHotKeyManager()`.

## License

[MIT](./LICENSE)
