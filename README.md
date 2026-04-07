# flutter_image_editor_pro

[![pub.dev](https://img.shields.io/pub/v/flutter_image_editor_pro.svg)](https://pub.dev/packages/flutter_image_editor_pro)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-Android%20%7C%20iOS%20%7C%20Web%20%7C%20Desktop-brightgreen)](#)

A complete, fully customizable image editor for Flutter.  
Supports **crop, rotate, 20+ filters, adjust, freehand drawing, text overlay, stickers, and unlimited undo/redo** — all in one widget.

**Pure Flutter** — no native code, no platform channels. Works on Android, iOS, Web, macOS, Windows, and Linux from the same codebase.

---

## Screenshots

| Filters | Drawing | Text | Stickers |
|---------|---------|------|---------|
| _(screenshot)_ | _(screenshot)_ | _(screenshot)_ | _(screenshot)_ |

---

## Features

- **Crop & Rotate** — free-form or locked aspect ratios (1:1, 4:3, 16:9, 9:16, custom), flip H/V
- **20+ Built-in Filters** — vintage, fade, sepia, noir, vivid, ocean, and more — via `ColorFilter.matrix`
- **Custom Filters** — bring your own `ColorMatrix` presets
- **Adjust** — brightness, contrast, saturation, warmth — all with live preview
- **Freehand Drawing** — pen, brush, eraser — custom color and stroke width
- **Text Overlay** — add, drag, resize, and edit text layers with font/color/shadow options
- **Stickers** — drag, pinch-to-scale, and rotate any Flutter widget as a sticker
- **Unlimited Undo / Redo** — full history stack with configurable depth
- **Export** — PNG or JPEG with custom quality and pixel ratio
- **Two usage modes** — full-screen page (`ImageEditorPro.open`) or embedded widget (`ImageEditorWidget`)
- **Fully themeable** — dark, light, or fully custom theme

---

## Installation

```yaml
dependencies:
  flutter_image_editor_pro: ^1.0.0
```

```bash
flutter pub get
```

---

## Quick Start

### Option A — Full-screen page (recommended)

```dart
import 'package:flutter_image_editor_pro/flutter_image_editor_pro.dart';

final result = await ImageEditorPro.open(
  context: context,
  image: myFile,           // File | Uint8List | String (url) | ImageProvider
);

if (result != null) {
  final bytes = result.bytes;   // Uint8List — ready to save or display
  final width = result.width;
  final height = result.height;
}
```

### Option B — Embedded widget

```dart
ImageEditorWidget(
  image: myFile,
  config: EditorConfig(
    enableCrop: true,
    enableFilters: true,
    enableDrawing: true,
    enableText: true,
    enableStickers: true,
    stickerPacks: [myStickerPack],
    exportOptions: ExportOptions(
      format: ExportFormat.jpeg,
      jpegQuality: 0.92,
    ),
  ),
  theme: EditorTheme.dark(),
  onExport: (result) {
    // Handle result.bytes
  },
  onClose: () => Navigator.pop(context),
)
```

---

## EditorConfig

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `enableCrop` | `bool` | `true` | Show crop & rotate tab |
| `cropAspectRatios` | `List<CropAspectRatio>?` | all built-in | Ratios shown in crop mode |
| `enableFilters` | `bool` | `true` | Show filters tab |
| `customFilters` | `List<FilterPreset>?` | `null` | Your own filter presets |
| `prependCustomFilters` | `bool` | `false` | Show custom filters before built-in |
| `enableAdjust` | `bool` | `true` | Show adjust tab |
| `enableDrawing` | `bool` | `true` | Show drawing tab |
| `brushColors` | `List<Color>` | 9 colors | Colors in brush color picker |
| `enableText` | `bool` | `true` | Show text overlay tab |
| `availableFonts` | `List<String>` | system fonts | Font families for text overlay |
| `enableStickers` | `bool` | `true` | Show stickers tab |
| `stickerPacks` | `List<StickerPack>` | `[]` | Your sticker packs |
| `maxUndoSteps` | `int` | `20` | History depth |
| `exportOptions` | `ExportOptions` | PNG, quality 0.92 | Export format & quality |

---

## EditorController

For programmatic control, create an `EditorController` and pass it to the widget:

```dart
final controller = EditorController();

// Switch tools
controller.setTool(EditorTool.filters);

// Apply a filter
controller.setFilter(FilterPreset.vintage);

// Drawing
controller.setBrushColor(Colors.red);
controller.setBrushSize(8.0);
controller.setEraser(true);

// Text
controller.addTextLayer(TextLayer(
  id: UniqueKey().toString(),
  text: 'Hello World',
  color: Colors.white,
  fontSize: 32,
));

// Undo / Redo
controller.undo();
controller.redo();

// Reset everything
controller.reset();
```

---

## Custom Filters

```dart
final myFilter = FilterPreset(
  name: 'My Filter',
  matrix: [
    1.2, 0.0, 0.0, 0, 0,
    0.0, 1.0, 0.0, 0, 0,
    0.0, 0.0, 0.8, 0, 0,
    0.0, 0.0, 0.0, 1, 0,
  ],
);

EditorConfig(
  customFilters: [myFilter],
  prependCustomFilters: true,   // show before built-in
)
```

---

## Sticker Packs

Any Flutter widget can be a sticker — `Image`, `Text`, `Icon`, `Lottie`, etc.

```dart
final myPack = StickerPack(
  name: 'My Pack',
  icon: Icons.emoji_emotions,
  stickers: [
    Image.asset('assets/sticker1.png', width: 80),
    Image.asset('assets/sticker2.png', width: 80),
    Text('🔥', style: TextStyle(fontSize: 48)),
  ],
);

EditorConfig(stickerPacks: [myPack])
```

---

## Theming

```dart
// Built-in themes
EditorTheme.dark()
EditorTheme.light()

// Custom theme
EditorTheme.dark().copyWith(
  activeToolColor: Colors.orange,
  exportButtonColor: Colors.orange,
)
```

---

## Built-in Filters

`normal` · `vintage` · `fade` · `cool` · `warm` · `vivid` · `chrome` · `forest` · `ocean` · `golden` · `sepia` · `sunset` · `noir` · `dramatic` · `matte` · `bloom` · `clarendon` · `lush` · `bronze` · `bw`

---

## Callbacks

| Callback | Signature | When |
|----------|-----------|------|
| `onExport` | `(EditorResult)` | User taps Save |
| `onClose` | `()` | User taps Close |
| `onToolChanged` | `(EditorTool)` | Tool tab changes |
| `onUndoStateChanged` | `(bool canUndo, bool canRedo)` | After undo/redo |

---

## EditorResult

```dart
class EditorResult {
  final Uint8List bytes;     // The exported image
  final File? file;          // Saved file (if savePath given)
  final int width;           // Pixel width
  final int height;          // Pixel height
  final ExportFormat format; // png or jpeg
}
```

---

## License

MIT — see [LICENSE](LICENSE)

---

## Contributing

PRs and issues are welcome!  
If you find this package useful, please give it a ⭐ on [pub.dev](https://pub.dev/packages/flutter_image_editor_pro) and [GitHub](https://github.com/yourusername/flutter_image_editor_pro).
