import 'package:flutter/material.dart';
import '../models/editor_config.dart';

/// Interactive crop overlay with draggable handles.
class CropOverlay extends StatefulWidget {
  final Size imageSize;
  final List<CropAspectRatio> ratios;
  final void Function(Rect cropRect) onCropChanged;

  const CropOverlay({
    super.key,
    required this.imageSize,
    required this.ratios,
    required this.onCropChanged,
  });

  @override
  State<CropOverlay> createState() => _CropOverlayState();
}

class _CropOverlayState extends State<CropOverlay> {
  late Rect _cropRect;
  CropAspectRatio _selectedRatio = CropAspectRatio.free;
  String? _activeHandle; // 'tl','tr','bl','br','t','b','l','r'

  @override
  void initState() {
    super.initState();
    _cropRect = Rect.fromLTWH(0, 0, widget.imageSize.width,
        widget.imageSize.height);
  }

  void _applyRatio(CropAspectRatio ratio) {
    setState(() {
      _selectedRatio = ratio;
      if (ratio.ratio == null) return; // free
      final w = _cropRect.width;
      final h = w / ratio.ratio!;
      final top = _cropRect.top + (_cropRect.height - h) / 2;
      _cropRect = Rect.fromLTWH(_cropRect.left, top, w, h);
    });
    widget.onCropChanged(_cropRect);
  }

  void _onHandleDrag(String handle, DragUpdateDetails d) {
    setState(() {
      double l = _cropRect.left, t = _cropRect.top;
      double r = _cropRect.right, b = _cropRect.bottom;
      final dx = d.delta.dx, dy = d.delta.dy;
      const minSize = 40.0;

      if (handle.contains('l')) l = (l + dx).clamp(0, r - minSize);
      if (handle.contains('r'))
        r = (r + dx).clamp(l + minSize, widget.imageSize.width);
      if (handle.contains('t')) t = (t + dy).clamp(0, b - minSize);
      if (handle.contains('b'))
        b = (b + dy).clamp(t + minSize, widget.imageSize.height);

      if (_selectedRatio.ratio != null) {
        // Lock ratio — adjust the non-dragged axis
        final w = r - l, h = b - t;
        if (handle.contains('l') || handle.contains('r')) {
          final newH = w / _selectedRatio.ratio!;
          b = t + newH;
        } else {
          final newW = h * _selectedRatio.ratio!;
          r = l + newW;
        }
      }

      _cropRect = Rect.fromLTRB(l, t, r, b);
    });
    widget.onCropChanged(_cropRect);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Dim outside crop
        _buildDimLayer(),
        // Crop border + grid
        Positioned(
          left: _cropRect.left,
          top: _cropRect.top,
          width: _cropRect.width,
          height: _cropRect.height,
          child: _buildCropBorder(),
        ),
        // Handles
        ..._buildHandles(),
        // Ratio selector at bottom
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: _buildRatioBar(),
        ),
      ],
    );
  }

  Widget _buildDimLayer() {
    return CustomPaint(
      size: widget.imageSize,
      painter: _DimPainter(cropRect: _cropRect),
    );
  }

  Widget _buildCropBorder() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: CustomPaint(
        painter: _GridPainter(),
      ),
    );
  }

  List<Widget> _buildHandles() {
    const handles = {
      'tl': Alignment.topLeft,
      'tr': Alignment.topRight,
      'bl': Alignment.bottomLeft,
      'br': Alignment.bottomRight,
    };
    return handles.entries.map((e) {
      final dx = e.value.x == -1 ? _cropRect.left : _cropRect.right;
      final dy = e.value.y == -1 ? _cropRect.top : _cropRect.bottom;
      return Positioned(
        left: dx - 12,
        top: dy - 12,
        child: GestureDetector(
          onPanUpdate: (d) => _onHandleDrag(e.key, d),
          child: Container(
            width: 24,
            height: 24,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
        ),
      );
    }).toList();
  }

  Widget _buildRatioBar() {
    final ratios = widget.ratios.isEmpty
        ? CropAspectRatio.defaultRatios
        : widget.ratios;
    return Container(
      height: 48,
      color: Colors.black54,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        children: ratios.map((r) {
          final isSelected = r.label == _selectedRatio.label;
          return GestureDetector(
            onTap: () => _applyRatio(r),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: isSelected ? Colors.white : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white54),
              ),
              child: Text(
                r.label,
                style: TextStyle(
                  color: isSelected ? Colors.black : Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _DimPainter extends CustomPainter {
  final Rect cropRect;
  _DimPainter({required this.cropRect});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black54;
    final full = Rect.fromLTWH(0, 0, size.width, size.height);
    final path = Path()
      ..addRect(full)
      ..addRect(cropRect)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_DimPainter old) => old.cropRect != cropRect;
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white24
      ..strokeWidth = 0.5;
    // Thirds grid
    canvas.drawLine(Offset(size.width / 3, 0),
        Offset(size.width / 3, size.height), paint);
    canvas.drawLine(Offset(size.width * 2 / 3, 0),
        Offset(size.width * 2 / 3, size.height), paint);
    canvas.drawLine(Offset(0, size.height / 3),
        Offset(size.width, size.height / 3), paint);
    canvas.drawLine(Offset(0, size.height * 2 / 3),
        Offset(size.width, size.height * 2 / 3), paint);
  }

  @override
  bool shouldRepaint(_GridPainter _) => false;
}
