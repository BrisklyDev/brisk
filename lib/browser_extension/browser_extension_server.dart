import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:brisk/constants/setting_options.dart';
import 'package:brisk/constants/setting_type.dart';
import 'package:brisk/db/hive_util.dart';
import 'package:brisk/l10n/app_localizations.dart';
import 'package:brisk/model/download_item.dart';
import 'package:brisk/model/setting.dart';
import 'package:brisk/util/app_logger.dart';
import 'package:brisk/util/auto_updater_util.dart';
import 'package:brisk/util/download_addition_ui_util.dart';
import 'package:brisk/util/file_util.dart';
import 'package:brisk/util/http_util.dart';
import 'package:brisk/util/parse_util.dart';
import 'package:brisk/setting/settings_cache.dart';
import 'package:brisk/util/ui_util.dart';
import 'package:brisk/widget/base/error_dialog.dart';
import 'package:brisk/widget/download/m3u8_master_playlist_dialog.dart';
import 'package:brisk/widget/download/update_available_dialog.dart';
import 'package:brisk/widget/loader/file_info_loader.dart';
import 'package:brisk_download_engine/brisk_download_engine.dart';
import 'package:brisk_download_engine/src/download_engine/client/custom_base_client.dart';
import 'package:dartx/dartx.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:window_to_front/window_to_front.dart';
import 'package:window_manager/window_manager.dart';
import 'package:brisk/widget/download/multi_download_addition_dialog.dart';

class BrowserExtensionServer {
  static bool _cancelClicked = false;
  static const String extensionVersion = "1.4.0";
  static DownloadItem? awaitingUpdateUrlItem;
  static HttpServer? _server;

  /// A map of prefetch vtt and m3u8 data by tabId coming form the extension
  static Map<int, List<M3U8>> _m3u8PrefetchCache = {};
  static Map<int, Map<String, String>> vttPrefetchCache = {};
  static Map<int, List<Pair<String, String>>> _fetchedVtts = {};
  static Timer? _m3u8PrefetchCacheClearTimer;

  /// To be able to reuse the http client, cached vtts will try be fetched every
  /// 3 seconds and the first pair argument determines how many times the timer
  /// should run in total.
  static Map<int, Pair<int, Timer?>> _vttFetcherTimers = {};

  static Future<void> setup(BuildContext context) async {
    showNewBrowserExtensionVersion(context);
    if (_server != null) return;
    _m3u8PrefetchCacheClearTimer = Timer.periodic(
      Duration(minutes: 5),
      (_) => _m3u8PrefetchCache.clear(),
    );

    final port = _extensionPort;
    try {
      _server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
      handleExtensionRequests(context);
    } catch (e) {
      if (e.toString().contains("Invalid port")) {
        _showInvalidPortError(context, port.toString());
        return;
      }
      if (e.toString().contains("Only one usage of each socket address")) {
        _showPortInUseError(context, port.toString());
        return;
      }
      _showUnexpectedError(context, port.toString(), e);
    }
  }

  static Future<void> restart(BuildContext context) async {
    _vttFetcherTimers.clear();
    vttPrefetchCache.clear();
    _m3u8PrefetchCache.clear();
    _m3u8PrefetchCacheClearTimer?.cancel();
    _m3u8PrefetchCacheClearTimer = null;
    _vttFetcherTimers.forEach((_, value) => value.second?.cancel());
    await _server?.close(force: true);
    _server = null;
    await Future.delayed(Duration(milliseconds: 300));
    await setup(context);
  }

