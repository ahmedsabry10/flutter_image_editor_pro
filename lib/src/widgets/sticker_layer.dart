import 'package:flutter/material.dart';
import '../controllers/editor_controller.dart';
import '../models/sticker_pack.dart';
import '../models/editor_theme.dart';

/// Renders all sticker layers with drag / pinch-to-scale / rotate support.
class StickerLayerWidget extends StatelessWidget {
  final EditorController controller;
  final EditorTheme theme;

  const StickerLayerWidget({
    super.key,
    required this.controller,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) => Stack(
        children: controller.stickerLayers
            .map((s) => _InteractiveSticker(
                  key: ValueKey(s.id),
                  sticker: s,
                  theme: theme,
                  onUpdate: controller.updateSticker,
                  onDelete: () => controller.removeSticker(s.id),
                ))
            .toList(),
      ),
    );
  }
}

class _InteractiveSticker extends StatefulWidget {
  final StickerLayer sticker;
  final EditorTheme theme;
  final void Function(StickerLayer) onUpdate;
  final VoidCallback onDelete;

  const _InteractiveSticker({
    super.key,
    required this.sticker,
    required this.theme,
    required this.onUpdate,
    required this.onDelete,
  });

  @override
  State<_InteractiveSticker> createState() => _InteractiveStickerState();
}

class _InteractiveStickerState extends State<_InteractiveSticker> {
  bool _selected = false;
  late StickerLayer _sticker;

  @override
  void initState() {
    super.initState();
    _sticker = widget.sticker;
  }

  void _onScaleUpdate(ScaleUpdateDetails d) {
    setState(() {
      _sticker = _sticker.copyWith(
        position: _sticker.position + d.focalPointDelta,
        scale: (_sticker.scale * d.scale).clamp(0.3, 5.0),
        rotation: _sticker.rotation + d.rotation,
      );
    });
    widget.onUpdate(_sticker);
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: _sticker.position.dx,
      top: _sticker.position.dy,
      child: GestureDetector(
        onTap: () => setState(() => _selected = !_selected),
        onScaleUpdate: _onScaleUpdate,
        child: Transform.rotate(
          angle: _sticker.rotation,
          child: Transform.scale(
            scale: _sticker.scale,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  decoration: _selected
                      ? BoxDecoration(
                          border:
                              Border.all(color: Colors.white54, width: 1),
                          borderRadius: BorderRadius.circular(4),
                        )
                      : null,
                  child: _sticker.widget,
                ),
                if (_selected)
                  Positioned(
                    top: -12,
                    right: -12,
                    child: GestureDetector(
                      onTap: widget.onDelete,
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close,
                            color: Colors.white, size: 14),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Bottom sheet for browsing and picking stickers from packs.
class StickerPickerSheet extends StatefulWidget {
  final List<StickerPack> packs;
  final EditorTheme theme;
  final void Function(Widget sticker) onPick;

  const StickerPickerSheet({
    super.key,
    required this.packs,
    required this.theme,
    required this.onPick,
  });

  @override
  State<StickerPickerSheet> createState() => _StickerPickerSheetState();
}

class _StickerPickerSheetState extends State<StickerPickerSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: widget.packs.length, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.packs.isEmpty) {
      return Container(
        height: 200,
        color: widget.theme.toolbarColor,
        child: Center(
          child: Text('No sticker packs provided.',
              style: TextStyle(color: widget.theme.iconColor)),
        ),
      );
    }
    return Container(
      height: 300,
      decoration: BoxDecoration(
        color: widget.theme.toolbarColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          TabBar(
            controller: _tabCtrl,
            indicatorColor: widget.theme.activeToolColor,
            labelColor: widget.theme.activeToolColor,
            unselectedLabelColor: widget.theme.iconColor,
            tabs: widget.packs
                .map((p) => Tab(
                      text: p.name,
                      icon: p.icon != null ? Icon(p.icon, size: 16) : null,
                    ))
                .toList(),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabCtrl,
              children: widget.packs
                  .map((pack) => GridView.builder(
                        padding: const EdgeInsets.all(12),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 5,
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                        ),
                        itemCount: pack.stickers.length,
                        itemBuilder: (_, i) => GestureDetector(
                          onTap: () {
                            widget.onPick(pack.stickers[i]);
                            Navigator.pop(context);
                          },
                          child: pack.stickers[i],
                        ),
                      ))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }
}
