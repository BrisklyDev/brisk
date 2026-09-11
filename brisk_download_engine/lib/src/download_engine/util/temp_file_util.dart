import 'dart:io';
import 'package:brisk_download_engine/src/download_engine/segment/segment.dart';
import 'package:dartx/dartx.dart';
import 'package:path/path.dart';

/// [first] : either the first file name or the sum of the previous reduce operation
int addTempFilesLengthReduce(String first, String secondFileName) {
  if (first.isInt) {
    return first.toInt() + getTempFileLength(secondFileName);
  }
  return getTempFileLength(first) + getTempFileLength(secondFileName);
}

Segment fileNameToSegment(String fileName) {
  final startByte = getStartByteFromTempFileName(fileName);
  final endByte = getEndByteFromTempFileName(fileName);
  return Segment(startByte, endByte);
}

int getTempFileLength(String tempFileName) {
  if (tempFileName.isEmpty) {
    return 0;
  }
  return getEndByteFromTempFileName(tempFileName) -
      getStartByteFromTempFileName(tempFileName) +
      1;
}

bool tempFileBelongsToConnection(File file, int connectionNumber) {
  return getConnectionNumberFromTempFileName(
        basename(file.path),
      ) ==
      connectionNumber;
}

int sortByByteRanges(FileSystemEntity a, FileSystemEntity b) {
  final aName = basename(a.path);
  final bName = basename(b.path);
  final aStartByte = getStartByteFromTempFileName(aName);
  final bStartByte = getStartByteFromTempFileName(bName);
  return aStartByte.compareTo(bStartByte);
}

int getStartByteFromTempFileName(String tempFileName) {
  return int.parse(
    tempFileName.substring(
      tempFileName.indexOf("#") + 1,
      tempFileName.indexOf("-"),
    ),
  );
}

List<File> getTempFilesSorted(
  Directory tempDirectory, {
  int? connectionNumber,
  Segment? inByteRange,
}) {
  if (!tempDirectory.existsSync()) {
    return [];
  }
  return tempDirectory
      .listSync()
      .map((e) => e as File)
      .where(
        (file) => connectionNumber != null
            ? tempFileBelongsToConnection(file, connectionNumber)
            : true,
      )
      .toList()
      .where(
        (file) => inByteRange != null
            ? isTempFileInByteRange(
                file,
                inByteRange.startByte,
                inByteRange.endByte,
              )
            : true,
      )
      .toList()
    ..sort(sortByByteRanges);
}

bool isTempFileInByteRange(File file, int startByte, int endByte) {
  final tempStartByte = getStartByteFromTempFile(file);
  final tempEndByte = getEndByteFromTempFile(file);
  return tempStartByte <= endByte && tempEndByte >= startByte;
}

int getStartByteFromTempFile(File tempFile) {
  return getStartByteFromTempFileName(basename(tempFile.path));
}

int getEndByteFromTempFile(File tempFile) {
  return getEndByteFromTempFileName(basename(tempFile.path));
}

int getEndByteFromTempFileName(String fileName) {
  return int.parse(fileName.substring(fileName.indexOf("-") + 1));
}

int getConnectionNumberFromTempFileName(String fileName) {
  return int.parse(fileName.substring(0, fileName.indexOf("#")));
}
