import 'dart:async';
import 'dart:convert';

import 'package:brisk/constants/setting_options.dart';
import 'package:brisk/model/download_item.dart';
import 'package:brisk/util/lang_utils.dart';
import 'package:brisk_download_engine/brisk_download_engine.dart';
import 'package:dartx/dartx.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

import '../constants/setting_type.dart';
import '../db/hive_util.dart';
import '../model/file_metadata.dart';
import '../model/setting.dart';

// Removed usage because of status 400 in google drive. also it doesn't seem necessary anyway
const Map<String, String> contentType_MultiPartByteRanges = {
  'content-type': 'multipart/byteranges;'
};

const Map<String, String> userAgentHeader = {
  "User-Agent":
      "Mozilla/5.0 (Windows NT 6.1; Trident/7.0; rv:11.0) like Gecko;",
};

bool checkDownloadPauseSupport(Map<String, String> headers) {
  final acceptsRanges = headers['Accept-Ranges'] ?? headers['accept-ranges'];
  final contentRange = headers['content-range'] ?? headers['Content-Range'];
  return (acceptsRanges != null && acceptsRanges == 'bytes') ||
      contentRange.isNotNullOrBlank;
}

String? extractFilenameFromHeaders(Map<String, String> headers) {
  final contentDisposition = headers['content-disposition'];
  if (contentDisposition == null) return null;
  List<String> tokens = contentDisposition.split(";");
  String? filename;
  for (var i = 0; i < tokens.length; i++) {
    if (tokens[i].contains('filename')) {
      filename = !tokens[i].contains('"')
          ? tokens[i].substring(tokens[i].indexOf("=") + 1, tokens[i].length)
          : tokens[i]
              .substring(tokens[i].indexOf("=") + 2, tokens[i].length - 1);
    }
  }
  if (filename != null && filename.startsWith("UTF-8''")) {
    filename = filename.replaceAll("UTF-8''", "");
  }
  return filename;
}

String extractFileNameFromUrl(String url) {
  final slashIndex = url.lastIndexOf('/');
  final dotIndex = url.lastIndexOf('.');
  final tailingStr = url.substring(slashIndex + 1);
  if (tailingStr.contains("?")) {
    return tailingStr.substring(0, tailingStr.indexOf("?"));
  }
  return (url.substring(dotIndex).contains('?'))
      ? url.substring(slashIndex + 1, url.lastIndexOf('?'))
      : url.substring(slashIndex + 1);
}

bool isUrlValid(String url) {
  final regex = RegExp(r'html#\{.*?\}');
  return (Uri.tryParse(url)?.hasAbsolutePath ?? false) || !regex.hasMatch(url);
}

List<int> calculateByteStartAndByteEnd(
    int totalSegments, int segmentNumber, contentLength) {
  final isLastSegment = totalSegments == segmentNumber;
  final segmentLength = (contentLength / totalSegments).floor();
  final byteStart = ((segmentNumber - 1) * segmentLength).toInt();
  final byteEnd = isLastSegment ? contentLength : byteStart + segmentLength - 1;
  return [byteStart, byteEnd];
}

Future<List<FileInfo>?> requestFileInfoBatch(
  List<DownloadItem> downloadItems,
  HttpClientSettings? clientSettings,
) async {
  List<FileInfo> fileInfos = [];
  for (final item in downloadItems) {
    final fileInfo = await requestFileInfo(
      item,
      clientSettings,
      ignoreException: true,
    ).onError((error, stackTrace) => null);
    if (fileInfo == null) continue;
    fileInfo.url = item.downloadUrl;
    fileInfos.add(fileInfo);
  }
  return fileInfos;
}

Future<FileInfo?> requestFileInfo(
  DownloadItem downloadItem,
  HttpClientSettings? clientSettings, {
  ignoreException = false,
}) async {
  return await sendFileInfoRequest(
    downloadItem,
    clientSettings: clientSettings,
    ignoreException: ignoreException,
    headers: downloadItem.requestHeaders,
  ).catchError((e) async {
    final fileInfo = await sendFileInfoRequest(
      downloadItem,
      ignoreException: ignoreException,
      clientSettings: clientSettings,
      headers: downloadItem.requestHeaders,
      useGet: true,
    );
    return fileInfo;
  });
}

Future<String> fetchStringContent(
  String url, {
  HttpClientSettings? clientSettings,
  Map<String, String>? headers,
}) async {
  final client = await HttpClientBuilder.buildClient(clientSettings);
  final request = http.Request('GET', Uri.parse(url));
  request.headers.addAll(userAgentHeader);
  request.headers.addAll(headers ?? {});
  final response = await client.get(Uri.parse(url), headers: headers);
  if (response.statusCode == 200) {
    return response.body;
  } else {
    throw Exception('Failed to fetch m3u8!');
  }
}

