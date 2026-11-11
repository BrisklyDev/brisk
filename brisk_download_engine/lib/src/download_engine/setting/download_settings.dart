import 'dart:io';

import 'package:brisk_download_engine/src/download_engine/client/http_client_settings.dart';
import 'package:brisk_download_engine/src/download_engine/engine_type.dart';
import 'package:brisk_download_engine/src/download_engine/setting/proxy_setting.dart';

class DownloadSettings extends ConnectionSettings {
  final Directory baseSaveDir;
  int totalConnections;
  int totalM3u8Connections;

  EngineType engineType;

  /// Default speed limit of each download in bytes per second. 0 means unlimited.
  /// Only supported by the kasma engine.
  int speedLimitBytesPerSec;

  DownloadSettings({
    required this.baseSaveDir,
    required this.totalConnections,
    required this.totalM3u8Connections,
    required super.loggerEnabled,
    required super.baseTempDir,
    required super.connectionRetryTimeoutMillis,
    required super.maxConnectionRetryCount,
    super.clientSettings,
    this.engineType = EngineType.standard,
    this.speedLimitBytesPerSec = 0,
  });
}

class ConnectionSettings {
  final Directory baseTempDir;
  final int connectionRetryTimeoutMillis;
  final int maxConnectionRetryCount;
  final bool loggerEnabled;
  final HttpClientSettings? clientSettings;

  ConnectionSettings({
    required this.baseTempDir,
    required this.connectionRetryTimeoutMillis,
    required this.maxConnectionRetryCount,
    required this.loggerEnabled,
    this.clientSettings,
  });
}
