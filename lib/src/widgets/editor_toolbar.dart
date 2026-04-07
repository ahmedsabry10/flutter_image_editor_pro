import 'package:flutter/material.dart';
import '../controllers/editor_controller.dart';
import '../models/editor_config.dart';
import '../models/editor_theme.dart';

class EditorToolbar extends StatelessWidget {
  final EditorController controller;
  final EditorConfig config;
  final EditorTheme theme;
  final VoidCallback onExport;
  final VoidCallback onClose;

  const EditorToolbar({
    super.key,
    required this.controller,
    required this.config,
    required this.theme,
    required this.onExport,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: theme.toolbarHeight,
      color: theme.toolbarColor,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          // Close
          IconButton(
            icon: Icon(Icons.close, color: theme.iconColor),
            onPressed: onClose,
          ),
          const Spacer(),
          // Undo
          AnimatedBuilder(
            animation: controller,
            builder: (_, __) => IconButton(
              icon: Icon(Icons.undo,
                  color: controller.canUndo
                      ? theme.iconColor
                      : theme.inactiveToolColor),
              onPressed: controller.canUndo ? controller.undo : null,
            ),
          ),
          // Redo
          AnimatedBuilder(
            animation: controller,
            builder: (_, __) => IconButton(
              icon: Icon(Icons.redo,
                  color: controller.canRedo
                      ? theme.iconColor
                      : theme.inactiveToolColor),
              onPressed: controller.canRedo ? controller.redo : null,
            ),
          ),
          // Export
          GestureDetector(
            onTap: onExport,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: theme.exportButtonColor,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Save',
                style: TextStyle(
                  color: theme.exportButtonTextColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bottom tool navigation bar.
class EditorBottomBar extends StatelessWidget {
  final EditorController controller;
  final EditorConfig config;
  final EditorTheme theme;

  const EditorBottomBar({
    super.key,
    required this.controller,
    required this.config,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final tools = _buildTools();
    return Container(
      height: theme.bottomBarHeight,
      color: theme.toolbarColor,
      child: AnimatedBuilder(
        animation: controller,
        builder: (_, __) => Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: tools
              .map((t) => _ToolItem(
                    icon: t.icon,
                    label: t.label,
                    isActive: controller.activeTool == t.tool,
                    theme: theme,
                    onTap: () => controller.setTool(t.tool),
                  ))
              .toList(),
        ),
      ),
    );
  }

  List<_ToolDef> _buildTools() {
    return [
      if (config.enableCrop)
        _ToolDef(EditorTool.crop, Icons.crop, 'Crop'),
      if (config.enableFilters)
        _ToolDef(EditorTool.filters, Icons.auto_fix_high, 'Filters'),
      if (config.enableAdjust)
        _ToolDef(EditorTool.adjust, Icons.tune, 'Adjust'),
      if (config.enableDrawing)
        _ToolDef(EditorTool.drawing, Icons.brush, 'Draw'),
      if (config.enableText)
        _ToolDef(EditorTool.text, Icons.text_fields, 'Text'),
      if (config.enableStickers)
        _ToolDef(EditorTool.stickers, Icons.emoji_emotions_outlined, 'Stickers'),
    ];
  }
}

class _ToolDef {
  final EditorTool tool;
  final IconData icon;
  final String label;
  _ToolDef(this.tool, this.icon, this.label);
}

class _ToolItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final EditorTheme theme;
  final VoidCallback onTap;

  const _ToolItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.theme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon,
              color: isActive ? theme.activeIconColor : theme.iconColor,
              size: 24),
          const SizedBox(height: 4),
          Text(label,
              style: TextStyle(
                color: isActive ? theme.activeToolColor : theme.iconColor,
                fontSize: 10,
                fontWeight:
                    isActive ? FontWeight.w600 : FontWeight.normal,
              )),
        ],
      ),
    );
  }
}
