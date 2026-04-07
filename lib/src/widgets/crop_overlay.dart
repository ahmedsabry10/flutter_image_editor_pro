import 'package:flutter/material.dart';
import '../models/editor_config.dart';

/// Interactive crop overlay with draggable corner handles.
/// FIX: Added [onApply] callback so the crop is actually committed.
class CropOverlay extends StatefulWidget {
  final Size imageSize;
  final List<CropAspectRatio> ratios;
  final void Function(Rect cropRect) onCropChanged;
  final VoidCallback onApply; // ← FIX

  const CropOverlay({
    super.key,
    required this.imageSize,
    required this.ratios,
    required this.onCropChanged,
    required this.onApply,
  });

  @override
  State<CropOverlay> createState() => _CropOverlayState();
}

class _CropOverlayState extends State<CropOverlay> {
  late Rect _cropRect;
  CropAspectRatio _selectedRatio = CropAspectRatio.free;

  @override
  void initState() {
    super.initState();
    // Default crop = full image with 10px inset so handles are visible
    _cropRect = Rect.fromLTWH(
      10, 10,
      widget.imageSize.width - 20,
      widget.imageSize.height - 20,
    );
  }

  void _applyRatio(CropAspectRatio ratio) {
    setState(() {
      _selectedRatio = ratio;
      if (ratio.ratio == null) return;
      final w = _cropRect.width;
      final h = w / ratio.ratio!;
      final top = (_cropRect.top + (_cropRect.height - h) / 2)
          .clamp(0.0, widget.imageSize.height - h);
      _cropRect = Rect.fromLTWH(_cropRect.left, top, w, h.clamp(40.0, widget.imageSize.height));
    });
    widget.onCropChanged(_cropRect);
  }

  void _onHandleDrag(String handle, DragUpdateDetails d) {
    setState(() {
      double l = _cropRect.left, t = _cropRect.top;
      double r = _cropRect.right, b = _cropRect.bottom;
      final dx = d.delta.dx, dy = d.delta.dy;
      const minSize = 40.0;

      if (handle.contains('l')) l = (l + dx).clamp(0.0, r - minSize);
      if (handle.contains('r')) r = (r + dx).clamp(l + minSize, widget.imageSize.width);
      if (handle.contains('t')) t = (t + dy).clamp(0.0, b - minSize);
      if (handle.contains('b')) b = (b + dy).clamp(t + minSize, widget.imageSize.height);

      if (_selectedRatio.ratio != null) {
        final w = r - l;
        if (handle.contains('l') || handle.contains('r')) {
          b = t + w / _selectedRatio.ratio!;
        } else {
          r = l + (b - t) * _selectedRatio.ratio!;
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
        // Dim layer
        CustomPaint(
          size: widget.imageSize,
          painter: _DimPainter(cropRect: _cropRect),
        ),
        // Crop border + rule-of-thirds grid
        Positioned(
          left: _cropRect.left,
          top: _cropRect.top,
          width: _cropRect.width,
          height: _cropRect.height,
          child: Container(
            decoration: BoxDecoration(border: Border.all(color: Colors.white, width: 1.5)),
            child: CustomPaint(painter: _GridPainter()),
          ),
        ),
        // Corner handles
        ..._buildHandles(),
        // Bottom bar: ratio selector + Apply button
        Positioned(
          bottom: 0, left: 0, right: 0,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildRatioBar(),
              // ── Apply crop button ──────────────────────────────────────
              GestureDetector(
                onTap: widget.onApply,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  color: const Color(0xFF00B4D8),
                  child: const Text(
                    'Apply Crop ✓',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _buildHandles() {
    const handles = {
      'tl': [false, false],
      'tr': [true, false],
      'bl': [false, true],
      'br': [true, true],
    };
    return handles.entries.map((e) {
      final dx = e.value[0] ? _cropRect.right : _cropRect.left;
      final dy = e.value[1] ? _cropRect.bottom : _cropRect.top;
      return Positioned(
        left: dx - 14,
        top: dy - 14,
        child: GestureDetector(
          onPanUpdate: (d) => _onHandleDrag(e.key, d),
          child: Container(
            width: 28, height: 28,
            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
          ),
        ),
      );
    }).toList();
  }

  Widget _buildRatioBar() {
    final ratios = widget.ratios.isEmpty ? CropAspectRatio.defaultRatios : widget.ratios;
    return Container(
      height: 44,
      color: Colors.black54,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
    final paint = Paint()..color = Colors.white24..strokeWidth = 0.5;
    canvas.drawLine(Offset(size.width / 3, 0), Offset(size.width / 3, size.height), paint);
    canvas.drawLine(Offset(size.width * 2 / 3, 0), Offset(size.width * 2 / 3, size.height), paint);
    canvas.drawLine(Offset(0, size.height / 3), Offset(size.width, size.height / 3), paint);
    canvas.drawLine(Offset(0, size.height * 2 / 3), Offset(size.width, size.height * 2 / 3), paint);
  }

  @override
  bool shouldRepaint(_GridPainter _) => false;
}
