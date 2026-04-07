import 'package:flutter/material.dart';
import '../controllers/editor_controller.dart';

/// Transparent canvas on top of the image for freehand drawing.
/// Only captures gestures when [isActive] is true.
class DrawingCanvas extends StatefulWidget {
  final EditorController controller;
  final Size size;
  final bool isActive; // ← FIX: only intercept touches when drawing tool is active

  const DrawingCanvas({
    super.key,
    required this.controller,
    required this.size,
    required this.isActive,
  });

  @override
  State<DrawingCanvas> createState() => _DrawingCanvasState();
}

class _DrawingCanvasState extends State<DrawingCanvas> {
  final List<Offset> _currentPoints = [];

  void _onPanStart(DragStartDetails d) {
    if (!widget.isActive) return;
    _currentPoints
      ..clear()
      ..add(d.localPosition);
  }

  void _onPanUpdate(DragUpdateDetails d) {
    if (!widget.isActive) return;
    setState(() => _currentPoints.add(d.localPosition));
  }

  void _onPanEnd(DragEndDetails _) {
    if (!widget.isActive || _currentPoints.isEmpty) return;
    widget.controller.addStroke(DrawingStroke(
      points: List.from(_currentPoints),
      color: widget.controller.brushColor,
      strokeWidth: widget.controller.brushSize,
      isEraser: widget.controller.isEraser,
    ));
    setState(() => _currentPoints.clear());
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      // ← FIX: when drawing is not active, pass all touches through
      ignoring: !widget.isActive,
      child: GestureDetector(
        onPanStart: _onPanStart,
        onPanUpdate: _onPanUpdate,
        onPanEnd: _onPanEnd,
        child: AnimatedBuilder(
          animation: widget.controller,
          builder: (_, __) => CustomPaint(
            size: widget.size,
            painter: _DrawingPainter(
              strokes: widget.controller.strokes,
              currentPoints: List.from(_currentPoints),
              currentColor: widget.controller.brushColor,
              currentWidth: widget.controller.brushSize,
              isEraser: widget.controller.isEraser,
            ),
          ),
        ),
      ),
    );
  }
}

class _DrawingPainter extends CustomPainter {
  final List<DrawingStroke> strokes;
  final List<Offset> currentPoints;
  final Color currentColor;
  final double currentWidth;
  final bool isEraser;

  _DrawingPainter({
    required this.strokes,
    required this.currentPoints,
    required this.currentColor,
    required this.currentWidth,
    required this.isEraser,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final stroke in strokes) {
      _drawStroke(canvas, stroke.points, stroke.color, stroke.strokeWidth,
          stroke.isEraser);
    }
    if (currentPoints.isNotEmpty) {
      _drawStroke(canvas, currentPoints, currentColor, currentWidth, isEraser);
    }
  }

  void _drawStroke(Canvas canvas, List<Offset> points, Color color,
      double width, bool eraser) {
    if (points.isEmpty) return;
    final paint = Paint()
      ..color = eraser ? Colors.transparent : color
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke
      ..blendMode = eraser ? BlendMode.clear : BlendMode.srcOver;

    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      if (i < points.length - 1) {
        final mid = Offset(
          (points[i].dx + points[i + 1].dx) / 2,
          (points[i].dy + points[i + 1].dy) / 2,
        );
        path.quadraticBezierTo(
            points[i].dx, points[i].dy, mid.dx, mid.dy);
      } else {
        path.lineTo(points[i].dx, points[i].dy);
      }
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_DrawingPainter old) => true;
}
