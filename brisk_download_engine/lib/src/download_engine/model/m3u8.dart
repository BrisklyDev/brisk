import 'dart:typed_data';

import 'package:brisk_download_engine/brisk_download_engine.dart';
import 'package:brisk_download_engine/src/download_engine/client/http_client_builder.dart';
import 'package:brisk_download_engine/src/download_engine/segment/segment_status.dart';
import 'package:brisk_download_engine/src/download_engine/setting/proxy_setting.dart';
import 'package:brisk_download_engine/src/download_engine/util/file_util.dart';
import 'package:brisk_download_engine/src/download_engine/util/m3u8_util.dart';
import 'package:rhttp/rhttp.dart';

class M3U8 {
  final String url;
  final List<StreamInf> streamInfos;
  final List<M3U8Segment> segments;
  final int mediaSequence;
  final M3U8EncryptionDetails encryptionDetails;
  final int totalDuration;
  String stringContent;
  String? refererHeader;
  String fileName;

  M3U8({
    required this.url,
    required this.segments,
    required this.mediaSequence,
    required this.encryptionDetails,
    required this.streamInfos,
    required this.totalDuration,
    required this.stringContent,
    required this.fileName,
    this.refererHeader,
  });

  bool get isMasterPlaylist => segments.isEmpty && streamInfos.isNotEmpty;

  void setStreamInfsResolutionFileName() {
    for (final streamInf in streamInfos) {
      if (streamInf.m3u8 != null && streamInf.m3u8!.fileName.contains(".ts")) {
        final rawName = streamInf.m3u8?.fileName.substring(
          0,
          streamInf.m3u8?.fileName.lastIndexOf(".ts"),
        );
        if (streamInf.resolution == '1920x1080') {
          streamInf.m3u8?.fileName = '$rawName.1080p.ts';
        } else if (streamInf.resolution == '1280x720') {
          streamInf.m3u8?.fileName = '$rawName.720p.ts';
        } else {
          streamInf.m3u8?.fileName = '$rawName.${streamInf.resolution}.ts';
        }
      }
    }
  }

  static Future<M3U8?> fromUrl(
    String url, {
    HttpClientSettings? clientSettings,
    bool isSubPlaylist = false,
    String? refererHeader,
    String? suggestedFileName,
  }) async {
    final client = await HttpClientBuilder.buildClient();
    try {
      final headers = {
        "User-Agent":
            "Mozilla/5.0 (Windows NT 6.1; Trident/7.0; rv:11.0) like Gecko;",
      };
      if (refererHeader != null) {
        headers.addAll({"referer": refererHeader});
      }
      final response = await client.get(Uri.parse(url), headers: headers);
      if (response.statusCode == 200) {
        final body = response.body;
        return await M3U8.fromString(
          body,
          url,
          isSubPlaylist: isSubPlaylist,
          suggestedFileName: suggestedFileName,
        )
          ?..refererHeader = refererHeader;
      } else {
        print("Failed to fetch m3u8... status code ${response.statusCode}");
        throw Exception('Failed to fetch m3u8!');
      }
    } catch (e) {
      print(e);
      rethrow;
    }
  }

