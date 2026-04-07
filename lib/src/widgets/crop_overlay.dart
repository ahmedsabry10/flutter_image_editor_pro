import 'package:flutter/material.dart';
import '../models/editor_config.dart';

/// Interactive crop overlay.
///
/// Receives [canvasSize] and [imageAspect] so it can compute the exact
/// rendered-image rect (accounting for BoxFit.contain letterboxing) and
/// constrain the crop handles to that region.
class CropOverlay extends StatefulWidget {
  final Size canvasSize;
  final double imageAspect; // imgWidth / imgHeight
  final List<CropAspectRatio> ratios;
  final void Function(Rect cropRect) onCropChanged;
  final VoidCallback onApply;

  const CropOverlay({
    super.key,
    required this.canvasSize,
    required this.imageAspect,
    required this.ratios,
    required this.onCropChanged,
    required this.onApply,
  });

  @override
  State<CropOverlay> createState() => _CropOverlayState();
}

class _CropOverlayState extends State<CropOverlay> {
  /// The actual rect the image occupies inside the canvas (letterbox-aware).
  late Rect _imageRect;
  /// Current crop rect — always in canvas coordinates.
  late Rect _cropRect;
  CropAspectRatio _selectedRatio = CropAspectRatio.free;

  @override
  void initState() {
    super.initState();
    _imageRect = _computeImageRect();
    // Default crop = full image area (with small inset so handles are visible)
    _cropRect = _imageRect.deflate(1);
  }

  @override
  void didUpdateWidget(CropOverlay old) {
    super.didUpdateWidget(old);
    if (old.canvasSize != widget.canvasSize ||
        old.imageAspect != widget.imageAspect) {
      _imageRect = _computeImageRect();
      _cropRect = _imageRect.deflate(1);
    }
  }

  /// Compute the rect the image occupies inside [canvasSize] with BoxFit.contain.
  Rect _computeImageRect() {
    final cs = widget.canvasSize;
    final ia = widget.imageAspect;
    final ca = cs.width / cs.height;

    double rw, rh, ox, oy;
    if (ia > ca) {
      // Letterboxed top/bottom
      rw = cs.width;
      rh = cs.width / ia;
      ox = 0;
      oy = (cs.height - rh) / 2;
    } else {
      // Pillarboxed left/right
      rh = cs.height;
      rw = cs.height * ia;
      ox = (cs.width - rw) / 2;
      oy = 0;
    }
    return Rect.fromLTWH(ox, oy, rw, rh);
  }

  void _applyRatio(CropAspectRatio ratio) {
    setState(() {
      _selectedRatio = ratio;
      if (ratio.ratio == null) return; // free

      final w = _cropRect.width;
      final h = w / ratio.ratio!;
      double top = _cropRect.top + (_cropRect.height - h) / 2;
      top = top.clamp(_imageRect.top, _imageRect.bottom - h);
      final bottom = (top + h).clamp(top + 40.0, _imageRect.bottom);
      _cropRect = Rect.fromLTRB(
          _cropRect.left, top, _cropRect.right, bottom);
    });
    widget.onCropChanged(_cropRect);
  }

