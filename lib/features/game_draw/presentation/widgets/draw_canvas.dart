import 'dart:ui';
import 'package:flutter/material.dart';
import '../../domain/models/draw_point.dart';

class DrawCanvas extends StatefulWidget {
  final ValueNotifier<List<DrawPoint>> pointsNotifier;
  final void Function(DrawPoint point)? onDraw;
  final Color currentColor;
  final double currentStrokeWidth;

  const DrawCanvas({
    super.key,
    required this.pointsNotifier,
    this.onDraw,
    this.currentColor = Colors.black,
    this.currentStrokeWidth = 3.0,
  });

  @override
  State<DrawCanvas> createState() => _DrawCanvasState();
}

class _DrawCanvasState extends State<DrawCanvas> {
  DateTime _lastSendTime = DateTime.now();
  static const int _throttleMs = 32;

  void _addPoint(Offset? offset) {
    if (widget.onDraw == null) return;
    
    final point = DrawPoint(
      point: offset,
      color: widget.currentColor,
      strokeWidth: widget.currentStrokeWidth,
    );
    
    _throttleAndSend(point);
  }
  
  void _throttleAndSend(DrawPoint point) {
    if (widget.onDraw == null) return;

    if (point.point == null) {
      widget.onDraw!(point);
      return;
    }

    final now = DateTime.now();
    if (now.difference(_lastSendTime).inMilliseconds >= _throttleMs) {
      widget.onDraw!(point);
      _lastSendTime = now;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: widget.onDraw == null ? null : (details) {
        RenderBox renderBox = context.findRenderObject() as RenderBox;
        _addPoint(renderBox.globalToLocal(details.globalPosition));
      },
      onPanUpdate: widget.onDraw == null ? null : (details) {
        RenderBox renderBox = context.findRenderObject() as RenderBox;
        _addPoint(renderBox.globalToLocal(details.globalPosition));
      },
      onPanEnd: widget.onDraw == null ? null : (details) {
        _addPoint(null); // End of stroke
      },
      child: ValueListenableBuilder<List<DrawPoint>>(
        valueListenable: widget.pointsNotifier,
        builder: (context, points, _) {
          return CustomPaint(
            painter: _CanvasPainter(points: points),
            size: Size.infinite,
          );
        },
      ),
    );
  }
}

class _CanvasPainter extends CustomPainter {
  final List<DrawPoint> points;

  _CanvasPainter({required this.points});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    for (int i = 0; i < points.length - 1; i++) {
      if (points[i].point != null && points[i + 1].point != null) {
        final paint = Paint()
          ..color = points[i].color
          ..strokeCap = StrokeCap.round
          ..strokeWidth = points[i].strokeWidth;
        
        canvas.drawLine(points[i].point!, points[i + 1].point!, paint);
      } else if (points[i].point != null && points[i + 1].point == null) {
        // Draw a dot for a single tap or end of stroke
        final paint = Paint()
          ..color = points[i].color
          ..strokeCap = StrokeCap.round
          ..strokeWidth = points[i].strokeWidth;
          
        canvas.drawPoints(PointMode.points, [points[i].point!], paint);
      }
    }
    
    // Draw the last point if it exists (for a quick tap without drag, or if it's the last drawn segment)
    if (points.length == 1 && points[0].point != null) {
        final paint = Paint()
          ..color = points[0].color
          ..strokeCap = StrokeCap.round
          ..strokeWidth = points[0].strokeWidth;
        canvas.drawPoints(PointMode.points, [points[0].point!], paint);
    }
  }

  @override
  bool shouldRepaint(covariant _CanvasPainter oldDelegate) {
    return !identical(oldDelegate.points, points);
  }
}
