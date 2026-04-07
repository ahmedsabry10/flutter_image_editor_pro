/// A color-matrix based image filter preset.
class FilterPreset {
  final String name;

  /// 4×5 color matrix applied via ColorFilter.matrix().
  /// Rows: R, G, B, A. Columns: R, G, B, A, offset.
  final List<double> matrix;

  const FilterPreset({required this.name, required this.matrix});

  /// Identity — no change.
  static const normal = FilterPreset(
    name: 'Normal',
    matrix: [
      1, 0, 0, 0, 0, //
      0, 1, 0, 0, 0, //
      0, 0, 1, 0, 0, //
      0, 0, 0, 1, 0, //
    ],
  );

  static const vintage = FilterPreset(
    name: 'Vintage',
    matrix: [
      0.9, 0.1, 0.0, 0, 0, //
      0.2, 0.8, 0.0, 0, 0, //
      0.1, 0.1, 0.7, 0, 0, //
      0.0, 0.0, 0.0, 1, 0, //
    ],
  );

  static const fade = FilterPreset(
    name: 'Fade',
    matrix: [
      1, 0, 0, 0, 30, //
      0, 1, 0, 0, 30, //
      0, 0, 1, 0, 30, //
      0, 0, 0, 1, 0, //
    ],
  );

  static const cool = FilterPreset(
    name: 'Cool',
    matrix: [
      0.8, 0.0, 0.2, 0, 0, //
      0.0, 0.9, 0.1, 0, 0, //
      0.0, 0.0, 1.2, 0, 0, //
      0.0, 0.0, 0.0, 1, 0, //
    ],
  );

  static const warm = FilterPreset(
    name: 'Warm',
    matrix: [
      1.2, 0.0, 0.0, 0, 0, //
      0.0, 1.0, 0.0, 0, 0, //
      0.0, 0.0, 0.8, 0, 0, //
      0.0, 0.0, 0.0, 1, 0, //
    ],
  );

  static const vivid = FilterPreset(
    name: 'Vivid',
    matrix: [
      1.4, -0.2, 0.0, 0, 0, //
      0.0, 1.30, 0.0, 0, 0, //
      0.0, 0.00, 1.4, 0, 0, //
      0.0, 0.00, 0.0, 1, 0, //
    ],
  );

  static const chrome = FilterPreset(
    name: 'Chrome',
    matrix: [
      1.0, 0.0, 0.0, 0, 10, //
      0.0, 1.0, 0.0, 0, 10, //
      0.0, 0.0, 1.0, 0, 10, //
      0.0, 0.0, 0.0, 1, 0, //
    ],
  );

  static const forest = FilterPreset(
    name: 'Forest',
    matrix: [
      0.7, 0.1, 0.0, 0, 0, //
      0.1, 1.1, 0.1, 0, 0, //
      0.0, 0.1, 0.7, 0, 0, //
      0.0, 0.0, 0.0, 1, 0, //
    ],
  );

  static const ocean = FilterPreset(
    name: 'Ocean',
    matrix: [
      0.6, 0.0, 0.2, 0, 0, //
      0.0, 0.8, 0.2, 0, 0, //
      0.0, 0.1, 1.3, 0, 0, //
      0.0, 0.0, 0.0, 1, 0, //
    ],
  );

  static const golden = FilterPreset(
    name: 'Golden',
    matrix: [
      1.3, 0.1, 0.0, 0, 0, //
      0.1, 1.1, 0.0, 0, 0, //
      0.0, 0.0, 0.6, 0, 0, //
      0.0, 0.0, 0.0, 1, 0, //
    ],
  );

  static const sepia = FilterPreset(
    name: 'Sepia',
    matrix: [
      0.393, 0.769, 0.189, 0, 0, //
      0.349, 0.686, 0.168, 0, 0, //
      0.272, 0.534, 0.131, 0, 0, //
      0.000, 0.000, 0.000, 1, 0, //
    ],
  );

  static const sunset = FilterPreset(
    name: 'Sunset',
    matrix: [
      1.3, 0.0, 0.0, 0, 0, //
      0.0, 0.9, 0.0, 0, 0, //
      0.0, 0.0, 0.5, 0, 0, //
      0.0, 0.0, 0.0, 1, 0, //
    ],
  );

  static const noir = FilterPreset(
    name: 'Noir',
    matrix: [
      0.33, 0.33, 0.33, 0, -10, //
      0.33, 0.33, 0.33, 0, -10, //
      0.33, 0.33, 0.33, 0, -10, //
      0.00, 0.00, 0.00, 1, 0, //
    ],
  );

  static const dramatic = FilterPreset(
    name: 'Dramatic',
    matrix: [
      1.5, -0.3, 0.0, 0, -20, //
      0.0, 1.20, 0.0, 0, -20, //
      0.0, 0.00, 1.5, 0, -20, //
      0.0, 0.00, 0.0, 1, 0, //
    ],
  );

  static const matte = FilterPreset(
    name: 'Matte',
    matrix: [
      0.9, 0.0, 0.0, 0, 20, //
      0.0, 0.9, 0.0, 0, 15, //
      0.0, 0.0, 0.9, 0, 20, //
      0.0, 0.0, 0.0, 1, 0, //
    ],
  );

  static const bloom = FilterPreset(
    name: 'Bloom',
    matrix: [
      1.1, 0.1, 0.1, 0, 10, //
      0.1, 1.1, 0.1, 0, 10, //
      0.1, 0.1, 1.1, 0, 10, //
      0.0, 0.0, 0.0, 1, 0, //
    ],
  );

  static const clarendon = FilterPreset(
    name: 'Clarendon',
    matrix: [
      1.2, 0.0, 0.0, 0, 0, //
      0.0, 1.2, 0.0, 0, 0, //
      0.0, 0.0, 1.4, 0, 0, //
      0.0, 0.0, 0.0, 1, 0, //
    ],
  );

  static const lush = FilterPreset(
    name: 'Lush',
    matrix: [
      0.8, 0.1, 0.0, 0, 0, //
      0.0, 1.3, 0.0, 0, 0, //
      0.0, 0.1, 0.8, 0, 0, //
      0.0, 0.0, 0.0, 1, 0, //
    ],
  );

  static const bronze = FilterPreset(
    name: 'Bronze',
    matrix: [
      1.2, 0.1, 0.0, 0, 5, //
      0.1, 1.0, 0.0, 0, 0, //
      0.0, 0.0, 0.7, 0, 0, //
      0.0, 0.0, 0.0, 1, 0, //
    ],
  );

  static const bw = FilterPreset(
    name: 'B&W',
    matrix: [
      0.33, 0.33, 0.33, 0, 0, //
      0.33, 0.33, 0.33, 0, 0, //
      0.33, 0.33, 0.33, 0, 0, //
      0.00, 0.00, 0.00, 1, 0, //
    ],
  );

  /// All 20 built-in filters in order.
  static const builtIn = [
    normal, vintage, fade, cool, warm,
    vivid, chrome, forest, ocean, golden,
    sepia, sunset, noir, dramatic, matte,
    bloom, clarendon, lush, bronze, bw,
  ];
}
