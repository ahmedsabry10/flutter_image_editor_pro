import 'package:flutter/material.dart';
import '../models/editor_config.dart';

/// Interactive crop overlay.
/// Uses its own LayoutBuilder internally — no canvasSize param needed.
class CropOverlay extends StatefulWidget {
  final double imageAspect; // imgWidth / imgHeight
  final List<CropAspectRatio> ratios;
  final void Function(Rect cropRect) onCropChanged;
  final VoidCallback onApply;

  const CropOverlay({
    super.key,
    required this.imageAspect,
    required this.ratios,
    required this.onCropChanged,
    required this.onApply,
  });

  @override
  State<CropOverlay> createState() => _CropOverlayState();
}

class _CropOverlayState extends State<CropOverlay> {
  Rect? _imageRect;
  Rect? _cropRect;
  CropAspectRatio _selectedRatio = CropAspectRatio.free;

  /// Compute the rect the image occupies with BoxFit.contain inside [canvasSize].
  Rect _computeImageRect(Size cs) {
    final ia = widget.imageAspect.isFinite && widget.imageAspect > 0
        ? widget.imageAspect
        : 1.0;
    final ca = cs.width / cs.height;
    double rw, rh, ox, oy;
    if (ia > ca) {
      rw = cs.width;
      rh = cs.width / ia;
      ox = 0;
      oy = (cs.height - rh) / 2;
    } else {
      rh = cs.height;
      rw = cs.height * ia;
      ox = (cs.width - rw) / 2;
      oy = 0;
    }
    return Rect.fromLTWH(ox, oy, rw, rh);
  }

  void _initRects(Size cs) {
    final ir = _computeImageRect(cs);
    _imageRect = ir;
    // Inset by 8px so handles are clearly visible
    _cropRect = ir.deflate(8).isEmpty ? ir : ir.deflate(8);
  }

  void _applyRatio(CropAspectRatio ratio, Size cs) {
    final ir = _imageRect ?? _computeImageRect(cs);
    setState(() {
      _selectedRatio = ratio;
      if (ratio.ratio == null) return;
      final cr = _cropRect ?? ir;
      final w = cr.width;
      final h = w / ratio.ratio!;
      double top = cr.center.dy - h / 2;
      top = top.clamp(ir.top, ir.bottom - h.clamp(40, ir.height));
      final bottom = (top + h).clamp(top + 40.0, ir.bottom);
      _cropRect = Rect.fromLTRB(cr.left, top, cr.right, bottom);
    });
    widget.onCropChanged(_cropRect!);
  }

  void _onHandleDrag(String handle, DragUpdateDetails d, Size cs) {
    final ir = _imageRect ?? _computeImageRect(cs);
    setState(() {
      final cr = _cropRect ?? ir;
      double l = cr.left, t = cr.top, r = cr.right, b = cr.bottom;
      final dx = d.delta.dx, dy = d.delta.dy;
      const minSize = 40.0;

      if (handle.contains('l')) l = (l + dx).clamp(ir.left, r - minSize);
      if (handle.contains('r')) r = (r + dx).clamp(l + minSize, ir.right);
      if (handle.contains('t')) t = (t + dy).clamp(ir.top, b - minSize);
      if (handle.contains('b')) b = (b + dy).clamp(t + minSize, ir.bottom);

      if (_selectedRatio.ratio != null) {
        final w = r - l;
        if (handle.contains('l') || handle.contains('r')) {
          b = (t + w / _selectedRatio.ratio!).clamp(t + minSize, ir.bottom);
        } else {
          r = (l + (b - t) * _selectedRatio.ratio!).clamp(l + minSize, ir.right);
        }
      }
      _cropRect = Rect.fromLTRB(l, t, r, b);
    });
    widget.onCropChanged(_cropRect!);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (ctx, constraints) {
      final cs = Size(constraints.maxWidth, constraints.maxHeight);

      // Init on first build or if canvas size changed
      if (_imageRect == null ||
          _imageRect!.width != cs.width && _imageRect!.height != cs.height) {
        _initRects(cs);
      }

      final ir = _imageRect!;
      final cr = _cropRect!;

      return SizedBox.expand(
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // ── Dim layer ──────────────────────────────────────────────────
            Positioned.fill(
              child: CustomPaint(
                painter: _DimPainter(imageRect: ir, cropRect: cr),
              ),
            ),

            // ── Crop border + grid ─────────────────────────────────────────
            Positioned(
              left: cr.left,
              top: cr.top,
              width: cr.width,
              height: cr.height,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                  child: CustomPaint(painter: _GridPainter()),
                ),
              ),
            ),

            // ── Corner handles ─────────────────────────────────────────────
            ..._buildHandles(cr, cs),

            // ── Bottom bar: ratios + Apply ─────────────────────────────────
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildRatioBar(cs),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: widget.onApply,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        color: const Color(0xFF00B4D8),
                        child: const Text(
                          '✓  Apply Crop',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    });
  }

  List<Widget> _buildHandles(Rect cr, Size cs) {
    const hSize = 30.0;
    const half = hSize / 2;
    final handles = {
      'tl': Offset(cr.left, cr.top),
      'tr': Offset(cr.right, cr.top),
      'bl': Offset(cr.left, cr.bottom),
      'br': Offset(cr.right, cr.bottom),
    };
    return handles.entries.map((e) {
      return Positioned(
        left: e.value.dx - half,
        top: e.value.dy - half,
        width: hSize,
        height: hSize,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanUpdate: (d) => _onHandleDrag(e.key, d, cs),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: Colors.black38, blurRadius: 4),
              ],
            ),
          ),
        ),
      );
    }).toList();
  }

  Widget _buildRatioBar(Size cs) {
    final ratios = widget.ratios.isEmpty
        ? CropAspectRatio.defaultRatios
        : widget.ratios;
    return Container(
      height: 48,
      color: Colors.black.withOpacity(0.6),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        children: ratios.map((r) {
          final isSel = r.label == _selectedRatio.label;
          return GestureDetector(
            onTap: () => _applyRatio(r, cs),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: isSel ? Colors.white : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white60),
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

// ── Painters ───────────────────────────────────────────────────────────────

class _DimPainter extends CustomPainter {
  final Rect imageRect;
  final Rect cropRect;
  _DimPainter({required this.imageRect, required this.cropRect});

  @override
  void paint(Canvas canvas, Size size) {
    final full = Offset.zero & size;

    // Black bars outside image area
    canvas.drawPath(
      Path()
        ..addRect(full)
        ..addRect(imageRect)
        ..fillType = PathFillType.evenOdd,
      Paint()..color = Colors.black.withOpacity(0.8),
    );

    // Semi-dim inside image but outside crop
    canvas.drawPath(
      Path()
        ..addRect(imageRect)
        ..addRect(cropRect)
        ..fillType = PathFillType.evenOdd,
      Paint()..color = Colors.black.withOpacity(0.5),
    );
  }

  @override
  bool shouldRepaint(_DimPainter old) =>
      old.cropRect != cropRect || old.imageRect != imageRect;
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = Colors.white38
      ..strokeWidth = 0.6;
    canvas.drawLine(Offset(size.width / 3, 0), Offset(size.width / 3, size.height), p);
    canvas.drawLine(Offset(size.width * 2 / 3, 0), Offset(size.width * 2 / 3, size.height), p);
    canvas.drawLine(Offset(0, size.height / 3), Offset(size.width, size.height / 3), p);
    canvas.drawLine(Offset(0, size.height * 2 / 3), Offset(size.width, size.height * 2 / 3), p);
  }

  @override
  bool shouldRepaint(_GridPainter _) => false;
}
