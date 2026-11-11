import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:brisk_download_engine/brisk_download_engine.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// Integration test of the kasma engine through [DownloadEngine].
///
/// Requires the native library. Build it with
/// `cargo build --release --manifest-path kasma_engine/rust/Cargo.toml`
/// and point `KASMA_LIBRARY_PATH` to `kasma_engine/rust/target/release/libkasma.so`
/// (or kasma.dll / libkasma.dylib). The test is skipped if the library can't be loaded.
void main() {
  late HttpServer server;
  late Uint8List data;
  late Directory tempRoot;
  const fileSize = 24 * 1000 * 1000;

  setUpAll(() async {
    final random = Random(42);
    data = Uint8List.fromList(List.generate(fileSize, (_) => random.nextInt(256)));
    tempRoot = await Directory.systemTemp.createTemp('kasma_test_');
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      final response = request.response;
      var start = 0;
      var end = fileSize - 1;
      final range = request.headers.value(HttpHeaders.rangeHeader);
      response.headers.set(HttpHeaders.acceptRangesHeader, 'bytes');
      if (range != null) {
        final match = RegExp(r'bytes=(\d+)-(\d*)').firstMatch(range)!;
        start = int.parse(match.group(1)!);
        if (match.group(2)!.isNotEmpty) end = min(int.parse(match.group(2)!), end);
        response.statusCode = HttpStatus.partialContent;
        response.headers.set(
          HttpHeaders.contentRangeHeader,
          'bytes $start-$end/$fileSize',
        );
      }
      response.contentLength = end - start + 1;
      if (request.method == 'HEAD') {
        await response.close();
        return;
      }
      // ~4 MB/s per connection so that the download takes a few seconds
      const chunk = 64 * 1024;
      try {
        for (var i = start; i <= end; i += chunk) {
          response.add(data.sublist(i, min(i + chunk, end + 1)));
          await response.flush();
          await Future.delayed(const Duration(milliseconds: 16));
        }
        await response.close();
      } catch (_) {}
    });
  });

  tearDownAll(() async {
    await server.close(force: true);
    await tempRoot.delete(recursive: true);
  });

  final skip = KasmaDownloadEngine.isAvailable
      ? false
      : 'kasma library not available: ${KasmaDownloadEngine.unavailableReason}';

  test('downloads, pauses and resumes through DownloadEngine', () async {
    final saveDir = Directory(p.join(tempRoot.path, 'save'))..createSync();
    final item = DownloadItemModel(
      id: 1,
      uid: 'kasma-test-1',
      fileName: 'test.bin',
      filePath: p.join(saveDir.path, 'test.bin'),
      downloadUrl: 'http://127.0.0.1:${server.port}/test.bin',
      progress: 0,
      fileSize: fileSize,
      supportsPause: true,
    );
    final settings = DownloadSettings(
      baseSaveDir: saveDir,
      baseTempDir: Directory(p.join(tempRoot.path, 'temp')),
      totalConnections: 8,
      totalM3u8Connections: 1,
      connectionRetryTimeoutMillis: 5000,
      maxConnectionRetryCount: -1,
      loggerEnabled: false,
      engineType: EngineType.kasma,
    );
    final statuses = <String>[];
    final buttons = <ButtonAvailabilityMessage>[];
    final completed = Completer<DownloadProgressMessage>();
    var paused = false;
    var resumed = false;

    DownloadEngine.start(
      item,
      settings,
      item.downloadType,
      onButtonAvailability: buttons.add,
      onDownloadProgress: (progress) {
        if (statuses.isEmpty || statuses.last != progress.status) {
          statuses.add(progress.status);
        }
        if (!paused &&
            progress.downloadProgress > 0.2 &&
            progress.buttonAvailability.pauseButtonEnabled) {
          paused = true;
          DownloadEngine.pause(item.uid);
        }
        if (paused &&
            !resumed &&
            progress.status == DownloadStatus.paused &&
            progress.buttonAvailability.startButtonEnabled) {
          resumed = true;
          Future.delayed(const Duration(seconds: 1), () {
            DownloadEngine.start(
              item,
              settings,
              item.downloadType,
              onButtonAvailability: buttons.add,
              onDownloadProgress: (_) {},
            );
          });
        }
        if (progress.status == DownloadStatus.assembleComplete ||
            progress.status == DownloadStatus.failed ||
            progress.status == DownloadStatus.networkError) {
          if (!completed.isCompleted) completed.complete(progress);
        }
      },
    );

    final result = await completed.future.timeout(const Duration(seconds: 90));
    expect(result.status, DownloadStatus.assembleComplete, reason: result.message);
    expect(result.assembleProgress, 1);
    expect(result.assembledFileSize, fileSize);
    expect(statuses, contains(DownloadStatus.paused));
    expect(statuses, contains(DownloadStatus.downloading));
    final downloaded = File(result.downloadItem.filePath);
    expect(md5.convert(downloaded.readAsBytesSync()), md5.convert(data));
    expect(buttons.any((b) => b.startButtonEnabled), isTrue);
    expect(
      Directory(p.join(settings.baseTempDir.path, item.uid)).existsSync(),
      isFalse,
    );
  }, skip: skip, timeout: const Timeout(Duration(minutes: 2)));

  test('terminate keeps progress and a new start resumes', () async {
    final saveDir = Directory(p.join(tempRoot.path, 'save2'))..createSync();
    final item = DownloadItemModel(
      id: 2,
      uid: 'kasma-test-2',
      fileName: 'test2.bin',
      filePath: p.join(saveDir.path, 'test2.bin'),
      downloadUrl: 'http://127.0.0.1:${server.port}/test2.bin',
      progress: 0,
      fileSize: fileSize,
      supportsPause: true,
    );
    final settings = DownloadSettings(
      baseSaveDir: saveDir,
      baseTempDir: Directory(p.join(tempRoot.path, 'temp')),
      totalConnections: 4,
      totalM3u8Connections: 1,
      connectionRetryTimeoutMillis: 5000,
      maxConnectionRetryCount: -1,
      loggerEnabled: false,
      engineType: EngineType.kasma,
    );
    final halfway = Completer<void>();
    DownloadEngine.start(
      item,
      settings,
      item.downloadType,
      onButtonAvailability: (_) {},
      onDownloadProgress: (progress) {
        if (progress.downloadProgress > 0.3 && !halfway.isCompleted) {
          halfway.complete();
        }
      },
    );
    await halfway.future.timeout(const Duration(seconds: 60));
    await DownloadEngine.terminate(item.uid).timeout(const Duration(seconds: 20));
    expect(KasmaDownloadEngine.isRunning(item.uid), isFalse);
    final tempDir = Directory(p.join(settings.baseTempDir.path, item.uid));
    expect(tempDir.listSync(), isNotEmpty);

    final completed = Completer<DownloadProgressMessage>();
    double? firstProgress;
    DownloadEngine.start(
      item,
      settings,
      item.downloadType,
      onButtonAvailability: (_) {},
      onDownloadProgress: (progress) {
        if (progress.status == DownloadStatus.downloading) {
          firstProgress ??= progress.downloadProgress;
        }
        if (progress.status == DownloadStatus.assembleComplete ||
            progress.status == DownloadStatus.failed) {
          if (!completed.isCompleted) completed.complete(progress);
        }
      },
    );
    final result = await completed.future.timeout(const Duration(seconds: 90));
    expect(result.status, DownloadStatus.assembleComplete, reason: result.message);
    expect(firstProgress, greaterThan(0.25), reason: 'resume should keep progress');
    final downloaded = File(result.downloadItem.filePath);
    expect(md5.convert(downloaded.readAsBytesSync()), md5.convert(data));
  }, skip: skip, timeout: const Timeout(Duration(minutes: 3)));
}
