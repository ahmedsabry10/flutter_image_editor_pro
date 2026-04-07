import 'package:flutter/material.dart';
import '../filters/filter_preset.dart';
import '../models/editor_theme.dart';
import 'dart:ui' as ui;


/// Horizontal strip of filter preview thumbnails.
class FilterPreviewStrip extends StatelessWidget {
  final ui.Image? thumbnail;
  final List<FilterPreset> filters;
  final FilterPreset selected;
  final EditorTheme theme;
  final void Function(FilterPreset) onSelect;

  // ignore: library_prefixes
  const FilterPreviewStrip({
    super.key,
    required this.thumbnail,
    required this.filters,
    required this.selected,
    required this.theme,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 90,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        itemCount: filters.length,
        itemBuilder: (_, i) {
          final f = filters[i];
          final isSelected = f.name == selected.name;
          return GestureDetector(
            onTap: () => onSelect(f),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              width: 64,
              child: Column(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      borderRadius: theme.filterPreviewRadius,
                      border: Border.all(
                        color: isSelected
                            ? theme.activeToolColor
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: theme.filterPreviewRadius,
                      child: ColorFiltered(
                        colorFilter: ColorFilter.matrix(f.matrix),
                        child: thumbnail != null
                            ? RawImage(image: thumbnail, fit: BoxFit.cover)
                            : Container(color: Colors.grey.shade800),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    f.name,
                    style: TextStyle(
                      fontSize: 10,
                      color: isSelected
                          ? theme.activeToolColor
                          : theme.iconColor,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ignore: avoid_web_libraries_in_flutter