  static Future<void> handleExtensionRequests(BuildContext context) async {
    await for (HttpRequest request in _server!) {
      runZonedGuarded(() async {
        bool responseClosed = false;
        try {
          addCORSHeaders(request);
          final jsonBody = await _jsonifyBody(request);
          if (jsonBody == null) {
            await flushAndCloseResponse(request, false);
            return;
          }
          final targetVersion = jsonBody["extensionVersion"];
          if (targetVersion == null || targetVersion.toString().isNullOrBlank) {
            await request.response.close();
            responseClosed = true;
            return;
          }
          if (isNewVersionAvailable(extensionVersion, targetVersion)) {
            showNewBrowserExtensionVersion(context);
          }
          if (request.uri.path == '/fetch-m3u8') {
            _fetchAndCacheM3u8(request, jsonBody);
            return;
          }
          if (request.uri.path == '/fetch-vtt') {
            _fetchAndCacheVtt(request, jsonBody);
            return;
          }
          final success = await _handleDownloadAddition(
            jsonBody,
            context,
            request,
          );
          await flushAndCloseResponse(request, success);
          responseClosed = true;
        } catch (e, stack) {
          Logger.log("Request handling error: $e\n$stack");
          try {
            Logger.log("responseClosed? $responseClosed");
            if (!responseClosed) {
              Logger.log("Closing response...");
              await flushAndCloseResponse(request, false);
            }
          } catch (_) {}
        }
      }, (error, stack) {
        if (error == "Failed to get file information") {
          DownloadAdditionUiUtil.showFileInfoErrorDialog(context);
          flushAndCloseResponse(request, false);
          return;
        }
        Logger.log("Unhandled error in request zone: $error\n$stack");
      });
    }
  }

  static dynamic _jsonifyBody(HttpRequest request) async {
    final bodyBytes = await request.fold<List<int>>(
      [],
      (previous, element) => previous..addAll(element),
    );
    final body = utf8.decode(bodyBytes);
    if (body.isEmpty) {
      return null;
    }
    return jsonDecode(body);
  }

  static void _fetchAndCacheVtt(HttpRequest request, jsonBody) async {
    final tabId = jsonBody['tabId'];
    vttPrefetchCache[tabId] ??= {};
    _fetchedVtts[tabId] ??= [];
    vttPrefetchCache[tabId]!.addAll(
      {jsonBody['url']: jsonBody['referer']},
    );
    if (_vttFetcherTimers[tabId] == null) {
      final client = await HttpClientBuilder.buildClient(
        SettingsCache.clientSettings,
      );
      _vttFetcherTimers[tabId] ??= Pair(
        1,
        Timer.periodic(
          Duration(seconds: 3),
          (timer) => _fetchAndCacheVttSubtitles(tabId, timer, client),
        ),
      );
    }
    await flushAndCloseResponse(request, true);
  }

  static void _fetchAndCacheVttSubtitles(
    tabId,
    Timer timer,
    CustomBaseClient client,
  ) {
    if (_vttFetcherTimers[tabId]!.first > 2) {
      timer.cancel();
    }
    vttPrefetchCache.forEach((tabId, vtts) {
      vtts.forEach((url, referer) {
        final alreadyFetched =
            _fetchedVtts[tabId]!.any((pair) => pair.first == url);
        if (alreadyFetched) {
          return;
        }
        final uri = Uri.parse(url);
        final headers = {
          'referer': referer ?? '',
          'User-Agent': userAgentHeader.values.first
        };
        client.get(uri, headers: headers).then((response) {
          if (response.statusCode == 200) {
            _fetchedVtts[tabId]!.add(Pair(url, response.body));
          }
        });
      });
    });
    _vttFetcherTimers[tabId] = Pair(_vttFetcherTimers[tabId]!.first + 1, timer);
  }

