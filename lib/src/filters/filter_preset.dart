/// A color-matrix based image filter preset.
class FilterPreset {
  final String name;

  /// 4×5 color matrix applied via ColorFilter.matrix().
  final List<double> matrix;

  const FilterPreset({required this.name, required this.matrix});

  // ─────────────────────────────────────────────────────────────────────────
  // BASIC
  // ─────────────────────────────────────────────────────────────────────────

  static const normal = FilterPreset(
    name: 'Normal',
    matrix: [1,0,0,0,0, 0,1,0,0,0, 0,0,1,0,0, 0,0,0,1,0],
  );

  // ─────────────────────────────────────────────────────────────────────────
  // VINTAGE / FILM
  // ─────────────────────────────────────────────────────────────────────────

  static const vintage = FilterPreset(
    name: 'Vintage',
    matrix: [0.9,0.1,0.0,0,0, 0.2,0.8,0.0,0,0, 0.1,0.1,0.7,0,0, 0,0,0,1,0],
  );

  static const fade = FilterPreset(
    name: 'Fade',
    matrix: [1,0,0,0,30, 0,1,0,0,30, 0,0,1,0,30, 0,0,0,1,0],
  );

  static const sepia = FilterPreset(
    name: 'Sepia',
    matrix: [0.393,0.769,0.189,0,0, 0.349,0.686,0.168,0,0, 0.272,0.534,0.131,0,0, 0,0,0,1,0],
  );

  static const kodak = FilterPreset(
    name: 'Kodak',
    matrix: [1.1,0.05,0.0,0,5, 0.0,1.0,0.05,0,2, 0.0,0.0,0.9,0,0, 0,0,0,1,0],
  );

  static const fuji = FilterPreset(
    name: 'Fuji',
    matrix: [0.95,0.05,0.0,0,0, 0.0,1.05,0.05,0,5, 0.0,0.05,1.0,0,0, 0,0,0,1,0],
  );

  static const lomo = FilterPreset(
    name: 'Lomo',
    matrix: [1.3,0.0,0.0,0,-15, 0.0,1.1,0.0,0,-10, 0.0,0.0,1.1,0,-10, 0,0,0,1,0],
  );

  static const polaroid = FilterPreset(
    name: 'Polaroid',
    matrix: [1.15,0.05,0.0,0,10, 0.0,1.05,0.05,0,5, 0.0,0.0,0.85,0,15, 0,0,0,1,0],
  );

  static const film = FilterPreset(
    name: 'Film',
    matrix: [0.85,0.10,0.05,0,15, 0.05,0.85,0.10,0,10, 0.05,0.05,0.90,0,5, 0,0,0,1,0],
  );

  // ─────────────────────────────────────────────────────────────────────────
  // MONO / B&W
  // ─────────────────────────────────────────────────────────────────────────

  static const bw = FilterPreset(
    name: 'B&W',
    matrix: [0.33,0.33,0.33,0,0, 0.33,0.33,0.33,0,0, 0.33,0.33,0.33,0,0, 0,0,0,1,0],
  );

  static const noir = FilterPreset(
    name: 'Noir',
    matrix: [0.33,0.33,0.33,0,-10, 0.33,0.33,0.33,0,-10, 0.33,0.33,0.33,0,-10, 0,0,0,1,0],
  );

  static const silver = FilterPreset(
    name: 'Silver',
    matrix: [0.40,0.40,0.20,0,5, 0.35,0.35,0.30,0,5, 0.25,0.25,0.50,0,5, 0,0,0,1,0],
  );

  static const contrast_bw = FilterPreset(
    name: 'High B&W',
    matrix: [0.5,0.5,0.0,0,-20, 0.4,0.4,0.2,0,-20, 0.2,0.2,0.6,0,-20, 0,0,0,1,0],
  );

  static const dramatic = FilterPreset(
    name: 'Dramatic',
    matrix: [1.5,-0.3,0.0,0,-20, 0.0,1.2,0.0,0,-20, 0.0,0.0,1.5,0,-20, 0,0,0,1,0],
  );

  // ─────────────────────────────────────────────────────────────────────────
  // COLOR GRADING
  // ─────────────────────────────────────────────────────────────────────────

  static const cool = FilterPreset(
    name: 'Cool',
    matrix: [0.8,0.0,0.2,0,0, 0.0,0.9,0.1,0,0, 0.0,0.0,1.2,0,0, 0,0,0,1,0],
  );

  static const warm = FilterPreset(
    name: 'Warm',
    matrix: [1.2,0.0,0.0,0,0, 0.0,1.0,0.0,0,0, 0.0,0.0,0.8,0,0, 0,0,0,1,0],
  );

  static const vivid = FilterPreset(
    name: 'Vivid',
    matrix: [1.4,-0.2,0.0,0,0, 0.0,1.3,0.0,0,0, 0.0,0.0,1.4,0,0, 0,0,0,1,0],
  );

