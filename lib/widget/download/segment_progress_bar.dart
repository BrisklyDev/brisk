import 'package:brisk_download_engine/brisk_download_engine.dart';
import 'package:flutter/material.dart';

/// A thin progress bar that visualizes how the file's byte range is split
/// between connections, similar to IDM's segment view.
///
/// The bar spans the whole file. Each segment is drawn at its byte position
/// and fills from its start byte as its connection receives data. Split
/// points between segments are drawn as gaps, so new connections show up
/// as a new progress starting in the middle of an existing segment.
class SegmentProgressBar extends StatelessWidget {
  final List<SegmentProgress> segments;
  final int fileSize;
  final Color fillColor;
  final Color backgroundColor;

  /// Color of the gaps that mark split points. Should match the surface the
  /// bar sits on.
  final Color dividerColor;

  /// When true, the whole bar is drawn as a single solid [completeColor]
  /// without split points.
  final bool completed;
  final Color completeColor;
  final double height;

  const SegmentProgressBar({
    super.key,
    required this.segments,
    required this.fileSize,
    required this.fillColor,
    required this.backgroundColor,
    required this.dividerColor,
    required this.completeColor,
    this.completed = false,
    this.height = 6,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SizedBox(
        height: height,
        width: constraints.hasBoundedWidth ? constraints.maxWidth : 0,
        child: CustomPaint(
          painter: _SegmentProgressPainter(
            segments: segments,
            fileSize: fileSize,
            fillColor: fillColor,
            backgroundColor: backgroundColor,
            dividerColor: dividerColor,
            completed: completed,
            completeColor: completeColor,
          ),
        ),
      ),
    );
  }
}

class _SegmentProgressPainter extends CustomPainter {
  final List<SegmentProgress> segments;
  final int fileSize;
  final Color fillColor;
  final Color backgroundColor;
  final Color dividerColor;
  final bool completed;
  final Color completeColor;

  static const double _dividerWidth = 2;
  static const double _headWidth = 2;

  _SegmentProgressPainter({
    required this.segments,
    required this.fileSize,
    required this.fillColor,
    required this.backgroundColor,
    required this.dividerColor,
    required this.completed,
    required this.completeColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || !size.isFinite) return;
    final bounds = Offset.zero & size;
    final radius = Radius.circular(size.height / 2);
    canvas.save();
    canvas.clipRRect(RRect.fromRectAndRadius(bounds, radius));
    canvas.drawRect(bounds, Paint()..color = backgroundColor);
    if (completed) {
      canvas.drawRect(bounds, Paint()..color = completeColor);
      canvas.restore();
      return;
    }
    if (fileSize <= 0 || segments.isEmpty) {
      canvas.restore();
      return;
    }

    final fillPaint = Paint()..color = fillColor;
    final headPaint = Paint()
      ..color = Color.lerp(fillColor, Colors.white, 0.6)!;
    double toX(int byte) => byte / fileSize * size.width;

    for (final segment in segments) {
      // Ignore malformed segments and clip to the file's byte range so bad
      // values can never produce an invalid rect or clamp range.
      final length = segment.length;
      if (length <= 0) continue;
      final start = segment.startByte.clamp(0, fileSize);
      final end = (segment.endByte + 1).clamp(0, fileSize);
      if (end <= start) continue;
      final x0 = toX(start);
      final x1 = toX(end);
      final fraction = (segment.receivedBytes / length).clamp(0.0, 1.0);
      final fillEnd = x0 + (x1 - x0) * fraction;
      if (fillEnd > x0) {
        canvas.drawRect(
          Rect.fromLTRB(x0, 0, fillEnd, size.height),
          fillPaint,
        );
      }
      // Highlight the leading edge of segments that are being downloaded so
      // it is clear which parts are currently moving.
      if (segment.active && fraction < 1) {
        final headStart = (fillEnd - _headWidth).clamp(x0, fillEnd);
        canvas.drawRect(
          Rect.fromLTRB(headStart, 0, fillEnd, size.height),
          headPaint,
        );
      }
    }

    final dividerPaint = Paint()..color = dividerColor;
    for (int i = 1; i < segments.length; i++) {
      final previous = segments[i - 1];
      if (previous.complete || previous.receivedBytes >= previous.length) {
        continue;
      }
      final x = toX(segments[i].startByte);
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset(x, size.height / 2),
          width: _dividerWidth,
          height: size.height,
        ),
        dividerPaint,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _SegmentProgressPainter old) =>
      old.segments != segments ||
      old.fileSize != fileSize ||
      old.fillColor != fillColor ||
      old.backgroundColor != backgroundColor ||
      old.dividerColor != dividerColor ||
      old.completed != completed ||
      old.completeColor != completeColor;
}