  void _onHandleDrag(String handle, DragUpdateDetails d) {
    setState(() {
      double l = _cropRect.left, t = _cropRect.top;
      double r = _cropRect.right, b = _cropRect.bottom;
      final dx = d.delta.dx, dy = d.delta.dy;
      const minSize = 40.0;

      if (handle.contains('l'))
        l = (l + dx).clamp(_imageRect.left, r - minSize);
      if (handle.contains('r'))
        r = (r + dx).clamp(l + minSize, _imageRect.right);
      if (handle.contains('t'))
        t = (t + dy).clamp(_imageRect.top, b - minSize);
      if (handle.contains('b'))
        b = (b + dy).clamp(t + minSize, _imageRect.bottom);

      if (_selectedRatio.ratio != null) {
        final w = r - l;
        if (handle.contains('l') || handle.contains('r')) {
          b = (t + w / _selectedRatio.ratio!)
              .clamp(t + minSize, _imageRect.bottom);
        } else {
          r = (l + (b - t) * _selectedRatio.ratio!)
              .clamp(l + minSize, _imageRect.right);
        }
      }

      _cropRect = Rect.fromLTRB(l, t, r, b);
    });
    widget.onCropChanged(_cropRect);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Dim everything outside the image area + dim the uncropped area
        Positioned.fill(
          child: CustomPaint(
            size: widget.canvasSize,
            painter: _DimPainter(
              canvasSize: widget.canvasSize,
              imageRect: _imageRect,
              cropRect: _cropRect,
            ),
          ),
        ),

        // Crop border + rule-of-thirds grid
        Positioned(
          left: _cropRect.left,
          top: _cropRect.top,
          width: _cropRect.width,
          height: _cropRect.height,
          child: Container(
            decoration:
                BoxDecoration(border: Border.all(color: Colors.white, width: 1.5)),
            child: CustomPaint(painter: _GridPainter()),
          ),
        ),

        // Corner handles
        ..._buildHandles(),

        // Bottom bar: ratios + Apply
        Positioned(
          bottom: 0, left: 0, right: 0,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            _buildRatioBar(),
            GestureDetector(
              onTap: widget.onApply,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 13),
                color: const Color(0xFF00B4D8),
                child: const Text(
                  '✓  Apply Crop',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15),
                ),
              ),
            ),
          ]),
        ),
      ],
    );
  }

  List<Widget> _buildHandles() {
    final handles = {
      'tl': Offset(_cropRect.left, _cropRect.top),
      'tr': Offset(_cropRect.right, _cropRect.top),
      'bl': Offset(_cropRect.left, _cropRect.bottom),
      'br': Offset(_cropRect.right, _cropRect.bottom),
    };
    return handles.entries.map((e) {
      return Positioned(
        left: e.value.dx - 14,
        top: e.value.dy - 14,
        child: GestureDetector(
          onPanUpdate: (d) => _onHandleDrag(e.key, d),
          child: Container(
            width: 28, height: 28,
            decoration:
                const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
          ),
        ),
      );
    }).toList();
  }

  Widget _buildRatioBar() {
    final ratios =
        widget.ratios.isEmpty ? CropAspectRatio.defaultRatios : widget.ratios;
    return Container(
      height: 44,
      color: Colors.black54,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        children: ratios.map((r) {
          final isSel = r.label == _selectedRatio.label;
          return GestureDetector(
            onTap: () => _applyRatio(r),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: isSel ? Colors.white : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white54),
              ),
              child: Text(
                r.label,
                style: TextStyle(
                  color: isSel ? Colors.black : Colors.white,
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

/// Dims everything OUTSIDE the crop rect.
/// Also dims the area inside [imageRect] but outside [cropRect],
/// and fully blacks out the letterbox bars (outside [imageRect]).
class _DimPainter extends CustomPainter {
  final Size canvasSize;
  final Rect imageRect;
  final Rect cropRect;

  _DimPainter({
    required this.canvasSize,
    required this.imageRect,
    required this.cropRect,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final fullRect = Rect.fromLTWH(0, 0, canvasSize.width, canvasSize.height);

    // 1) Dim letterbox bars (outside image rect) — dark
    final barPaint = Paint()..color = Colors.black.withOpacity(0.75);
    final barPath = Path()
      ..addRect(fullRect)
      ..addRect(imageRect)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(barPath, barPaint);

    // 2) Dim image area that is NOT inside the crop rect — semi-transparent
    final dimPaint = Paint()..color = Colors.black.withOpacity(0.55);
    final dimPath = Path()
      ..addRect(imageRect)
      ..addRect(cropRect)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(dimPath, dimPaint);
  }

  @override
  bool shouldRepaint(_DimPainter old) =>
      old.cropRect != cropRect ||
      old.imageRect != imageRect ||
      old.canvasSize != canvasSize;
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white30
      ..strokeWidth = 0.5;
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
