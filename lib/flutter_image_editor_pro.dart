import 'package:flutter/material.dart';
import 'src/controllers/editor_controller.dart';
import 'src/models/editor_config.dart';
import 'src/models/editor_theme.dart';
import 'src/models/export_options.dart';
import 'src/widgets/image_editor.dart';

export 'src/controllers/editor_controller.dart'
    show EditorController, EditorTool, AdjustValues, DrawingStroke, TextLayer;
export 'src/filters/filter_preset.dart' show FilterPreset;
export 'src/models/editor_config.dart' show EditorConfig, CropAspectRatio;
export 'src/models/editor_theme.dart' show EditorTheme;
export 'src/models/export_options.dart' show ExportOptions, ExportFormat, EditorResult;
export 'src/models/sticker_pack.dart' show StickerPack, StickerLayer;
export 'src/widgets/image_editor.dart' show ImageEditorWidget;

/// Static helper to open the image editor as a full-screen route.
///
/// ```dart
/// final result = await ImageEditorPro.open(
///   context: context,
///   image: myFile,
/// );
/// if (result != null) {
///   // use result.bytes
/// }
/// ```
class ImageEditorPro {
  ImageEditorPro._();

  /// Push the editor as a full-screen page.
  /// Returns [EditorResult] on save, or null if the user closed without saving.
  static Future<EditorResult?> open({
    required BuildContext context,
    required dynamic image,
    EditorConfig config = const EditorConfig(),
    EditorTheme? theme,
    EditorController? controller,
  }) async {
    EditorResult? result;

    await Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => Scaffold(
          body: SafeArea(
            child: ImageEditorWidget(
              image: image,
              config: config,
              theme: theme,
              controller: controller,
              onExport: (r) {
                result = r;
                Navigator.of(context).pop();
              },
              onClose: () => Navigator.of(context).pop(),
            ),
          ),
        ),
      ),
    );

    return result;
  }
}