  static Future<M3U8?> fromString(
    String content,
    String url, {
    HttpClientSettings? clientSettings,
    bool fetchKeys = true,
    bool isSubPlaylist = false,
    String? refererHeader,
    String? suggestedFileName,
  }) async {
    final lines = content.split("\n");
    StringBuffer modifierStringContent = StringBuffer("");
    int mediaSequence = 0;
    M3U8EncryptionDetails encryptionDetails = M3U8EncryptionDetails();
    bool reachedSegments = false;
    int currSegmentNum = -1;
    int currStreamInfNum = -1;
    Map<int, M3U8Segment> segments = {};
    Map<int, StreamInf> streamInfos = {};
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (line.startsWith("#EXT-X-STREAM-INF:")) {
        modifierStringContent.writeln(line);
        currStreamInfNum++;
        final urlLine = lines[i + 1];
        streamInfos[currStreamInfNum] = (streamInfos[currStreamInfNum] ??
            StreamInf())
          ..url = urlLine.trim();
        final resolutionPattern = RegExp(r'RESOLUTION=(\d+x\d+)');
        final matchRes = resolutionPattern.firstMatch(line);
        if (matchRes != null) {
          final resolution = matchRes.group(1);
          streamInfos[currStreamInfNum] = (streamInfos[currStreamInfNum] ??
              StreamInf())
            ..resolution = resolution;
        }
        final frameRatePattern = RegExp(r'FRAME-RATE=([\d.]+)');
        final matchFrameRate = frameRatePattern.firstMatch(line);
        if (matchFrameRate != null) {
          final frameRate = matchFrameRate.group(1);
          streamInfos[currStreamInfNum] = (streamInfos[currStreamInfNum] ??
              StreamInf())
            ..frameRate = frameRate;
        }
      } else if (line.startsWith("#EXT-X-MEDIA-SEQUENCE:")) {
        modifierStringContent.writeln(line);
        mediaSequence = int.tryParse(line.substring(22)) ?? 0;
      } else if (line.startsWith("#EXT-X-KEY")) {
        modifierStringContent.writeln(line);
        final attrs = parseAttributes(line);
        final currEncryptionDetails = M3U8EncryptionDetails(
          encryptionKeyUrl: attrs["URI"],
          encryptionMethod: M3U8EncryptionMethodParser.fromString(
            attrs["METHOD"]!,
          ),
          iv: attrs["IV"],
        );
        if (reachedSegments) {
          segments[currSegmentNum] = (segments[currSegmentNum] ?? M3U8Segment())
            ..encryptionDetails = currEncryptionDetails;
        } else {
          encryptionDetails = currEncryptionDetails;
        }
      } else if (line.startsWith("#EXTINF:")) {
        modifierStringContent.writeln(line);
        currSegmentNum++;
        final extInfValue = line.substring(8, line.length - 2);
        reachedSegments = true;
        segments[currSegmentNum] = (segments[currSegmentNum] ?? M3U8Segment())
          ..extInf = extInfValue
          ..sequenceNumber = currSegmentNum;
      } else if (line.startsWith("http")) {
        modifierStringContent.writeln(line);
        segments[currSegmentNum] = (segments[currSegmentNum] ?? M3U8Segment())
          ..url = line;
      } else if (!line.startsWith("http") &&
          (isSubPlaylist || line.endsWith(".ts")) &&
          FileUtil.isFileName(line)) {
        final completeUrl =
            "${url.substring(0, url.lastIndexOf("/"))}/${line.trim()}";
        segments[currSegmentNum] = (segments[currSegmentNum] ?? M3U8Segment())
          ..url = completeUrl;
        modifierStringContent.writeln(completeUrl);
      }
    }
    final totalDuration = segments.isEmpty
        ? 0
        : segments.values
            .map((m) => double.tryParse(m.extInf) ?? 0)
            .reduce((sum, duration) => sum + duration)
            .toInt();
    final m3u8 = M3U8(
      segments: segments.values.toList(),
      mediaSequence: mediaSequence,
      encryptionDetails: encryptionDetails,
      streamInfos: streamInfos.values.toList(),
      totalDuration: totalDuration,
      stringContent: content,
      url: url,
      fileName: suggestedFileName ??
          (url.contains('/') ? url.substring(url.lastIndexOf('/') + 1) : url),
    );
    if (m3u8.isMasterPlaylist) {
      for (var streamInf in m3u8.streamInfos) {
        var streamUrl = streamInf.url;
        if (streamUrl == null) continue;
        if (!streamUrl.contains("http")) {
          streamUrl = "${url.substring(0, url.lastIndexOf("/"))}/$streamUrl";
          streamInf.m3u8 = await M3U8.fromUrl(streamUrl,
              isSubPlaylist: true,
              clientSettings: clientSettings,
              refererHeader: refererHeader,
              suggestedFileName: suggestedFileName);
        }
      }
    }
    m3u8.refererHeader = refererHeader;
    if (!fetchKeys) {
      return m3u8;
    }
    if (m3u8.encryptionDetails.encryptionMethod ==
        M3U8EncryptionMethod.aes128) {
      m3u8.encryptionDetails.keyBytes = await fetchDecryptionKey(
        m3u8.encryptionDetails.encryptionKeyUrl!,
        clientSettings: clientSettings,
      );
    }
    for (var segment in m3u8.segments) {
      if (segment.encryptionDetails == null ||
          segment.encryptionDetails!.encryptionKeyUrl == null ||
          segment.encryptionDetails!.encryptionKeyUrl!.isEmpty) {
        continue;
      }
      segment.encryptionDetails!.keyBytes = await fetchDecryptionKey(
        segment.encryptionDetails!.encryptionKeyUrl!,
        clientSettings: clientSettings,
      );
    }

