import 'dart:io';

import 'package:flutter/material.dart';
import 'package:window_manager/src/resize_edge.dart';
import 'package:window_manager/src/window_manager.dart';

/// A widget for drag to resize window.
///
/// Use the widget to simulate dragging the edges to resize the window.
///
/// {@tool snippet}
///
/// The sample creates a grey box, drag the box to resize the window.
///
/// ```dart
/// DragToResizeArea(
///   child: Container(
///     width: double.infinity,
///     height: double.infinity,
///     color: Colors.grey,
///   ),
///   resizeEdgeSize: 6,
///   resizeEdgeColor: Colors.red.withOpacity(0.2),
/// )
/// ```
/// {@end-tool}
class DragToResizeArea extends StatelessWidget {
  const DragToResizeArea({
    super.key,
    required this.child,
    this.resizeEdgeColor = Colors.transparent,
    this.resizeEdgeSize = 8,
    this.resizeEdgeMargin = EdgeInsets.zero,
    this.enableResizeEdges,
  });

  final Widget child;
  final double resizeEdgeSize;
  final Color resizeEdgeColor;
  final EdgeInsets resizeEdgeMargin;
  final List<ResizeEdge>? enableResizeEdges;

  Widget _buildDragToResizeEdge(
    ResizeEdge resizeEdge, {
    MouseCursor cursor = SystemMouseCursors.basic,
    double? width,
    double? height,
  }) {
    if (enableResizeEdges != null && !enableResizeEdges!.contains(resizeEdge)) {
      return Container();
    }
    return Container(
      width: width,
      height: height,
      color: resizeEdgeColor,
      child: MouseRegion(
        cursor: cursor,
        child: GestureDetector(
          onPanStart: (_) => windowManager.startResizing(resizeEdge),
          onDoubleTap: () => (Platform.isWindows &&
                  (resizeEdge == ResizeEdge.top ||
                      resizeEdge == ResizeEdge.bottom))
              ? windowManager.maximize(vertically: true)
              : null,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        child,
        Positioned(
          child: Container(
            margin: resizeEdgeMargin,
            child: Column(
              children: [
                Row(
                  children: [
                    _buildDragToResizeEdge(
                      ResizeEdge.topLeft,
                      cursor: SystemMouseCursors.resizeUpLeft,
                      width: resizeEdgeSize,
                      height: resizeEdgeSize,
                    ),
                    Expanded(
                      flex: 1,
                      child: _buildDragToResizeEdge(
                        ResizeEdge.top,
                        cursor: SystemMouseCursors.resizeUp,
                        height: resizeEdgeSize,
                      ),
                    ),
                    _buildDragToResizeEdge(
                      ResizeEdge.topRight,
                      cursor: SystemMouseCursors.resizeUpRight,
                      width: resizeEdgeSize,
                      height: resizeEdgeSize,
                    ),
                  ],
                ),
                Expanded(
                  flex: 1,
                  child: Row(
                    children: [
                      _buildDragToResizeEdge(
                        ResizeEdge.left,
                        cursor: SystemMouseCursors.resizeLeft,
                        width: resizeEdgeSize,
                        height: double.infinity,
                      ),
                      Expanded(
                        flex: 1,
                        child: Container(),
                      ),
                      _buildDragToResizeEdge(
                        ResizeEdge.right,
                        cursor: SystemMouseCursors.resizeRight,
                        width: resizeEdgeSize,
                        height: double.infinity,
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    _buildDragToResizeEdge(
                      ResizeEdge.bottomLeft,
                      cursor: SystemMouseCursors.resizeDownLeft,
                      width: resizeEdgeSize,
                      height: resizeEdgeSize,
                    ),
                    Expanded(
                      flex: 1,
                      child: _buildDragToResizeEdge(
                        ResizeEdge.bottom,
                        cursor: SystemMouseCursors.resizeDown,
                        height: resizeEdgeSize,
                      ),
                    ),
                    _buildDragToResizeEdge(
                      ResizeEdge.bottomRight,
                      cursor: SystemMouseCursors.resizeDownRight,
                      width: resizeEdgeSize,
                      height: resizeEdgeSize,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