  static void _fetchAndCacheM3u8(request, jsonBody) async {
    final url = jsonBody['url'];
    final referer = jsonBody['referer'];
    final suggestedName = jsonBody['suggestedName'];
    final tabId = jsonBody['tabId'];
    M3U8 m3u8;
    try {
      m3u8 = await _downloadAndParseM3u8Meta(
        url,
        refererHeader: referer,
        suggestedName: suggestedName,
      );
    } catch (e) {
      flushAndCloseResponse(request, false);
      return;
    }
    final responseBody = {};
    _m3u8PrefetchCache[tabId] = [];
    _m3u8PrefetchCache[tabId]!.add(m3u8);
    if (m3u8.isMasterPlaylist) {
      m3u8.setStreamInfsResolutionFileName();
      for (final streamInf in m3u8.streamInfos) {
        if (streamInf.m3u8 != null) {
          _m3u8PrefetchCache[tabId]!.add(streamInf.m3u8!);
        }
      }
      final streamInfs = m3u8.streamInfos
          .map(
            (s) => {
              'url': s.m3u8!.url,
              'resolution': s.resolution,
              'fileName': s.m3u8!.fileName,
            },
          )
          .toList();
      responseBody['streamInfs'] = streamInfs;
    }
    responseBody['referer'] = referer;
    responseBody['isMasterPlaylist'] = m3u8.isMasterPlaylist;
    responseBody['fileName'] = m3u8.fileName;
    responseBody['url'] = m3u8.url;
    responseBody['captured'] = true;
    await sendResponse(request, responseBody);
  }

  static void showNewBrowserExtensionVersion(BuildContext context) async {
    var lastNotify = HiveUtil.getSetting(
      SettingOptions.lastBrowserExtensionUpdateNotification,
    );
    if (lastNotify == null) {
      lastNotify = Setting(
        name: "lastBrowserExtensionUpdateNotification",
        value: "0",
        settingType: SettingType.system.name,
      );
      await HiveUtil.instance.settingBox.add(lastNotify);
    }
    if (int.parse(lastNotify.value) + 86400000 >
        DateTime.now().millisecondsSinceEpoch) {
      return;
    }
    final changeLog = await getLatestVersionChangeLog(
      browserExtension: true,
      removeChangeLogHeader: true,
    );
    showDialog(
      barrierDismissible: false,
      context: context,
      builder: (context) => UpdateAvailableDialog(
        isBrowserExtension: true,
        newVersion: extensionVersion,
        changeLog: changeLog,
        onUpdatePressed: () => launchUrlString(
          "https://github.com/AminBhst/brisk-browser-extension",
        ),
        onLaterPressed: () {
          lastNotify!.value = DateTime.now().millisecondsSinceEpoch.toString();
          lastNotify.save();
        },
      ),
    );
  }

  static Future<bool> _handleDownloadAddition(
      jsonBody, context, request) async {
    final type = jsonBody["type"] as String;
    switch (type.toLowerCase()) {
      case "single":
        return _handleSingleDownloadRequest(jsonBody, context, request);
      case "multi":
        _handleMultiDownloadRequest(jsonBody, context, request);
        return true;
      case "m3u8":
        _handleM3u8DownloadRequest(jsonBody, context, request);
        return true;
      default:
        return false;
    }
  }

  static void _handleM3u8DownloadRequest(jsonBody, context, request) async {
    handleWindowToFront();
    final subtitles = await _fetchVttSubtitles(jsonBody, context);
    final m3u8 = await _fetchM3u8(jsonBody, context);
    if (m3u8 == null) {
      safePop(context);
      DownloadAdditionUiUtil.showFileInfoErrorDialog(context);
      return;
    }
    if (m3u8.isMasterPlaylist) {
      _handleMasterPlaylist(m3u8, context, subtitles);
      return;
    }
    DownloadAdditionUiUtil.handleM3u8Addition(
      m3u8,
      context,
      subtitles,
    );
  }

