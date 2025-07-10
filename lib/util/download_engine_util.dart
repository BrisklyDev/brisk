import 'package:brisk/model/download_item.dart';
import 'package:brisk/setting/settings_cache.dart';
import 'package:brisk_download_engine/brisk_download_engine.dart';

DownloadSettings downloadSettingsFromCache() {
  return DownloadSettings(
    baseTempDir: SettingsCache.temporaryDir,
    baseSaveDir: SettingsCache.saveDir,
    totalConnections: SettingsCache.connectionsNumber,
    totalM3u8Connections: SettingsCache.m3u8ConnectionNumber,
    connectionRetryTimeoutMillis: SettingsCache.connectionRetryTimeout * 1000,
    maxConnectionRetryCount: SettingsCache.connectionRetryCount,
    loggerEnabled: SettingsCache.loggerEnabled,
    clientSettings: HttpClientSettings(
      proxySetting: SettingsCache.proxySetting,
      clientType: SettingsCache.httpClientType,
    ),
  );
}

DownloadItemModel buildFromDownloadItem(DownloadItem item) {
  return DownloadItemModel(
    id: item.key,
    fileName: item.fileName,
    downloadUrl: item.downloadUrl,
    startDate: item.startDate,
    progress: item.progress,
    fileSize: item.contentLength,
    filePath: item.filePath,
    fileType: item.fileType,
    finishDate: item.finishDate,
    status: item.status,
    supportsPause: item.supportsPause,
    uid: item.uid,
    m3u8Content: item.extraInfo["m3u8Content"],
    duration: item.extraInfo["duration"],
    refererHeader: item.extraInfo["refererHeader"],
    requestHeaders: item.requestHeaders,
  );
}
