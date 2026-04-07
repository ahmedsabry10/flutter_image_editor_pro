import 'package:flutter/material.dart';

/// Visual theme for the image editor UI.
class EditorTheme {
  final Color backgroundColor;
  final Color toolbarColor;
  final Color activeToolColor;
  final Color inactiveToolColor;
  final Color iconColor;
  final Color activeIconColor;
  final Color textColor;
  final Color sliderActiveColor;
  final Color sliderInactiveColor;
  final Color exportButtonColor;
  final Color exportButtonTextColor;
  final double toolbarHeight;
  final double bottomBarHeight;
  final BorderRadius filterPreviewRadius;

  const EditorTheme({
    required this.backgroundColor,
    required this.toolbarColor,
    required this.activeToolColor,
    required this.inactiveToolColor,
    required this.iconColor,
    required this.activeIconColor,
    required this.textColor,
    required this.sliderActiveColor,
    required this.sliderInactiveColor,
    required this.exportButtonColor,
    required this.exportButtonTextColor,
    this.toolbarHeight = 56,
    this.bottomBarHeight = 80,
    this.filterPreviewRadius = const BorderRadius.all(Radius.circular(8)),
  });

  /// Dark theme (default — recommended for photo editors).
  factory EditorTheme.dark() => const EditorTheme(
        backgroundColor: Color(0xFF1A1A1A),
        toolbarColor: Color(0xFF222222),
        activeToolColor: Color(0xFF4FC3F7),
        inactiveToolColor: Color(0xFF555555),
        iconColor: Color(0xFFAAAAAA),
        activeIconColor: Color(0xFF4FC3F7),
        textColor: Color(0xFFFFFFFF),
        sliderActiveColor: Color(0xFF4FC3F7),
        sliderInactiveColor: Color(0xFF444444),
        exportButtonColor: Color(0xFF4FC3F7),
        exportButtonTextColor: Color(0xFF000000),
      );

  /// Light theme.
  factory EditorTheme.light() => const EditorTheme(
        backgroundColor: Color(0xFFF5F5F5),
        toolbarColor: Color(0xFFFFFFFF),
        activeToolColor: Color(0xFF0288D1),
        inactiveToolColor: Color(0xFFCCCCCC),
        iconColor: Color(0xFF555555),
        activeIconColor: Color(0xFF0288D1),
        textColor: Color(0xFF1A1A1A),
        sliderActiveColor: Color(0xFF0288D1),
        sliderInactiveColor: Color(0xFFCCCCCC),
        exportButtonColor: Color(0xFF0288D1),
        exportButtonTextColor: Color(0xFFFFFFFF),
      );

  EditorTheme copyWith({
    Color? backgroundColor,
    Color? toolbarColor,
    Color? activeToolColor,
    Color? inactiveToolColor,
    Color? iconColor,
    Color? activeIconColor,
    Color? textColor,
    Color? sliderActiveColor,
    Color? sliderInactiveColor,
    Color? exportButtonColor,
    Color? exportButtonTextColor,
    double? toolbarHeight,
    double? bottomBarHeight,
  }) {
    return EditorTheme(
      backgroundColor: backgroundColor ?? this.backgroundColor,
      toolbarColor: toolbarColor ?? this.toolbarColor,
      activeToolColor: activeToolColor ?? this.activeToolColor,
      inactiveToolColor: inactiveToolColor ?? this.inactiveToolColor,
      iconColor: iconColor ?? this.iconColor,
      activeIconColor: activeIconColor ?? this.activeIconColor,
      textColor: textColor ?? this.textColor,
      sliderActiveColor: sliderActiveColor ?? this.sliderActiveColor,
      sliderInactiveColor: sliderInactiveColor ?? this.sliderInactiveColor,
      exportButtonColor: exportButtonColor ?? this.exportButtonColor,
      exportButtonTextColor:
          exportButtonTextColor ?? this.exportButtonTextColor,
      toolbarHeight: toolbarHeight ?? this.toolbarHeight,
      bottomBarHeight: bottomBarHeight ?? this.bottomBarHeight,
    );
  }
}
