import 'dart:io';

import 'package:brisk_download_engine/brisk_download_engine.dart';
import 'package:brisk_download_engine/src/download_engine/connection/http_download_connection.dart';
import 'package:brisk_download_engine/src/download_engine/engine/http_download_engine.dart';
import 'package:brisk_download_engine/src/download_engine/segment/download_segment_tree.dart';
import 'package:brisk_download_engine/src/download_engine/segment/segment.dart';
import 'package:test/test.dart';

void main() {
  group('HTTP byte ranges', () {
    test('segment tree treats content length as a byte count', () {
      const fileSize = 130079008;
      final tree = DownloadSegmentTree.buildFromMissingBytes(
        fileSize,
        8,
        [Segment(0, fileSize - 1)],
      );

      expect(tree.root.segment.startByte, 0);
      expect(tree.root.segment.endByte, fileSize - 1);

      for (var i = 0; i < 4; i++) {
        tree.split();
      }

      final modeledBytes = tree.lowestLevelNodes
          .map((node) => node.segment.length)
          .reduce((first, second) => first + second);
      expect(modeledBytes, fileSize);
      expect(
        tree.lowestLevelNodes.every(
          (node) => node.segment.endByte <= fileSize - 1,
        ),
        isTrue,
      );
    });

    test('segment tree clamps legacy endByte equal to content length', () {
      const fileSize = 130079008;
      final tree = DownloadSegmentTree.buildFromMissingBytes(
        fileSize,
        8,
        [Segment(0, fileSize)],
      );

      expect(tree.root.segment.startByte, 0);
      expect(tree.root.segment.endByte, fileSize - 1);
      expect(tree.root.segment.length, fileSize);
    });

    test('connection completion predicates use inclusive segment length', () {
      const fileSize = 130079008;
      final segment = Segment(129706678, fileSize - 1);
      final connection = _connection(fileSize, segment);

      connection.totalRequestReceivedBytes = segment.length - 1;
      expect(connection.receivedBytesMatchEndByte, isFalse);
      expect(connection.receivedBytesExceededEndByte, isFalse);

      connection.totalRequestReceivedBytes = segment.length;
      expect(connection.receivedBytesMatchEndByte, isTrue);
      expect(connection.receivedBytesExceededEndByte, isFalse);

      connection.totalRequestReceivedBytes = segment.length + 1;
      expect(connection.receivedBytesMatchEndByte, isFalse);
      expect(connection.receivedBytesExceededEndByte, isTrue);
    });

    test('connection rejects an inclusive endByte equal to fileSize', () {
      const fileSize = 130079008;
      final valid = _connection(fileSize, Segment(fileSize - 10, fileSize - 1));
      final invalid = _connection(fileSize, Segment(fileSize - 10, fileSize));

      expect(valid.isStartNotAllowed(false, false), isFalse);
      expect(invalid.isStartNotAllowed(false, false), isTrue);
    });

    test('total progress uses byte counts instead of summed fractions', () {
      const fileSize = 28;
      final item = DownloadItemModel(
        fileName: 'file.bin',
        downloadUrl: 'https://example.com/file.bin',
        progress: 0,
        fileSize: fileSize,
      );
      final completedConnectionBytes = [9, 18, 1];
      final completedProgresses = completedConnectionBytes
          .map(
            (bytes) => DownloadProgressMessage(
              downloadItem: item,
              totalReceivedBytes: bytes,
              totalDownloadProgress: bytes / fileSize,
            ),
          )
          .toList();

      final summedConnectionFractions = completedProgresses
          .map((progress) => progress.totalDownloadProgress)
          .reduce((first, second) => first + second);

      expect(summedConnectionFractions, greaterThan(1));
      expect(
        HttpDownloadEngine.calculateTotalProgressFromConnectionProgresses(
          completedProgresses,
        ),
        1,
      );

      final overrunProgresses = [9, 18, 2]
          .map(
            (bytes) => DownloadProgressMessage(
              downloadItem: item,
              totalReceivedBytes: bytes,
              totalDownloadProgress: bytes / fileSize,
            ),
          )
          .toList();
      expect(
        HttpDownloadEngine.calculateTotalProgressFromConnectionProgresses(
          overrunProgresses,
        ),
        greaterThan(1),
      );
    });
  });
}

HttpDownloadConnection _connection(int fileSize, Segment segment) {
  return HttpDownloadConnection(
    downloadItem: DownloadItemModel(
      fileName: 'file.bin',
      downloadUrl: 'https://example.com/file.bin',
      progress: 0,
      fileSize: fileSize,
    ),
    segment: segment,
    connectionNumber: 0,
    settings: ConnectionSettings(
      baseTempDir: Directory.systemTemp,
      connectionRetryTimeoutMillis: 1000,
      maxConnectionRetryCount: 1,
      loggerEnabled: false,
    ),
  );
}
