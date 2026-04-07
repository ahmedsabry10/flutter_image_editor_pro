import 'package:flutter/material.dart';

/// A named collection of sticker widgets.
class StickerPack {
  /// Display name shown in the stickers tab (e.g. "Emoji", "Summer").
  final String name;

  /// Optional icon shown next to the pack name.
  final IconData? icon;

  /// The stickers — any Flutter widget (Image, Text, Icon, Lottie, etc.)
  final List<Widget> stickers;

  const StickerPack({
    required this.name,
    required this.stickers,
    this.icon,
  });
}

/// An active sticker placed on the canvas.
class StickerLayer {
  final String id;
  final Widget widget;
  Offset position;
  double scale;
  double rotation;

  StickerLayer({
    required this.id,
    required this.widget,
    this.position = const Offset(100, 100),
    this.scale = 1.0,
    this.rotation = 0.0,
  });

  StickerLayer copyWith({
    Offset? position,
    double? scale,
    double? rotation,
  }) {
    return StickerLayer(
      id: id,
      widget: widget,
      position: position ?? this.position,
      scale: scale ?? this.scale,
      rotation: rotation ?? this.rotation,
    );
  }
}