  static Future<M3U8?> _fetchM3u8(jsonBody, context) async {
    final tabId = jsonBody['tabId'];
    final url = jsonBody['m3u8Url'] as String;
    M3U8? m3u8 =
        _m3u8PrefetchCache[tabId]?.where((m3u8) => m3u8.url == url).firstOrNull;
    if (m3u8 != null) {
      return m3u8;
    }
    bool canceled = false;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => FileInfoLoader(
        onCancelPressed: () {
          canceled = true;
          safePop(context);
        },
      ),
    );
    var suggestedName = jsonBody["suggestedName"] as String?;
    if (FileUtil.isFileNameInvalid(suggestedName) ||
        suggestedName != null && suggestedName.isEmpty) {
      suggestedName = null;
    }
    final refererHeader = jsonBody["refererHeader"] as String?;
    try {
      m3u8 = await _downloadAndParseM3u8Meta(
        url,
        refererHeader: refererHeader,
        suggestedName: suggestedName,
      );
    } catch (e) {
      if (canceled) {
        return null;
      }
    }
    if (m3u8 != null) {
      safePop(context);
    }
    return m3u8;
  }

  /// Fetches the subtitles from the prefetched cache and if empty, downloads them
  static Future<List<Map<String, String>>> _fetchVttSubtitles(
    jsonBody,
    context,
  ) async {
    final tabId = jsonBody['tabId'];
    List<Pair<String, String>>? subtitles = _fetchedVtts[tabId];
    bool foundInCache = true;
    if (_fetchedVtts[tabId] == null || _fetchedVtts[tabId]!.isEmpty) {
      foundInCache = false;
      final List<Map<String, String>> vttUrls = (jsonBody['vttUrls'] as List?)
              ?.map((item) => (item as Map).map<String, String>(
                    (key, value) =>
                        MapEntry(key.toString(), value?.toString() ?? ""),
                  ))
              .toList() ??
          [];
      try {
        _showLoadingDialog(
          context,
          customMessage: AppLocalizations.of(context)!.fetchingSubtitles,
        );
        subtitles = await fetchSubtitlesIsolate(
          vttUrls,
          SettingsCache.clientSettings,
        );
      } catch (e) {
        Logger.log("Failed to fetch subs ${e}");
      }
    }
    if (!foundInCache) {
      safePop(context);
    }
    return subtitles
            ?.map((p) => {'url': p.first, 'content': p.second})
            .toList() ??
        [];
  }

  static Future<M3U8> _downloadAndParseM3u8Meta(
    String url, {
    String? refererHeader,
    String? suggestedName,
  }) async {
    String m3u8Content = await fetchBodyString(
      url,
      clientSettings: SettingsCache.clientSettings,
      headers: refererHeader != null
          ? {
              HttpHeaders.refererHeader: refererHeader,
            }
          : {},
    );
    return (await M3U8.fromString(
      m3u8Content,
      url,
      clientSettings: SettingsCache.clientSettings,
      refererHeader: refererHeader,
      suggestedFileName: suggestedName,
    ))!;
  }

  static void _handleMasterPlaylist(
    M3U8 m3u8,
    BuildContext context,
    List<Map<String, String>> subtitles,
  ) {
    showDialog(
      context: context,
      builder: (context) => M3u8MasterPlaylistDialog(
        m3u8: m3u8,
        subtitles: subtitles,
      ),
      barrierDismissible: false,
    );
  }

  static Future<void> sendResponse(HttpRequest request, body) async {
    try {
      final responseBody = jsonEncode(body);
      request.response.write(responseBody);
      await request.response.flush();
      await request.response.close();
    } catch (_) {
      try {
        await request.response.close();
      } catch (_) {}
    }
  }

  static Future<void> flushAndCloseResponse(
    HttpRequest request,
    bool success,
  ) async {
    return await sendResponse(request, {"captured": success});
  }

  static void addCORSHeaders(HttpRequest httpRequest) {
    httpRequest.response.headers.add("Access-Control-Allow-Origin", "*");
    httpRequest.response.headers.add("Access-Control-Allow-Headers", "*");
  }

  static void _handleMultiDownloadRequest(jsonBody, context, request) {
    List downloadHrefs = jsonBody["data"]["downloadHrefs"];
    final referer = jsonBody['data']['referer'];
    if (downloadHrefs.isEmpty) return;
    downloadHrefs = downloadHrefs.toSet().toList() // removes duplicates
      ..removeWhere((url) => !isUrlValid(url));
    final downloadItems =
        downloadHrefs.map((e) => DownloadItem.fromUrl(e)).toList();
    downloadItems.forEach((item) => item.referer = referer);
    _cancelClicked = false;
    _showLoadingDialog(context);
    requestFileInfoBatch(
      downloadItems.toList(),
      SettingsCache.clientSettings,
    ).then((fileInfos) {
      if (_cancelClicked) {
        return;
      }
      fileInfos?.removeWhere(
        (fileInfo) => SettingsCache.extensionSkipCaptureRules.any(
          (rule) => rule.isSatisfiedByFileInfo(fileInfo),
        ),
      );
      handleWindowToFront();
      safePop(context);
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => MultiDownloadAdditionDialog(fileInfos!),
      );
    }).onError((error, stackTrace) =>
        DownloadAdditionUiUtil.onFileInfoRetrievalError(context));
  }

  static void handleWindowToFront() {
    if (_windowToFrontEnabled) {
      windowManager.show().then((_) => WindowToFront.activate());
    }
  }

  static void _showLoadingDialog(context, {String? customMessage}) {
    showDialog(
      barrierDismissible: false,
      context: context,
      builder: (_) => FileInfoLoader(
          message: customMessage,
          onCancelPressed: () {
            _cancelClicked = true;
            safePop(context);
          }),
    );
  }

  static Future<bool> _handleSingleDownloadRequest(
    jsonBody,
    context,
    request,
  ) async {
    final loc = AppLocalizations.of(context)!;
    final url = jsonBody['data']['url'];
    final referer = jsonBody['data']['referer'];
    final cookie = jsonBody['data']['cookie'];
    Completer<bool> completer = Completer();
    if (awaitingUpdateUrlItem != null) {
      final id = awaitingUpdateUrlItem!.key;
      DownloadAdditionUiUtil.handleDownloadAddition(
        downloadId: id,
        context,
        url,
        updateDialog: true,
        additionalPop: true,
        headers: cookie != null ? {'Cookie': cookie} : {},
      );
      completer.complete(true);
      return completer.future;
    }
    final downloadItem = DownloadItem.fromUrl(url);
    downloadItem.referer = referer;
    if (cookie != null) {
      downloadItem.requestHeaders = {'Cookie': cookie};
    }
    if (!isUrlValid(url)) {
      completer.complete(false);
    }
    final fileInfoResponse = DownloadAdditionUiUtil.requestFileInfo(
      url,
      headers: downloadItem.requestHeaders,
    );
    fileInfoResponse.then((fileInfo) {
      final satisfied = SettingsCache.extensionSkipCaptureRules.any(
        (rule) => rule.isSatisfiedByFileInfo(fileInfo),
      );
      if (satisfied) {
        completer.complete(false);
        return;
      }
      handleWindowToFront();
      DownloadAdditionUiUtil.addDownload(
        downloadItem,
        fileInfo,
        context,
        false,
      );
      completer.complete(true);
    });
    return completer.future;
  }

  static int get _extensionPort => int.parse(
        HiveUtil.getSetting(SettingOptions.extensionPort)?.value ?? "3020",
      );

  static bool get _windowToFrontEnabled => parseBool(
        HiveUtil.getSetting(SettingOptions.enableWindowToFront)?.value ??
            "true",
      );

  static void _showPortInUseError(BuildContext context, String port) {
    showDialog(
        context: context,
        builder: (context) => ErrorDialog(
            width: 580,
            height: 160,
            textHeight: 70,
            title: "Port ${port} is already in use by another process!",
            description:
                "\nFor optimal browser integration, please change the extension port in [Settings->Extension->Port] then restart the app."
                " Finally, set the same port number for the browser extension by clicking on its icon."));
  }

  static void _showInvalidPortError(BuildContext context, String port) {
    showDialog(
      context: context,
      builder: (context) => ErrorDialog(
          width: 400,
          height: 120,
          textHeight: 20,
          textSpaceBetween: 18,
          title: "Port $port is invalid!",
          description:
              "Please set a valid port value in app settings, then set the same value for the browser extension"),
    );
  }

  static void _showUnexpectedError(BuildContext context, String port, e) {
    showDialog(
      context: context,
      builder: (context) => ErrorDialog(
        width: 750,
        height: 200,
        textHeight: 40,
        textSpaceBetween: 10,
        title: "Failed to listen to port $port! ${e.runtimeType}",
        description: e.toString(),
      ),
    );
  }
}