    if (modifierStringContent.isNotEmpty) {
      m3u8.stringContent = modifierStringContent.toString();
    }
    return m3u8;
  }

  static Map<String, String> parseAttributes(String attributesLine) {
    final attributes = <String, String>{};
    final regex = RegExp(r'(\w+)="([^"]+)"|(\w+)=([^,]+)');
    for (final match in regex.allMatches(attributesLine)) {
      if (match.group(1) != null && match.group(2) != null) {
        attributes[match.group(1)!] = match.group(2)!;
      } else if (match.group(3) != null && match.group(4) != null) {
        attributes[match.group(3)!] = match.group(4)!;
      }
    }
    return attributes;
  }
}

class StreamInf {
  String? resolution;
  String? frameRate;
  String? url;
  M3U8? m3u8;

  String get fileName {
    if (url == null) return "";
    if (url!.contains("/")) {
      return url!.substring(url!.lastIndexOf('/') + 1);
    }
    return url!;
  }

  StreamInf({this.resolution, this.frameRate, this.url, this.m3u8});
}

class M3U8Segment {
  String url;
  int sequenceNumber;
  String extInf;
  int? connectionNumber;
  SegmentStatus segmentStatus = SegmentStatus.initial;

  /// Encryption details for m3u8 files with key rotation
  M3U8EncryptionDetails? encryptionDetails;

  M3U8EncryptionMethod get encryptionMethod => encryptionDetails != null
      ? encryptionDetails!.encryptionMethod
      : M3U8EncryptionMethod.none;

  M3U8Segment({
    this.url = "",
    this.sequenceNumber = 0,
    this.extInf = "",
    this.encryptionDetails,
    this.segmentStatus = SegmentStatus.initial,
  });

  @override
  String toString() {
    return "Sequence Number $sequenceNumber Url: $url";
  }

  @override
  bool operator ==(Object other) {
    return other is M3U8Segment &&
        other.sequenceNumber == sequenceNumber &&
        other.url == url;
  }
}

enum M3U8EncryptionMethod { none, aes128, sampleAes }

extension M3U8EncryptionMethodParser on M3U8EncryptionMethod {
  static M3U8EncryptionMethod fromString(String str) {
    if (str == "AES-128") {
      return M3U8EncryptionMethod.aes128;
    } else if (str == "SAMPLE-AES") {
      return M3U8EncryptionMethod.sampleAes;
    } else {
      return M3U8EncryptionMethod.none;
    }
  }
}

class M3U8EncryptionDetails {
  final M3U8EncryptionMethod encryptionMethod;
  final String? encryptionKeyUrl;
  final String? iv;
  Uint8List? keyBytes;

  M3U8EncryptionDetails({
    this.encryptionMethod = M3U8EncryptionMethod.none,
    this.encryptionKeyUrl,
    this.iv,
    this.keyBytes,
  });
}