/// Sends a HEAD request to the url given in the [downloadItem] object.
/// Determines pause/resume functionality support by the server,
/// total file size and the content-type of the request.
/// TODO handle status codes other than 200
Future<FileInfo?> sendFileInfoRequest(
  DownloadItem downloadItem, {
  HttpClientSettings? clientSettings = null,
  bool ignoreException = false,
  bool useGet = false,
  Map<String, String> headers = const {},
}) async {
  Completer<FileInfo?> completer = Completer();
  final request = http.Request(
    useGet ? "GET" : "HEAD",
    Uri.parse(downloadItem.downloadUrl),
  );
  if (!headers.containsKeyIgnoreCase("User-Agent")) {
    request.headers.addAll(userAgentHeader);
  }
  if (headers.isNotEmpty) {
    request.headers.addAll(headers);
  }
  final client = await HttpClientBuilder.buildClient(clientSettings);
  try {
    client
        .send(request)
        .asStream()
        .timeout(Duration(seconds: 10))
        .listen((streamedResponse) {
      try {
        final headers = streamedResponse.headers;
        var filename = extractFilenameFromHeaders(headers);
        if (filename != null) {
          downloadItem.fileName = filename;
        }
        if (headers["content-length"] == null ||
            !streamedResponse.statusCode.toString().startsWith("2")) {
          if (ignoreException) {
            completer.complete(null);
            return;
          }
          completer.completeError(
              Exception("Failed to retrieve result from the given URL"));
          return;
        }
        downloadItem.contentLength = int.parse(headers["content-length"]!);
        downloadItem.fileName = Uri.decodeComponent(downloadItem.fileName);
        final supportsPause = checkDownloadPauseSupport(headers);
        final data = FileInfo(
          supportsPause,
          downloadItem.fileName,
          downloadItem.contentLength,
        );
        completer.complete(data);
      } finally {
        if (useGet) {
          client.close();
        }
      }
    }).onError((e) {
      completer.completeError(
        Exception("Could not retrieve result from the given URL"),
      );
    });
  } catch (e) {
    completer.completeError(e);
  }
  return completer.future;
}

Future<dynamic> getJson(String url) async {
  Completer<dynamic> completer = Completer();
  final response = http.Client().get(Uri.parse(url));
  response.asStream().listen((event) {
    final json = jsonDecode(String.fromCharCodes(event.bodyBytes));
    completer.complete(json);
    return;
  });
  return completer.future;
}

Future<String?> getBrowserExtensionDownloadLink(String browser) async {
  final json = await getJson(
    "https://api.github.com/repos/BrisklyDev/brisk-browser-extension/releases/latest",
  );
  if (json['message'].toString().contains("rate limit")) {
    return null;
  }
  final assets = json['assets'] as List<dynamic>;
  for (final asset in assets) {
    final name = asset['name'] as String;
    final url = asset['browser_download_url'] as String;
    if (name.contains(browser.toLowerCase())) {
      return url;
    }
  }
  return null;
}

Future<Pair<bool, String>> isNewBriskVersionAvailable({
  bool ignoreLastUpdateCheck = false,
}) async {
  var lastUpdateCheck = HiveUtil.getSetting(SettingOptions.lastUpdateCheck);
  if (lastUpdateCheck == null) {
    lastUpdateCheck = Setting(
      name: "lastUpdateCheck",
      value: "0",
      settingType: SettingType.system.name,
    );
    await HiveUtil.instance.settingBox.add(lastUpdateCheck);
  }
  if (!ignoreLastUpdateCheck &&
      int.parse(lastUpdateCheck.value) + 86400000 >
          DateTime.now().millisecondsSinceEpoch) return Pair(false, "");

  lastUpdateCheck = HiveUtil.getSetting(SettingOptions.lastUpdateCheck)!;
  lastUpdateCheck.value = DateTime.now().millisecondsSinceEpoch.toString();
  await lastUpdateCheck.save();

  final json = await getJson(
    "https://api.github.com/repos/AminBhst/brisk/releases/latest",
  );
  if (json["message"].toString().contains("rate limit")) {
    throw Exception("GitHub API rate limit exceeded. Please try again later.");
  }
  if (json == null || json['tag_name'] == null) return Pair(false, "");

  String tagName = json['tag_name'];
  tagName = tagName.replaceAll(".", "").replaceAll("v", "");
  String latestVersion = (json['tag_name'] as String).replaceAll("v", "");
  final packageInfo = await PackageInfo.fromPlatform();
  return Pair(
    isNewVersionAvailable(latestVersion, packageInfo.version),
    latestVersion,
  );
}

bool isNewVersionAvailable(String latestVersion, String targetVersion) {
  final latestSplit = latestVersion.split(".");
  final currentSplit = targetVersion.split(".");
  for (int i = 0; i < latestSplit.length; i++) {
    final splitVersion = int.parse(latestSplit[i]);
    final splitCurrent = int.parse(currentSplit[i]);
    if (splitVersion > splitCurrent) {
      return true;
    }
    if (i == latestSplit.length - 1) {
      return false;
    }
  }
  return false;
}