  static const chrome = FilterPreset(
    name: 'Chrome',
    matrix: [1.0,0.0,0.0,0,10, 0.0,1.0,0.0,0,10, 0.0,0.0,1.0,0,10, 0,0,0,1,0],
  );

  static const clarendon = FilterPreset(
    name: 'Clarendon',
    matrix: [1.2,0.0,0.0,0,0, 0.0,1.2,0.0,0,0, 0.0,0.0,1.4,0,0, 0,0,0,1,0],
  );

  static const matte = FilterPreset(
    name: 'Matte',
    matrix: [0.9,0.0,0.0,0,20, 0.0,0.9,0.0,0,15, 0.0,0.0,0.9,0,20, 0,0,0,1,0],
  );

  static const bloom = FilterPreset(
    name: 'Bloom',
    matrix: [1.1,0.1,0.1,0,10, 0.1,1.1,0.1,0,10, 0.1,0.1,1.1,0,10, 0,0,0,1,0],
  );

  static const lush = FilterPreset(
    name: 'Lush',
    matrix: [0.8,0.1,0.0,0,0, 0.0,1.3,0.0,0,0, 0.0,0.1,0.8,0,0, 0,0,0,1,0],
  );

  static const golden = FilterPreset(
    name: 'Golden',
    matrix: [1.3,0.1,0.0,0,0, 0.1,1.1,0.0,0,0, 0.0,0.0,0.6,0,0, 0,0,0,1,0],
  );

  static const bronze = FilterPreset(
    name: 'Bronze',
    matrix: [1.2,0.1,0.0,0,5, 0.1,1.0,0.0,0,0, 0.0,0.0,0.7,0,0, 0,0,0,1,0],
  );

  // ─────────────────────────────────────────────────────────────────────────
  // NATURE / LANDSCAPE
  // ─────────────────────────────────────────────────────────────────────────

  static const forest = FilterPreset(
    name: 'Forest',
    matrix: [0.7,0.1,0.0,0,0, 0.1,1.1,0.1,0,0, 0.0,0.1,0.7,0,0, 0,0,0,1,0],
  );

  static const ocean = FilterPreset(
    name: 'Ocean',
    matrix: [0.6,0.0,0.2,0,0, 0.0,0.8,0.2,0,0, 0.0,0.1,1.3,0,0, 0,0,0,1,0],
  );

  static const sunset = FilterPreset(
    name: 'Sunset',
    matrix: [1.3,0.0,0.0,0,0, 0.0,0.9,0.0,0,0, 0.0,0.0,0.5,0,0, 0,0,0,1,0],
  );

  static const desert = FilterPreset(
    name: 'Desert',
    matrix: [1.2,0.1,0.0,0,10, 0.1,1.0,0.0,0,5, 0.0,0.0,0.6,0,0, 0,0,0,1,0],
  );

  static const arctic = FilterPreset(
    name: 'Arctic',
    matrix: [0.8,0.1,0.1,0,10, 0.05,0.9,0.05,0,10, 0.1,0.1,1.1,0,20, 0,0,0,1,0],
  );

  static const jungle = FilterPreset(
    name: 'Jungle',
    matrix: [0.6,0.15,0.0,0,-5, 0.05,1.2,0.05,0,0, 0.0,0.1,0.6,0,-5, 0,0,0,1,0],
  );

  static const tropical = FilterPreset(
    name: 'Tropical',
    matrix: [1.1,0.0,0.1,0,5, 0.0,1.2,0.1,0,5, 0.0,0.0,0.9,0,0, 0,0,0,1,0],
  );

  static const autumn = FilterPreset(
    name: 'Autumn',
    matrix: [1.2,0.1,0.0,0,0, 0.1,0.9,0.0,0,0, 0.0,0.0,0.5,0,0, 0,0,0,1,0],
  );

  static const spring = FilterPreset(
    name: 'Spring',
    matrix: [0.9,0.05,0.05,0,10, 0.0,1.1,0.05,0,10, 0.05,0.0,0.9,0,10, 0,0,0,1,0],
  );

  // ─────────────────────────────────────────────────────────────────────────
  // CINEMATIC / MOOD
  // ─────────────────────────────────────────────────────────────────────────

  static const cinematic = FilterPreset(
    name: 'Cinematic',
    matrix: [1.1,-0.1,0.0,0,-5, 0.0,1.0,0.0,0,-5, 0.1,0.0,0.8,0,10, 0,0,0,1,0],
  );

  static const teal_orange = FilterPreset(
    name: 'Teal & Orange',
    matrix: [1.3,0.0,-0.1,0,0, -0.1,1.0,0.1,0,0, -0.1,0.0,1.2,0,0, 0,0,0,1,0],
  );

