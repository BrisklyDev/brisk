import 'dart:io';

import 'package:brisk_download_engine/brisk_download_engine.dart';
import 'package:brisk_download_engine/src/download_engine/connection/http_download_connection.dart';
import 'package:brisk_download_engine/src/download_engine/engine/http_download_engine.dart';
import 'package:brisk_download_engine/src/download_engine/segment/download_segment_tree.dart';
import 'package:brisk_download_engine/src/download_engine/segment/segment.dart';
import 'package:brisk_download_engine/src/download_engine/segment/segment_status.dart';
import 'package:path/path.dart' as p;
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

    test('segment tree splits unfinished leaves after connection reuse', () {
      const fileSize = 130079008;
      final tree = DownloadSegmentTree.buildFromMissingBytes(
        fileSize,
        8,
        [Segment(0, fileSize - 1)],
      );
      tree.split();

      final completedLeft = tree.root.leftChild!;
      final activeRight = tree.root.rightChild!;
      completedLeft.segmentStatus = SegmentStatus.complete;
      activeRight.segmentStatus = SegmentStatus.inUse;
      activeRight.connectionNumber = 1;

      final reusedConnectionSplit = tree.splitSegmentNode(
        activeRight,
        setConnectionNumber: false,
      );
      expect(reusedConnectionSplit, isTrue);
      activeRight
        ..segmentStatus = SegmentStatus.outdated
        ..leftChild!.segmentStatus = SegmentStatus.complete
        ..rightChild!.segmentStatus = SegmentStatus.inUse;
      activeRight.rightChild!.connectionNumber = 0;

      expect(() => tree.split(), returnsNormally);

      expect(completedLeft.leftChild, isNull);
      expect(completedLeft.rightChild, isNull);
      expect(
        tree.lowestLevelNodes.map((node) => node.segment).toList(),
        [
          Segment(0, 65039503),
          Segment(65039504, 97559255),
          Segment(97559256, 113819131),
          Segment(113819132, 130079007),
        ],
      );
    });

    test('segment tree split respects maxSplits', () {
      const fileSize = 116045672;
      final tree = DownloadSegmentTree.buildFromMissingBytes(
        fileSize,
        8,
        [Segment(0, fileSize - 1)],
      );

      var splitNodes = tree.split(maxSplits: 1);
      expect(splitNodes.length, 1);
      expect(tree.lowestLevelNodes.length, 2);

      for (final node in tree.lowestLevelNodes) {
        node.segmentStatus = SegmentStatus.inUse;
      }
      splitNodes = tree.split(maxSplits: 2);
      expect(splitNodes.length, 2);
      expect(tree.lowestLevelNodes.length, 4);

      for (final node in tree.lowestLevelNodes) {
        node.segmentStatus = SegmentStatus.inUse;
      }
      splitNodes = tree.split(maxSplits: 1);
      expect(splitNodes.length, 1);
      expect(tree.lowestLevelNodes.length, 5);
      expect(tree.maxConnectionNumber, 4);
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

    test('connection clips overrun chunk and ignores later chunks', () async {
      final tempDir =
          Directory.systemTemp.createTempSync('brisk_chunk_boundary_test_');
      try {
        final connection = _connection(
          32,
          Segment(10, 19),
          tempDir: tempDir,
          uid: 'boundary-test',
        );
        final messages = <dynamic>[];
        connection.progressCallback = messages.add;
        connection.tempDirectory.createSync(recursive: true);

        await connection.doProcessChunk(List<int>.filled(15, 1));
        await connection.doProcessChunk(List<int>.filled(8, 2));

        final files =
            connection.tempDirectory.listSync().whereType<File>().toList();
        expect(files, hasLength(1));
        expect(p.basename(files.single.path), '0#10-19');
        expect(files.single.lengthSync(), 10);
        expect(connection.totalRequestReceivedBytes, 10);
        expect(connection.receivedBytesMatchEndByte, isTrue);
      } finally {
        tempDir.deleteSync(recursive: true);
      }
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

HttpDownloadConnection _connection(
  int fileSize,
  Segment segment, {
  Directory? tempDir,
  String uid = '',
}) {
  return HttpDownloadConnection(
    downloadItem: DownloadItemModel(
      uid: uid,
      fileName: 'file.bin',
      downloadUrl: 'https://example.com/file.bin',
      progress: 0,
      fileSize: fileSize,
    ),
    segment: segment,
    connectionNumber: 0,
    settings: ConnectionSettings(
      baseTempDir: tempDir ?? Directory.systemTemp,
      connectionRetryTimeoutMillis: 1000,
      maxConnectionRetryCount: 1,
      loggerEnabled: false,
    ),
  );
}
