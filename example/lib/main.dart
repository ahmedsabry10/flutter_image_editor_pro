import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_image_editor_pro/flutter_image_editor_pro.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ImageEditorPro Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: const DemoPage(),
    );
  }
}

class DemoPage extends StatefulWidget {
  const DemoPage({super.key});

  @override
  State<DemoPage> createState() => _DemoPageState();
}

class _DemoPageState extends State<DemoPage> {
  Uint8List? _resultBytes;
  bool _useEmbedded = false;

  // ── Sticker packs ─────────────────────────────────────────────────────────
  final List<StickerPack> _stickerPacks = [
    StickerPack(
      name: 'Emoji',
      icon: Icons.emoji_emotions,
      stickers: ['😀', '😂', '❤️', '🔥', '⭐', '🎉', '👍', '🙌', '😎', '🥳']
          .map((e) => Text(e, style: const TextStyle(fontSize: 40)))
          .toList(),
    ),
    StickerPack(
      name: 'Shapes',
      icon: Icons.category,
      stickers: [
        _colorBox(Colors.red),
        _colorBox(Colors.blue),
        _colorBox(Colors.green),
        _colorBox(Colors.yellow),
        _star(Colors.orange),
        _star(Colors.purple),
      ],
    ),
  ];

  static Widget _colorBox(Color c) => Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(8)),
      );

  static Widget _star(Color c) => Icon(Icons.star, color: c, size: 50);

  // ── Open as full-screen page ──────────────────────────────────────────────
  Future<void> _openFullScreen() async {
    // In a real app: pick an image from gallery.
    // Here we load a demo image from network as bytes.
    final bytes = await _loadDemoImage();
    if (!mounted) return;

    final result = await ImageEditorPro.open(
      context: context,
      image: bytes,
      config: EditorConfig(
        stickerPacks: _stickerPacks,
        exportOptions: const ExportOptions(
          format: ExportFormat.jpeg,
          jpegQuality: 0.92,
        ),
      ),
      theme: EditorTheme.dark(),
    );

    if (result != null) {
      setState(() => _resultBytes = result.bytes);
      _showSnack('Saved! ${result.width}×${result.height}px');
    }
  }

  // ── Embedded widget demo ──────────────────────────────────────────────────
  Future<void> _toggleEmbedded() async {
    final bytes = await _loadDemoImage();
    if (!mounted) return;
    // We store bytes so the embedded widget can use them
    setState(() {
      _resultBytes = bytes;
      _useEmbedded = true;
    });
  }

  Future<Uint8List> _loadDemoImage() async {
    // Load bundled asset (add assets/demo.jpg to your pubspec for real usage)
    // Fallback: generate a simple gradient image in memory
    try {
      return (await rootBundle.load('assets/demo.jpg')).buffer.asUint8List();
    } catch (_) {
      return _generatePlaceholderImage();
    }
  }

  Uint8List _generatePlaceholderImage() {
    // 200×200 solid teal PNG placeholder (minimal valid PNG)
    // In a real example, load from assets or image_picker
    return Uint8List.fromList([
      0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, // PNG signature
    ]);
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    if (_useEmbedded && _resultBytes != null) {
      return Scaffold(
        body: SafeArea(
          child: ImageEditorWidget(
            image: _resultBytes!,
            config: EditorConfig(stickerPacks: _stickerPacks),
            theme: EditorTheme.dark(),
            onExport: (result) {
              setState(() {
                _resultBytes = result.bytes;
                _useEmbedded = false;
              });
              _showSnack('Saved! ${result.width}×${result.height}px');
            },
            onClose: () => setState(() => _useEmbedded = false),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF222222),
        title: const Text('ImageEditorPro Demo',
            style: TextStyle(color: Colors.white)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Result preview
            if (_resultBytes != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.memory(_resultBytes!, height: 280, fit: BoxFit.cover),
              ),
              const SizedBox(height: 12),
              Text(
                'Last exported image',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
              ),
              const SizedBox(height: 24),
            ] else ...[
              Container(
                height: 200,
                decoration: BoxDecoration(
                  color: const Color(0xFF2A2A2A),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white12),
                ),
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.image_outlined, color: Colors.white24, size: 48),
                      SizedBox(height: 8),
                      Text('No image yet',
                          style: TextStyle(color: Colors.white38)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Open full-screen button
            _ActionButton(
              icon: Icons.fullscreen,
              label: 'Open as Full-Screen Editor',
              subtitle: 'ImageEditorPro.open()',
              color: const Color(0xFF4FC3F7),
              onTap: _openFullScreen,
            ),
            const SizedBox(height: 12),

            // Embedded widget button
            _ActionButton(
              icon: Icons.view_compact,
              label: 'Embed as Widget',
              subtitle: 'ImageEditorWidget(...)',
              color: const Color(0xFF81C784),
              onTap: _toggleEmbedded,
            ),

            const SizedBox(height: 32),
            const _FeatureChips(),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                  color: color.withOpacity(0.15), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 15)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 12,
                          fontFamily: 'monospace')),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: color, size: 14),
          ],
        ),
      ),
    );
  }
}

class _FeatureChips extends StatelessWidget {
  const _FeatureChips();

  @override
  Widget build(BuildContext context) {
    const features = [
      '✂ Crop & Rotate',
      '◑ 20+ Filters',
      '⬡ Adjust',
      '✎ Drawing',
      'T Text Overlay',
      '★ Stickers',
      '↩ Undo/Redo',
      '⤓ PNG & JPEG Export',
      '🌐 Pure Flutter',
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: features
          .map((f) => Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white12),
                ),
                child: Text(f,
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 12)),
              ))
          .toList(),
    );
  }
}
