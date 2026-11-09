/// A read-only snapshot of a single byte range of a download, as currently
/// allocated by the engine's segment tree.
///
/// This is used purely for visualization. It mirrors the lowest level nodes
/// of the segment tree and the progress of the connection assigned to each.
class SegmentProgress {
  final int startByte;

  /// Inclusive end byte
  final int endByte;

  /// The connection assigned to this segment.
  final int connectionNumber;

  /// Number of bytes received for this segment, counted from [startByte].
  final int receivedBytes;

  /// Whether this segment has been fully downloaded.
  final bool complete;

  /// Whether a connection is currently downloading this segment.
  final bool active;

  const SegmentProgress({
    required this.startByte,
    required this.endByte,
    required this.connectionNumber,
    required this.receivedBytes,
    required this.complete,
    required this.active,
  });

  int get length => endByte - startByte + 1;

  @override
  String toString() =>
      "SegmentProgress($startByte-$endByte conn: $connectionNumber "
      "received: $receivedBytes complete: $complete active: $active)";
}