  static const cyberpunk = FilterPreset(
    name: 'Cyberpunk',
    matrix: [1.4,-0.2,0.2,0,0, -0.1,1.0,0.2,0,0, 0.2,-0.1,1.4,0,0, 0,0,0,1,0],
  );

  static const neon = FilterPreset(
    name: 'Neon',
    matrix: [1.5,0.0,0.3,0,0, 0.0,1.3,0.3,0,0, 0.3,0.0,1.5,0,0, 0,0,0,1,0],
  );

  static const horror = FilterPreset(
    name: 'Horror',
    matrix: [1.2,0.0,0.0,0,-20, 0.0,0.7,0.0,0,-20, 0.0,0.0,0.7,0,-20, 0,0,0,1,0],
  );

  static const dreamy = FilterPreset(
    name: 'Dreamy',
    matrix: [0.9,0.1,0.1,0,20, 0.05,0.9,0.1,0,15, 0.1,0.1,1.0,0,20, 0,0,0,1,0],
  );

  static const retro = FilterPreset(
    name: 'Retro',
    matrix: [1.0,0.1,0.0,0,10, 0.1,0.9,0.0,0,5, 0.0,0.0,0.7,0,10, 0,0,0,1,0],
  );

  static const faded_film = FilterPreset(
    name: 'Faded Film',
    matrix: [0.85,0.05,0.05,0,25, 0.05,0.85,0.05,0,20, 0.05,0.05,0.85,0,25, 0,0,0,1,0],
  );

  static const cross_process = FilterPreset(
    name: 'Cross Process',
    matrix: [1.3,-0.1,0.0,0,0, 0.1,1.0,-0.1,0,0, -0.1,0.1,1.3,0,0, 0,0,0,1,0],
  );

  static const duotone_blue = FilterPreset(
    name: 'Duotone Blue',
    matrix: [0.3,0.3,0.3,0,0, 0.2,0.2,0.2,0,20, 0.4,0.4,0.4,0,80, 0,0,0,1,0],
  );

  static const duotone_purple = FilterPreset(
    name: 'Duotone Purple',
    matrix: [0.4,0.2,0.4,0,30, 0.1,0.2,0.1,0,0, 0.4,0.2,0.4,0,60, 0,0,0,1,0],
  );

  static const duotone_rose = FilterPreset(
    name: 'Duotone Rose',
    matrix: [0.5,0.2,0.2,0,50, 0.1,0.2,0.1,0,10, 0.2,0.1,0.3,0,20, 0,0,0,1,0],
  );

  // ─────────────────────────────────────────────────────────────────────────
  // PORTRAIT
  // ─────────────────────────────────────────────────────────────────────────

  static const beauty = FilterPreset(
    name: 'Beauty',
    matrix: [1.0,0.05,0.05,0,10, 0.05,1.0,0.05,0,8, 0.05,0.05,1.0,0,10, 0,0,0,1,0],
  );

  static const skin_glow = FilterPreset(
    name: 'Skin Glow',
    matrix: [1.1,0.1,0.0,0,15, 0.05,1.05,0.0,0,10, 0.0,0.0,0.9,0,5, 0,0,0,1,0],
  );

  static const portrait = FilterPreset(
    name: 'Portrait',
    matrix: [1.05,0.05,0.0,0,5, 0.0,1.05,0.0,0,5, 0.0,0.0,1.0,0,5, 0,0,0,1,0],
  );

  // ─────────────────────────────────────────────────────────────────────────
  // FOOD / PRODUCT
  // ─────────────────────────────────────────────────────────────────────────

  static const food = FilterPreset(
    name: 'Food',
    matrix: [1.1,0.0,0.0,0,5, 0.0,1.1,0.05,0,5, 0.0,0.0,0.85,0,0, 0,0,0,1,0],
  );

  static const fresh = FilterPreset(
    name: 'Fresh',
    matrix: [0.9,0.05,0.05,0,15, 0.0,1.1,0.05,0,10, 0.05,0.05,1.0,0,15, 0,0,0,1,0],
  );

  /// All built-in filters grouped into categories.
  static const builtIn = [
    // Basic
    normal, fade, matte, chrome, bloom,
    // B&W
    bw, noir, silver, dramatic,
    // Vintage / Film
    vintage, sepia, kodak, fuji, lomo, polaroid, film, retro, faded_film,
    // Color Grading
    cool, warm, vivid, clarendon, lush, golden, bronze, cross_process,
    // Nature
    forest, ocean, sunset, desert, arctic, jungle, tropical, autumn, spring,
    // Cinematic / Mood
    cinematic, teal_orange, cyberpunk, neon, horror, dreamy,
    // Duotone
    duotone_blue, duotone_purple, duotone_rose,
    // Portrait / Food
    beauty, skin_glow, portrait, food, fresh,
  ];
}
