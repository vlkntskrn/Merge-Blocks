import 'dart:async';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const String _prefsKeyV1 = 'merge_blocks_save_v1';

class _GemFlyFx {
  final int id;
  final Offset from;
  final Offset to;
  final int startMs;
  const _GemFlyFx({required this.id, required this.from, required this.to, required this.startMs});
}

class _CoinFlyFx {
  final int id;
  final Offset from;
  final Offset to;
  final int startMs;
  const _CoinFlyFx({required this.id, required this.from, required this.to, required this.startMs});
}


class _LevelUpBurstPainter extends CustomPainter {
  final double t;
  final int seed;

  const _LevelUpBurstPainter({required this.t, required this.seed});

  @override
  void paint(Canvas canvas, Size size) {
    final rng = Random(seed);
    final center = Offset(size.width / 2, size.height / 2);
    final fade = (1.0 - t).clamp(0.0, 1.0);

    final rayPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..color = const Color(0xFF27E6FF).withOpacity(0.32 * fade);

    for (int i = 0; i < 20; i++) {
      final a = (i / 20.0) * pi * 2 + rng.nextDouble() * 0.16;
      final r0 = size.shortestSide * (0.10 + 0.06 * t);
      final r1 = size.shortestSide * (0.44 + 0.20 * t) * (0.9 + rng.nextDouble() * 0.25);
      canvas.drawLine(center + Offset(cos(a), sin(a)) * r0, center + Offset(cos(a), sin(a)) * r1, rayPaint);
    }

    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2
      ..color = const Color(0xFF8A5BFF).withOpacity(0.22 * fade);

    canvas.drawCircle(center, size.shortestSide * (0.31 + 0.09 * t), ringPaint);
    canvas.drawCircle(center, size.shortestSide * (0.20 + 0.07 * t), ringPaint..strokeWidth = 2.1);

    final glow = Paint()
      ..style = PaintingStyle.fill
      ..color = const Color(0xFF27E6FF).withOpacity(0.11 * fade);
    canvas.drawCircle(center, size.shortestSide * (0.24 + 0.06 * t), glow);
  }

  @override
  bool shouldRepaint(covariant _LevelUpBurstPainter oldDelegate) {
    return oldDelegate.t != t || oldDelegate.seed != seed;
  }
}


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  } catch (_) {}
  runApp(const MergeBlocksApp());
}

class MergeBlocksApp extends StatelessWidget {
  const MergeBlocksApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      restorationScopeId: 'app',
      title: 'MERGE BLOCKS NEON CHAIN',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF7C4DFF),
      ),
      home: const UltraGamePage(),
    );
  }
}

// Supported UI languages. (Turkish removed by request.)
enum AppLang { en, de }

class UltraGamePage extends StatefulWidget {
  const UltraGamePage({super.key});

  @override
  State<UltraGamePage> createState() => _UltraGamePageState();
}

class _UltraGamePageState extends State<UltraGamePage> with TickerProviderStateMixin, WidgetsBindingObserver, RestorationMixin {
  // Boot/persistence
  bool _booting = true;
  Timer? _autoSaveTimer;

  // Level-up FX
  late final AnimationController _levelCtrl;
  Timer? _levelTimer;
  String? _levelMsg;

  // HUD targets / fly FX
  final GlobalKey _rootStackKey = GlobalKey();
  final GlobalKey _diamondCounterKey = GlobalKey();
  final GlobalKey _scoreCounterKey = GlobalKey();
  final List<_GemFlyFx> _gemFlyFx = <_GemFlyFx>[];
  int _gemFxId = 1;
  final List<_CoinFlyFx> _coinFlyFx = <_CoinFlyFx>[];
  int _coinFxId = 1;
  bool _launchOfferShown = false;

  // ===== Board config =====
  static const int cols = 5;
  static const int rows = 7;
  static const double kGap = 10.0;
  static const double kBannerHeight = 50.0; // fixed banner height (Phase 1)

  double get uiScale {
    // Scale UI slightly down on small screens; keep board as large as possible.
    final h = MediaQuery.of(context).size.height;
    final s = (h / 820.0).clamp(0.85, 1.0);
    return s.toDouble();
  }


// --- State restoration (DartPad-friendly persistence) ---
final RestorableStringN _saveBlob = RestorableStringN(null);
bool _didRestore = false;

@override
String? get restorationId => 'ultra_game';

@override
void restoreState(RestorationBucket? oldBucket, bool initialRestore) {
  registerForRestoration(_saveBlob, 'save_blob');
  if (_saveBlob.value != null) {
    _loadFromBlob(_saveBlob.value!);
    _didRestore = true;
  }
}

void _saveToBlob() {
  final flat = <String?>[];
  for (int r = 0; r < rows; r++) {
    for (int c = 0; c < cols; c++) {
      final v = grid[r][c];
      flat.add(v == null ? null : v.toString());
    }
  }
  final data = <String, dynamic>{
    'rows': rows,
    'cols': cols,
    'grid': flat,
    'score': score.toString(),
    'best': best.toString(),
    'levelIdx': levelIdx,
    'diamonds': diamonds,
    'swaps': swaps,
    // Store as string for forward/backward compatibility.
    'lang': lang.name,
  };
  _saveBlob.value = jsonEncode(data);

  _saveToPrefs();
}


void _loadFromBlob(String blob) {
  try {
    final Map<String, dynamic> data = jsonDecode(blob) as Map<String, dynamic>;
    final int sr = (data['rows'] as num?)?.toInt() ?? rows;
    final int sc = (data['cols'] as num?)?.toInt() ?? cols;
    final List<dynamic>? flat = data['grid'] as List<dynamic>?;
    if (flat != null && sr == rows && sc == cols && flat.length == rows * cols) {
      grid = List.generate(rows, (_) => List<BigInt?>.filled(cols, null));
      for (int r = 0; r < rows; r++) {
        for (int c = 0; c < cols; c++) {
          final idx = r * cols + c;
          final v = flat[idx];
          grid[r][c] = (v == null) ? null : BigInt.parse(v.toString());
        }
      }
    } else {
      grid = List.generate(rows, (_) => List<BigInt?>.filled(cols, null));
      _initFirstBoard();
    }

    score = BigInt.parse((data['score'] ?? '0').toString());
    best = BigInt.parse((data['best'] ?? '0').toString());
    levelIdx = (data['levelIdx'] as num?)?.toInt() ?? 1;
    diamonds = (data['diamonds'] as num?)?.toInt() ?? 0;
    swaps = (data['swaps'] as num?)?.toInt() ?? 0;

    // Language migration:
    // - New format: string 'en'/'de'
    // - Old format: int index (from previous builds)
    // - If an older save stored 'tr' (removed), fall back to English.
    final rawLang = data['lang'];
    if (rawLang is String) {
      if (rawLang == 'de') {
        lang = AppLang.de;
      } else {
        // includes 'en' and any unknown (incl. legacy 'tr')
        lang = AppLang.en;
      }
    } else {
      final li = (rawLang as num?)?.toInt();
      if (li != null && li >= 0 && li < AppLang.values.length) {
        lang = AppLang.values[li];
      } else {
        lang = AppLang.en;
      }
    }

    _clearPath();
    _recalcBest();
    if (mounted) setState(() {});
  } catch (_) {
    grid = List.generate(rows, (_) => List<BigInt?>.filled(cols, null));
    _initFirstBoard();
    _clearPath();
    _recalcBest();
  }
}

  void _startAutoSave() {
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer.periodic(const Duration(seconds: 4), (_) => _saveToBlob());
  }

  Future<void> _saveToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = _saveBlob.value;
      if (raw == null || raw.isEmpty) return;
      await prefs.setString(_prefsKeyV1, raw);
    } catch (_) {}
  }

  Future<bool> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKeyV1);
      if (raw == null || raw.isEmpty) return false;
      _saveBlob.value = raw;
      _loadFromBlob(raw);
      return true;
    } catch (_) {
      return false;
    }
  }



Random _rng = Random();

  late List<List<BigInt?>> grid;

  int levelIdx = 1; // Level 1 starts
  BigInt score = BigInt.zero;
  BigInt best = BigInt.zero;
  int diamonds = 0; // starts with 0 diamonds
  int swaps = 0; // rewarded swap credits

  bool swapMode = false;
  bool hammerMode = false;
  bool duplicateMode = false;
  Pos? _swapFirst;

  final List<Pos> _path = [];
  final List<Color> _pathColors = <Color>[]; // per-segment chain line colors
  bool _dragging = false;
  Offset? _lastPanLocal; // for drag sampling across cells

  // Tick used to force rebuild keys for spawn animations.
  int _spawnTick = 0;


  BigInt? _lastValue; // last value in current selection
  final Map<Pos, int> _fallSteps = <Pos, int>{};
  final List<_VanishFx> _vanishFx = <_VanishFx>[];
  // Last combo count (merges in a single move).
  int _lastCombo = 0;

  // Chain selection state (rebuilt)
  BigInt? _baseValue;
  int _baseCount = 0;
  bool _armed = false;
  BigInt? _stageValue;
  int _stageCount = 0;

  String? _toast;
  Timer? _toastTimer;
  late final AnimationController _toastCtrl;
  late final Animation<double> _toastOpacity;
  late final Animation<double> _toastScale;
  late final AnimationController _comboCtrl;
  late final AnimationController _shakeCtrl;
  late final AnimationController _shimmerCtrl;

  AppLang lang = AppLang.en;

  // ===== Localization =====
  static const Map<String, String> _en = {
    'now': 'NOW',
    'max': 'MAX',
    'next': 'GOAL',
    'swap': 'SWAP',
    'hammer': 'HAMMER',
    'watchAd': 'AD',
    'earnDiamonds': 'EARN +10',
    'duplicate': 'DUP x2',
    'swapBonus': 'SWAP Bonus',
    'swapPlus': '+1 SWAP',
    'noSwaps': 'No swaps left',
    'shop': 'SHOP',
    'pause': 'PAUSE',
    'settings': 'Settings',
    'resume': 'Resume',
    'restart': 'Restart',
    'notEnoughDiamonds': 'Not enough diamonds',
    'broken': 'Broken!',
    'shopTitle': 'Diamond Shop',
    'buy': 'Buy',
  };

  static const Map<String, String> _de = {
    'now': 'JETZT',
    'max': 'MAX',
    'next': 'ZIEL',
    'swap': 'TAUSCH',
    'hammer': 'HAMMER',
    'watchAd': 'WERBUNG',
    'earnDiamonds': '+10',
    'duplicate': 'DUP x2',
    'swapBonus': 'SWAP Bonus',
    'swapPlus': '+1 SWAP',
    'noSwaps': 'Keine Swaps übrig',
    'shop': 'SHOP',
    'pause': 'PAUSE',
    'settings': 'Einstellungen',
    'resume': 'Weiter',
    'restart': 'Neustart',
    'notEnoughDiamonds': 'Nicht genug Diamanten',
    'broken': 'Zerbrochen!',
    'shopTitle': 'Diamant-Shop',
    'buy': 'Kaufen',
  };

  String t(String key) {
    final dict = switch (lang) {
      AppLang.de => _de,
      AppLang.en => _en,
    };
    return dict[key] ?? key;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _toastCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 220));
    _toastOpacity = CurvedAnimation(parent: _toastCtrl, curve: Curves.easeOut, reverseCurve: Curves.easeIn);
    _toastScale = Tween<double>(begin: 0.92, end: 1.0).animate(CurvedAnimation(parent: _toastCtrl, curve: Curves.easeOutBack, reverseCurve: Curves.easeIn));
    _comboCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 520));
    _shakeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 520));
    _shimmerCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));

    _levelCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));

    () async {
      final okPrefs = await _loadFromPrefs();
      if (!okPrefs) {
        final raw = _saveBlob.value;
        if (raw != null && raw.isNotEmpty) {
          _loadFromBlob(raw);
        } else {
          _resetBoard(hard: true);
          _saveToBlob();
        }
      }
      _startAutoSave();
      if (!mounted) return;
      setState(() => _booting = false);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showLaunchOfferIfNeeded();
      });
    }();
  }


  // ===== Game logic =====

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      _saveToBlob();
    }
  }

  @override
  void dispose() {
    _toastTimer?.cancel();
    _autoSaveTimer?.cancel();
    _levelTimer?.cancel();
    _toastCtrl.dispose();
    _comboCtrl.dispose();
    _shakeCtrl.dispose();
    _shimmerCtrl.dispose();
    _levelCtrl.dispose();
    WidgetsBinding.instance.removeObserver(this);
    _saveToBlob();
    super.dispose();
  }

void _resetBoard({required bool hard}) {
    grid = List.generate(rows, (_) => List<BigInt?>.filled(cols, null));
    _initFirstBoard();
    _clearPath();
    if (hard) {
      score = BigInt.zero;
      levelIdx = 1;
      diamonds = 0;
      swaps = 0;
    }
    _recalcBest();
    _saveToBlob();
    setState(() {});
  }

  void _initFirstBoard() {
  for (int r = 0; r < rows; r++) {
    for (int c = 0; c < cols; c++) {
      grid[r][c] = _spawnTile();
    }
  }
}

  BigInt _spawnTile() {
  // Level-based uniform spawn:
  // Level 1: 2-4-8-16-32
  // Level 2: 4-8-16-32-64
  // Level 3: 8-16-32-64-128
  // General: 2^level .. 2^(level+4) (5 values, uniform)
  final start = BigInt.one << levelIdx; // levelIdx=1 => 2
  final pool = List<BigInt>.generate(5, (i) => start << i);
  return pool[_rng.nextInt(pool.length)];
}

  BigInt _goalForLevel(int level) {
    // Level 1 target = 2048, Level 2 = 4096, Level 3 = 8192 ...
    return BigInt.one << (10 + level);
  }

  BigInt _maxOnBoard() {
    BigInt m = BigInt.zero;
    for (final row in grid) {
      for (final v in row) {
        if (v != null && v > m) m = v;
      }
    }
    return m;
  }

  void _recalcBest() {
    final m = _maxOnBoard();
    if (m > best) best = m;
  }

  bool _inBounds(Pos p) => p.r >= 0 && p.r < rows && p.c >= 0 && p.c < cols;

  bool _isNeighbor8(Pos a, Pos b) {
    final dr = (a.r - b.r).abs();
    final dc = (a.c - b.c).abs();
    return (dr <= 1 && dc <= 1) && !(dr == 0 && dc == 0);
  }



  void _clearPath() {
    _path.clear();
    _pathColors.clear();
    _dragging = false;
    _armed = false;
    _baseValue = null;
    _baseCount = 0;
    _stageValue = null;
    _stageCount = 0;
    _lastValue = null;
    _lastPanLocal = null;
  }

  Pos? _hitTestPos(Offset local, double cellSize, double gap) {
    // Robust hit-testing:
    // - Use floor() (not rounding) to prevent "magnet" snapping.
    // - Ignore pointer positions that fall inside the visual gap between cells.
    final span = cellSize + gap;

    final c = (local.dx / span).floor();
    final r = (local.dy / span).floor();
    if (r < 0 || r >= rows || c < 0 || c >= cols) return null;

    final inCellX = local.dx - c * span;
    final inCellY = local.dy - r * span;
    if (inCellX < 0 || inCellX > cellSize) return null;
    if (inCellY < 0 || inCellY > cellSize) return null;

    return Pos(r, c);
  }

BigInt? _valueAt(Pos p) => _inBounds(p) ? grid[p.r][p.c] : null;

Color _chainColorForStep(int step) {
  // Vibrant but not harsh (higher contrast) palette for chain segments.
  const palette = <Color>[
    Color(0xFF2EE6D6), // aqua neon
    Color(0xFF7C5CFF), // violet
    Color(0xFFFFC857), // amber
    Color(0xFF2F9BFF), // blue
    Color(0xFFFF5FA2), // pink
    Color(0xFF7DFF6B), // green
    Color(0xFFFF6B4A), // coral
    Color(0xFFB8FF3D), // lime
  ];
  return palette[step % palette.length].withOpacity(0.78);
}

Color _chainColorForIndex(int idx) => _chainColorForStep(idx);

void _onCellDown(Pos p) {
  if (!_inBounds(p)) return;
  final v = _valueAt(p);
  if (v == null) return;

  // Tool modes take priority
  if (swapMode) {
    _handleSwapTap(p);
    return;
  }
  if (hammerMode) {
    _handleHammerTap(p);
    return;
  }

  // Start a new drag/selection session (needed so _onCellUp can commit merge).
  _dragging = true;

  _path.clear();
  _pathColors.clear();
  _baseValue = v;
  _baseCount = 1;
  _armed = true; // old-version behavior: no base-pair arming needed
  _stageValue = null;
  _stageCount = 0;
  _lastValue = v;

  _path.add(p);
  _pathColors.add(_chainColorForIndex(0));
  setState(() {});
}

void _recalcPathState() {
  if (_path.isEmpty) {
    _baseValue = null;
    _baseCount = 0;
    _armed = false;
    _stageValue = null;
    _stageCount = 0;
    _lastValue = null;
    return;
  }
  _baseValue = _valueAt(_path.first);
  _baseCount = _baseValue == null ? 0 : 1;
  _armed = true; // old-version behavior: no base-pair arming needed
  _stageValue = null;
  _stageCount = 0;
  _lastValue = _valueAt(_path.last);
}


void _onCellEnter(Pos p) {
  if (_path.isEmpty) return;
  if (!_inBounds(p)) return;

  // Undo path: allow going back one step by hovering the previous cell.
  if (_path.length >= 2 && p == _path[_path.length - 2]) {
    _path.removeLast();
    if (_pathColors.isNotEmpty) _pathColors.removeLast();
    _recalcPathState();
    setState(() {});
    return;
  }

  if (_path.contains(p)) return;

  final last = _path.last;
  if (!_isNeighbor8(last, p)) return;

  final v = _valueAt(p);
  if (v == null) return;

  // Old-version rule:
  // Next pick must be same or double of the previous pick (no base-pair arming).
  final lv = _lastValue ?? _valueAt(last);
  if (lv == null) return;

  if (v == lv || v == (lv << 1)) {
    _path.add(p);
    _pathColors.add(_chainColorForIndex(_path.length - 1));
    _playChainNote(_path.length);
    _lastValue = v;
    setState(() {});
  }
}



void _recomputeSelectionState() {
  _armed = false;
  _baseValue = null;
  _baseCount = 0;
  _stageValue = null;
  _stageCount = 0;

  if (_path.isEmpty) return;

  final firstV = _valueAt(_path.first);
  if (firstV == null) return;

  _baseValue = firstV;

  // count initial same-value run
  int i = 0;
  while (i < _path.length && _valueAt(_path[i]) == firstV) {
    i++;
  }
  _baseCount = i;

  if (_baseCount >= 2) {
    _armed = true;
    _stageValue = firstV;
    _stageCount = _baseCount;

    // walk remaining selections enforcing: same stage, or (stage even) -> next stage
    for (int j = i; j < _path.length; j++) {
      final v = _valueAt(_path[j]);
      if (v == null) break;
      final sv = _stageValue!;
      if (v == sv) {
        _stageCount++;
        continue;
      }
      if (_stageCount >= 2 && _stageCount.isEven && v == (sv << 1)) {
        _stageValue = sv << 1;
        _stageCount = 1;
        continue;
      }
      break;
    }
  }
  _lastValue = null;
}


void _onCellUp() {
  if (!_dragging) return;
  _dragging = false;

  if (_path.length >= 2) {
    _applyMergeChain(_path.toList());
  } else {
    _clearPath();
    setState(() {});
  }
}

void _applyMergeChain(List<Pos> chain) {
  if (chain.length < 2) {
    _clearPath();
    return;
  }

  final pos = <Pos>[];
  BigInt sum = BigInt.zero;

  for (final p in chain) {
    final v = _valueAt(p);
    if (v == null) break;
    pos.add(p);
    sum += v;
  }

  if (pos.length < 2) {
    _clearPath();
    _saveToBlob();
    setState(() {});
    return;
  }

  // Old-version merge math:
  // merged = next power-of-two >= max(2, sum(values))
  BigInt target = BigInt.one;
  final minNeed = sum < BigInt.from(2) ? BigInt.from(2) : sum;
  while (target < minNeed) {
    target = target << 1;
  }

  // Clear all but the final (target) position.
  for (int i = 0; i < pos.length - 1; i++) {
    final p = pos[i];
    grid[p.r][p.c] = null;
  }

  final targetPos = pos.last;
  grid[targetPos.r][targetPos.c] = target;

  // Keep scoring minimal and consistent: award merged value.
  score += target;
  _animateCoinGain((pos.length + 2).clamp(2, 10));
  _recalcBest();

  _clearPath();

  // Let existing gravity + spawn animation system handle refills.
  _collapseAndFill();

  // Treat "combo" as number of tiles consumed.
  _handleCombo(max(0, pos.length - 1));
  _checkGoalAndMaybeAdvance();
  _maybeShowNextLevelReward();
  _saveGame();

  setState(() {});
}



void _cascadeFrom(Pos start) {
  // Chain merge (no collapse during cascade):
  // While the tile has an equal neighbour (8-direction), merge pairwise into this tile.
  Pos cur = start;
  while (true) {
    final v = grid[cur.r][cur.c];
    if (v == null) return;

    Pos? neighborSame;
    for (int dr = -1; dr <= 1; dr++) {
      for (int dc = -1; dc <= 1; dc++) {
        if (dr == 0 && dc == 0) continue;
        final p = Pos(cur.r + dr, cur.c + dc);
        if (!_inBounds(p)) continue;
        if (grid[p.r][p.c] == v) {
          neighborSame = p;
          break;
        }
      }
      if (neighborSame != null) break;
    }
    if (neighborSame == null) return;

    // Consume neighbour into current.
    grid[neighborSame.r][neighborSame.c] = null;
    final newV = v * BigInt.from(2);
    grid[cur.r][cur.c] = newV;

    // Score adds the produced value.
    score += newV;
    _animateCoinGain(3);
    _recalcBest();
  }
}

void _collapseAndFill() {
  // Gravity collapse downwards per column, then fill empties with spawn values.
  // Also record how many "cell steps" each tile falls so we can animate it.
  _fallSteps.clear();

  for (int c = 0; c < cols; c++) {
    final tiles = <_TileFall>[];

    // Collect existing tiles bottom-up.
    for (int r = rows - 1; r >= 0; r--) {
      final v = grid[r][c];
      if (v != null) {
        tiles.add(_TileFall(v: v, fromR: r));
      }
    }

    // Write them back bottom-up.
    int writeR = rows - 1;
    for (final t in tiles) {
      grid[writeR][c] = t.v;
      final steps = t.fromR - writeR;
      if (steps != 0) {
        _fallSteps[Pos(writeR, c)] = steps.abs();
      }
      writeR--;
    }

    // Clear remaining.
    for (int r = writeR; r >= 0; r--) {
      grid[r][c] = null;
    }

    // Fill empties with new spawn values (these should "fall" from above).
    for (int r = writeR; r >= 0; r--) {
      final spawned = _spawnValue();
      grid[r][c] = spawned;
      _fallSteps[Pos(r, c)] = (r + 1); // fall from above the column
    }
  }

  // Trigger spawn/fall animations.
  _spawnTick++;
}


  // Wrapper kept for compatibility with older call sites.
  BigInt _spawnValue() => _spawnTile();

  void _handleCombo(int merges) {
    _lastCombo = merges;
    _playMergeMelody(merges);
    if (merges < 5) return;

    String msg;
    if (merges >= 11) {
      diamonds += 1;
      _animateDiamondGain(1);
      msg = lang == AppLang.de ? 'MEGA KOMBO! +1 💎' : 'MEGA COMBO! +1 💎';
    } else if (merges >= 8) {
      msg = lang == AppLang.de ? 'TOLLE KOMBO!' : 'AWESOME COMBO!';
    } else {
      msg = lang == AppLang.de ? 'SUPER KOMBO!' : 'SUPER COMBO!';
    }
    _showToast(msg);
  }

  void _maybeShowNextLevelReward() {
    // Phase 2 rewarded flow is not wired in this DartPad-safe build.
    // Kept as no-op so we don't break existing call sites.
  }

  void _saveGame() {
    _saveToBlob();
  }

  void _checkGoalAndMaybeAdvance() {
    // Phase 1: level increases when reaching targets (2048, 4096, 8192 ...).
    // No automatic diamond reward here (rewarded flow will be Phase 2).
    while (true) {
      final goal = _goalForLevel(levelIdx);
      final curMax = _maxOnBoard();
      if (curMax >= goal) {
        levelIdx += 1;
        diamonds += 3;
        _showLevelUpFx(levelIdx);
        _animateDiamondGain(3);
        _showToast('+3 💎 LEVEL');
        continue;
      }
      break;
    }
  }

  // ===== Tools =====

  void _handleSwapTap(Pos p) {
    final v = grid[p.r][p.c];
    if (v == null) return;

    if (_swapFirst == null) {
      _swapFirst = p;
      _showToast('1/2');
      _saveToBlob();
      setState(() {});
      return;
    }
    if (_swapFirst == p) {
      _swapFirst = null;
      setState(() {});
      return;
    }
    final a = _swapFirst!;
    final tmp = grid[a.r][a.c];
    grid[a.r][a.c] = grid[p.r][p.c];
    grid[p.r][p.c] = tmp;

    if (swaps > 0) swaps -= 1;
    swapMode = false;
    _swapFirst = null;
    _showToast(t('swap'));
    setState(() {});
  }

  void _handleHammerTap(Pos p) {
    if (grid[p.r][p.c] == null) return;
    grid[p.r][p.c] = null;
    _collapseAndFill();
    hammerMode = false;
    _showToast(t('broken'));
    setState(() {});
  }

  void _toggleSwap() {
  if (!swapMode) {
    if (diamonds < 10) {
      _showToast(t('notEnoughDiamonds'));
      return;
    }
    diamonds -= 10;
    swapMode = true;
    hammerMode = false;
    duplicateMode = false;
    _swapFirst = null;
    _showToast('-10 💎');
  } else {
    swapMode = false;
    _swapFirst = null;
  }
  _saveToBlob();
  setState(() {});
}

  void _toggleHammer() {
    if (!hammerMode) {
      if (diamonds < 7) {
        _showToast(t('notEnoughDiamonds'));
        return;
      }
      diamonds -= 7;
      hammerMode = true;
      swapMode = false;
      _swapFirst = null;
      _showToast('-7 💎');
    } else {
      hammerMode = false;
    }
    _saveToBlob();
    setState(() {});
  }

void _toggleDuplicate() {
  if (!duplicateMode) {
    if (diamonds < 20) {
      _showToast(t('notEnoughDiamonds'));
      return;
    }
    diamonds -= 20;
    duplicateMode = true;
    swapMode = false;
    hammerMode = false;
    _swapFirst = null;
    _showToast('-20 💎');
  } else {
    duplicateMode = false;
  }
  _saveToBlob();
  setState(() {});
}

void _handleDuplicateTap(Pos p) {
  final v = _valueAt(p);
  if (v == null) return;
  grid[p.r][p.c] = v << 1;
  duplicateMode = false;
  _showToast('x2');
  _saveToBlob();
  setState(() {});
}

  void _watchAdReward() {
  diamonds += 10;
  _animateDiamondGain(10);
  _showToast('+10 💎');
  _saveToBlob();
  setState(() {});
}


  Offset _centerForKey(GlobalKey key, {Offset? fallback}) {
    final rootCtx = _rootStackKey.currentContext;
    final targetCtx = key.currentContext;
    if (rootCtx == null || targetCtx == null) return fallback ?? Offset.zero;
    final rootBox = rootCtx.findRenderObject();
    final targetBox = targetCtx.findRenderObject();
    if (rootBox is! RenderBox || targetBox is! RenderBox) return fallback ?? Offset.zero;
    final topLeft = targetBox.localToGlobal(Offset.zero, ancestor: rootBox);
    return topLeft + Offset(targetBox.size.width / 2, targetBox.size.height / 2);
  }

  Offset _diamondCounterCenterLocal() => _centerForKey(_diamondCounterKey, fallback: const Offset(74, 56));
  Offset _scoreCounterCenterLocal() => _centerForKey(_scoreCounterKey, fallback: const Offset(280, 56));

  int _visualGemFlyCount(int amount) {
    if (amount <= 1) return 1;
    if (amount <= 2) return 2;
    if (amount <= 3) return 3;
    if (amount <= 5) return 5;
    if (amount <= 10) return 7;
    if (amount <= 50) return 15;
    if (amount <= 100) return 20;
    return 30;
  }

  void _animateDiamondGain(int amount, {Offset? from}) {
    if (!mounted || amount <= 0) return;
    final target = _diamondCounterCenterLocal();
    final rootObj = _rootStackKey.currentContext?.findRenderObject();
    final rootSize = rootObj is RenderBox ? rootObj.size : const Size(360, 760);
    final fromBase = from ?? Offset(rootSize.width * 0.50, rootSize.height * 0.58);
    final now = DateTime.now().millisecondsSinceEpoch;
    final count = _visualGemFlyCount(amount);
    for (int i = 0; i < count; i++) {
      final jitter = Offset((i % 5 - 2) * 8.0, (i ~/ 5) * 6.0 - 12.0);
      _gemFlyFx.add(_GemFlyFx(id: _gemFxId++, from: fromBase + jitter, to: target, startMs: now + i * 55));
    }
    Timer(Duration(milliseconds: 1200 + count * 55), () { if (mounted) setState(() => _gemFlyFx.clear()); });
    setState(() {});
  }

  void _animateCoinGain(int count, {Offset? from}) {
    if (!mounted || count <= 0) return;
    final target = _scoreCounterCenterLocal();
    final rootObj = _rootStackKey.currentContext?.findRenderObject();
    final rootSize = rootObj is RenderBox ? rootObj.size : const Size(360, 760);
    final fromBase = from ?? Offset(rootSize.width * 0.50, rootSize.height * 0.63);
    final now = DateTime.now().millisecondsSinceEpoch;
    final n = count.clamp(2, 18);
    for (int i = 0; i < n; i++) {
      final jitter = Offset((i % 6 - 2.5) * 7.0, (i ~/ 6) * 6.0 - 10.0);
      _coinFlyFx.add(_CoinFlyFx(id: _coinFxId++, from: fromBase + jitter, to: target, startMs: now + i * 36));
    }
    Timer(Duration(milliseconds: 900 + n * 36), () { if (mounted) setState(() => _coinFlyFx.clear()); });
    setState(() {});
  }

  // ===== UI helpers =====

  void _showToast(String msg) {
    _toastTimer?.cancel();
    setState(() => _toast = msg);
    _toastCtrl.forward(from: 0);

    _toastTimer = Timer(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      // Fade out quickly before removing.
      _toastCtrl.reverse().whenComplete(() {
        if (!mounted) return;
        setState(() => _toast = null);
      });
    });
  }

  void _showLevelUpFx(int lvl) {
    _levelTimer?.cancel();
    _levelMsg = 'LEVEL $lvl';
    _levelCtrl.forward(from: 0);
    HapticFeedback.heavyImpact();

    _levelTimer = Timer(const Duration(milliseconds: 1500), () {
      if (!mounted) return;
      _levelCtrl.reverse().whenComplete(() {
        if (!mounted) return;
        setState(() => _levelMsg = null);
      });
    });

    setState(() {});
  }




  void _showLaunchOfferIfNeeded() {
    if (_launchOfferShown || !mounted) return;
    _launchOfferShown = true;
    final packs = const <({int gems, int oldUsd})>[
      (gems: 100, oldUsd: 5),
      (gems: 250, oldUsd: 15),
      (gems: 500, oldUsd: 29),
      (gems: 1000, oldUsd: 59),
    ];
    final o = packs[DateTime.now().millisecond % packs.length];
    final newUsd = (o.oldUsd * 0.6).round();
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.62),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF09163E), Color(0xFF120B2D)]),
            border: Border.all(color: Colors.white.withOpacity(0.14)),
            boxShadow: const [BoxShadow(color: Color(0x8027E6FF), blurRadius: 30), BoxShadow(color: Color(0x668A5BFF), blurRadius: 44)],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Stack(alignment: Alignment.center, children: [
                Container(height: 138, decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), gradient: LinearGradient(colors:[const Color(0xFF27E6FF).withOpacity(0.12),const Color(0xFF8A5BFF).withOpacity(0.10),const Color(0xFFFF4D8D).withOpacity(0.10)]))),
                Positioned(top: 2, right: 4, child: Transform.rotate(angle: 0.12, child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(gradient: const LinearGradient(colors:[Color(0xFFFFC107),Color(0xFFFF6F00)]), borderRadius: BorderRadius.circular(999)), child: const Text('%40 DISCOUNT', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 0.8, fontSize: 11))))),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.86, end: 1.0), duration: const Duration(milliseconds: 900), curve: Curves.elasticOut,
                  builder: (c,v,_) => Transform.scale(scale: v, child: Stack(alignment: Alignment.center, children: [
                    Container(width: 92, height: 76, decoration: BoxDecoration(color: const Color(0xFF7A4A23), borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFB8864B), width: 1.6))),
                    Positioned(top: 18, child: Container(width: 70, height: 14, decoration: BoxDecoration(color: const Color(0xFF9D6233), borderRadius: BorderRadius.circular(999), border: Border.all(color: const Color(0xFFC18C57), width: 1.1)))),
                    Positioned(top: 10, child: Container(width: 36, height: 12, decoration: BoxDecoration(color: const Color(0xFF6B3C1E), borderRadius: BorderRadius.circular(999)))),
                    ...List.generate(11, (i) { final dx=(-38 + i*8.0)+(i.isEven?2:-2); final dy=i<4?-20.0:(i<8?-4.0:12.0); final sz=i%3==0?18.0:15.0; const cols=[Color(0xFF90CAF9),Color(0xFFB388FF),Color(0xFF7DF9FF)]; return Positioned(left: 46+dx, top: 42+dy, child: Icon(Icons.diamond, size: sz, color: cols[i%3])); }),
                  ])),
                ),
              ]),
              const SizedBox(height: 10),
              Text('Sana Özel Teklifimiz', style: _neon(19, opacity: 0.99).copyWith(letterSpacing: 0.4, fontStyle: FontStyle.italic)),
              const SizedBox(height: 6),
              Text('${o.gems} ELMAS', style: _neon(23, opacity: 1.0).copyWith(fontWeight: FontWeight.w900, letterSpacing: 1.3)),
              const SizedBox(height: 6),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text('\$${o.oldUsd}', style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 15, fontWeight: FontWeight.w700, decoration: TextDecoration.lineThrough, decorationColor: Colors.white38)),
                const SizedBox(width: 10),
                Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), gradient: const LinearGradient(colors:[Color(0xFF1DE9B6),Color(0xFF00B0FF)])), child: Text('\$${newUsd}', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 0.5))),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: OutlinedButton(onPressed: ()=>Navigator.pop(ctx), child: const Text('Later'))),
                const SizedBox(width: 8),
                Expanded(child: FilledButton(onPressed: () { Navigator.pop(ctx); setState(() => diamonds += o.gems); _animateDiamondGain(o.gems); _saveToBlob(); _showToast('+${o.gems} 💎 OFFER'); }, child: const Text('Buy Now'))),
              ]),
            ]),
          ),
        ),
      ),
    );
  }

  void _playChainNote(int index) {
    // Lightweight, plugin-free feedback. On mobile this is a short click + haptic.
    // (For real piano samples later, swap this out with an audio plugin.)
    HapticFeedback.selectionClick();
    SystemSound.play(SystemSoundType.click);
  }

  void _playMergeMelody(int mergedCount) {
    // Play a short ascending "piano-like" click sequence.
    final n = mergedCount.clamp(2, 8);
    for (int i = 0; i < n; i++) {
      Timer(Duration(milliseconds: 70 * i), () {
        SystemSound.play(SystemSoundType.click);
      });
    }
    if (n >= 5) HapticFeedback.lightImpact();
  }

  String _fmtBig(BigInt n) {
  // UI should display only numbers (no extra letters like "2a").
  // We format large values with short suffixes: K, M, B, T.
  final num v = n.toDouble();
  if (v < 1000) return n.toString();
  const suffixes = ['K', 'M', 'B', 'T', 'Q'];
  double x = v.toDouble();
  int i = 0;
  while (x >= 1000 && i < suffixes.length - 1) {
    x /= 1000.0;
    i++;
  }
  final str = x >= 10 ? x.toStringAsFixed(0) : x.toStringAsFixed(1);
  return str + suffixes[i - 1];
}

  Color _tileColor(BigInt v) {
    final int p = (v.bitLength - 1).clamp(0, 30);
    final hues = <Color>[
      const Color(0xFF1B2A41), // deep navy
      const Color(0xFF2E4A7D), // blue
      const Color(0xFF5B2C83), // purple
      const Color(0xFF007C8A), // teal
      const Color(0xFFB84A6D), // magenta rose
      const Color(0xFFB9851C), // amber
      const Color(0xFF2D8A4A), // green
      const Color(0xFF1F6FB2), // bright blue
      const Color(0xFF8A3FFC), // neon violet
      const Color(0xFF00A3FF), // cyan
      const Color(0xFFFF4D8D), // neon pink
      const Color(0xFFFFB703), // neon amber
      const Color(0xFF00D68F), // neon green
      const Color(0xFFEF476F), // coral
      const Color(0xFF06D6A0), // mint
      const Color(0xFF118AB2), // ocean
      const Color(0xFF9B5DE5), // lavender neon
      const Color(0xFFF15BB5), // pink
    ];
    return hues[p % hues.length];
  }

  TextStyle _neon(double size, {double opacity = 0.92, bool bold = true}) {
    return TextStyle(
      color: Colors.white.withOpacity(opacity),
      fontSize: size,
      fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
      shadows: const [
        Shadow(blurRadius: 10, color: Color(0xAAFFFFFF), offset: Offset(0, 0)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_booting) {
      return const Scaffold(
        backgroundColor: Color(0xFF071033),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final goal = _goalForLevel(levelIdx);
    final curMax = _maxOnBoard();
    final bestLocal = best;
    final nowLabel = _fmtBig(curMax);
    final maxLabel = _fmtBig(bestLocal);
    final goalLabel = _fmtBig(goal);
    final ratio = goal == BigInt.zero ? 0.0 : min(1.0, curMax.toDouble() / goal.toDouble());

    return Scaffold(
      backgroundColor: const Color(0xFF071033),
      body: SafeArea(
        bottom: false,
        child: Stack(
          key: _rootStackKey,
          children: [
            Column(
              children: [
                _buildHeader(nowLabel: nowLabel, maxLabel: maxLabel, goalLabel: goalLabel, ratio: ratio),
                const SizedBox(height: 10),
                Expanded(child: _buildBoard()),
                const SizedBox(height: 6),
              ],
            ),
            if (_toast != null)
              Positioned(
                left: 0,
                right: 0,
                // Keep toast above action bar + banner.
                bottom: 14 + kBannerHeight + 112,
                child: Center(
                  child: FadeTransition(
                    opacity: _toastOpacity,
                    child: ScaleTransition(
                      scale: _toastScale,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0E1A3B).withOpacity(0.86),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: const Color(0xFF7DF9FF).withOpacity(0.28)),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF7DF9FF).withOpacity(0.22),
                              blurRadius: 22,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: Text(_toast!, style: _neon(15, opacity: 0.98)),
                      ),
                    ),
                  ),
                ),
              ),

            if (_levelMsg != null)
              Positioned.fill(
                child: IgnorePointer(
                  child: AnimatedBuilder(
                    animation: _levelCtrl,
                    builder: (context, _) {
                      final t = _levelCtrl.value;
                      final eased = Curves.easeOutCubic.transform(t.clamp(0.0, 1.0));
                      final fade = (1.0 - (t - 0.72).clamp(0.0, 0.28) / 0.28).clamp(0.0, 1.0);
                      final scale = 0.65 + (eased * 1.35); // ~3x visual impact via huge base + scale
                      return Opacity(
                        opacity: fade,
                        child: Center(
                          child: Transform.scale(
                            scale: scale,
                            child: SizedBox(
                              width: 140,
                              height: 140,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  Positioned.fill(
                                    child: CustomPaint(
                                      painter: _LevelUpBurstPainter(
                                        t: eased,
                                        seed: levelIdx * 997,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    width: 116,
                                    height: 116,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: RadialGradient(
                                        colors: [
                                          const Color(0xAA7DF9FF),
                                          const Color(0x668A5BFF),
                                          Colors.transparent,
                                        ],
                                      ),
                                      border: Border.all(
                                        color: Colors.white.withOpacity(0.65),
                                        width: 1.8,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFF7DF9FF).withOpacity(0.35),
                                          blurRadius: 26,
                                          spreadRadius: 4,
                                        ),
                                        BoxShadow(
                                          color: const Color(0xFF8A5BFF).withOpacity(0.28),
                                          blurRadius: 40,
                                          spreadRadius: 8,
                                        ),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text('LEVEL UP', style: _neon(10, opacity: 0.95)),
                                      const SizedBox(height: 2),
                                      Text('LV $levelIdx', style: _neon(18, opacity: 1.0)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ..._gemFlyFx.map((fx) => _GemFlyWidget(fx: fx)),
            ..._coinFlyFx.map((fx) => _CoinFlyWidget(fx: fx)),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildBottomBar(),
            _buildBannerAdPlaceholder(),
          ],
        ),
      ),
    );
  }

  Widget _buildBannerAdPlaceholder() {
    // Phase 1: fixed-size banner slot to prevent board overlap.
    // Replace this Container with real AdMob Banner widget when integrating ads.
    return SizedBox(
      height: kBannerHeight,
      child: Container(
        margin: const EdgeInsets.fromLTRB(14, 0, 14, 6),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.10)),
        ),
        child: Center(
          child: Text(
            'BANNER AD',
            style: TextStyle(
              color: Colors.white.withOpacity(0.65),
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.1,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader({
    required String nowLabel,
    required String maxLabel,
    required String goalLabel,
    required double ratio,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
      child: Column(
        children: [
          Row(
            children: [
              _pill(
                key: _diamondCounterKey,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.diamond, size: 18, color: Color(0xFFB388FF)),
                    const SizedBox(width: 6),
                    Text('$diamonds', style: _neon(16)),
                    const SizedBox(width: 8),
                    _tinyButton(icon: Icons.add, onTap: _openShopSheet),
                  ],
                ),
              ),
              const Spacer(),
              Container(key: _scoreCounterKey, child: Text(_fmtBig(score), style: _neon(34, opacity: 0.98))),
              const Spacer(),
              _pill(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.workspace_premium, size: 18, color: Color(0xFFFFD54F)),
                    const SizedBox(width: 6),
                    Text('Level $levelIdx', style: _neon(14)),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _tinyButton(icon: Icons.settings, onTap: _openSettingsSheet),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _miniStatChip(t('now'), nowLabel)),
              const SizedBox(width: 10),
              Expanded(child: _miniStatChip(t('max'), maxLabel)),
              const SizedBox(width: 10),
              Expanded(child: _miniStatChip(t('next'), goalLabel)),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 10,
              backgroundColor: Colors.white.withOpacity(0.10),
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white.withOpacity(0.75)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pill({Key? key, required Widget child}) {
    return Container(
      key: key,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.14)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.35), blurRadius: 16, offset: const Offset(0, 8))],
      ),
      child: child,
    );
  }

  Widget _tinyButton({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 34,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.10),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.16)),
        ),
        child: Icon(icon, size: 18, color: Colors.white.withOpacity(0.92)),
      ),
    );
  }

  Widget _miniStatChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Column(
        children: [
          Text(label, style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 12, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(value, style: _neon(14, opacity: 0.95)),
        ],
      ),
    );
  }

  
Widget _buildBoard() {
  return LayoutBuilder(
    builder: (context, constraints) {
      final gap = kGap;
      final availW = constraints.maxWidth;
      final availH = constraints.maxHeight;

      final cellW = (availW - (cols - 1) * gap) / cols;
      final cellH = (availH - (rows - 1) * gap) / rows;
      final cellSize = max(6.0, min(cellW, cellH));

      final boardW = cols * cellSize + (cols - 1) * gap;
      final boardH = rows * cellSize + (rows - 1) * gap;

      void feed(Offset from, Offset to) {
        final dx = to.dx - from.dx;
        final dy = to.dy - from.dy;
        final dist = sqrt(dx * dx + dy * dy);
        final step = max(1.0, (cellSize + gap) / 3);
        final n = max(1, (dist / step).ceil());
        for (int i = 1; i <= n; i++) {
          final tt = i / n;
          final o = Offset(from.dx + dx * tt, from.dy + dy * tt);
          final p = _hitTestPos(o, cellSize, gap);
          if (p != null) _onCellEnter(p);
        }
      }

      return Center(
        child: SizedBox(
          width: boardW,
          height: boardH,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanStart: (d) {
              _lastPanLocal = d.localPosition;
              final p = _hitTestPos(d.localPosition, cellSize, gap);
              if (p != null) _onCellDown(p);
            },
            onPanUpdate: (d) {
              final prev = _lastPanLocal ?? d.localPosition;
              feed(prev, d.localPosition);
              _lastPanLocal = d.localPosition;
            },
            onPanEnd: (_) {
              _lastPanLocal = null;
              _onCellUp();
            },
            onPanCancel: () {
              _lastPanLocal = null;
              _onCellUp();
            },
            onTapDown: (d) {
              final p = _hitTestPos(d.localPosition, cellSize, gap);
              if (p != null) _onCellDown(p);
            },
            onTapUp: (_) => _onCellUp(),
            child: Stack(
              children: [
                for (int r = 0; r < rows; r++)
                  for (int c = 0; c < cols; c++)
                    Positioned(
                      left: c * (cellSize + gap),
                      top: r * (cellSize + gap),
                      width: cellSize,
                      height: cellSize,
                      child: _cellWidget(Pos(r, c), cellSize),
                    ),

                // Premium vanish FX (if present)
                for (final fx in _vanishFx)
                  Positioned(
                    left: fx.pos.c * (cellSize + gap),
                    top: fx.pos.r * (cellSize + gap),
                    width: cellSize,
                    height: cellSize,
                    child: _vanishFxWidget(fx, cellSize),
                  ),

                if (_path.length >= 2)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: _NeonPathPainter(
                          points: _path,
                          colors: _pathColors,
                          cellSize: cellSize,
                          gap: gap,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
  // Premium merge vanish FX overlay (safe stub).
  // If you later want a richer effect, we can animate opacity/scale here.
  Widget _vanishFxWidget(_VanishFx fx, double size) {
    return const SizedBox.shrink();
  }



  Widget _cellWidget(Pos p, double size) {
  final v = grid[p.r][p.c];
  final selected = _path.contains(p);
  final isSwapFirst = (swapMode && _swapFirst == p);

  final steps = _fallSteps[p] ?? 0;
  final beginDy = steps <= 0 ? 0.0 : -(steps * (size + kGap));

  final baseColor = v == null ? Colors.white.withOpacity(0.05) : _tileColor(v).withOpacity(0.92);
  final top = _lighten(baseColor, 0.08);
  final bottom = _darken(baseColor, 0.16);

  return TweenAnimationBuilder<double>(
      key: ValueKey('fall_${p.r}_${p.c}_${v?.toString() ?? "n"}_${_spawnTick}'),
      tween: Tween<double>(begin: beginDy, end: 0.0),
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      builder: (context, dy, child) {
        return Transform.translate(offset: Offset(0, dy), child: child);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          gradient: v == null
              ? null
              : LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [top, baseColor, bottom],
                ),
          color: v == null ? Colors.white.withOpacity(0.05) : null,
          borderRadius: BorderRadius.circular(12), // more square-ish
          border: Border.all(
            color: (selected || isSwapFirst) ? Colors.white.withOpacity(0.90) : Colors.white.withOpacity(0.10),
            width: (selected || isSwapFirst) ? 2 : 1,
          ),
          boxShadow: [
            // subtle 3D depth
            BoxShadow(
              color: Colors.black.withOpacity(selected ? 0.50 : 0.32),
              blurRadius: selected ? 18 : 12,
              offset: const Offset(0, 8),
            ),
            if (v != null)
              BoxShadow(
                color: Colors.white.withOpacity(0.10),
                blurRadius: 8,
                offset: const Offset(-2, -2),
              ),
          ],
        ),
        child: Center(
          child: v == null
              ? const SizedBox.shrink()
              : Text(
                  _fmtBig(v),
                  style: _neon(size * 0.26, opacity: 0.96),
                ),
        ),
      ),
    );
}


  Widget _buildBottomBar() {
  return Container(
    padding: const EdgeInsets.fromLTRB(12, 4, 12, 6),
    decoration: BoxDecoration(
      color: const Color(0xFF06102C),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.45), blurRadius: 20, offset: const Offset(0, -10))],
    ),
    child: Row(
      children: [
        Expanded(
          child: _actionButton(
            icon: swapMode ? Icons.close : Icons.swap_horiz,
            label: t('swap'),
            sub: '10',
            active: swapMode,
            onTap: _toggleSwap,
            showLabel: false,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: _actionButton(
            icon: hammerMode ? Icons.close : Icons.gavel,
            label: t('hammer'),
            sub: '7',
            active: hammerMode,
            onTap: _toggleHammer,
            showLabel: false,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: _actionButton(
            icon: Icons.smart_display,
            label: t('watchAd'),
            sub: '+10',
            active: false,
            onTap: _watchAdReward,
            showLabel: false,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: _actionButton(
            icon: duplicateMode ? Icons.close : Icons.copy,
            label: t('duplicate'),
            sub: '20',
            active: duplicateMode,
            onTap: _toggleDuplicate,
            showLabel: false,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: _actionButton(
            icon: Icons.shopping_cart,
            label: t('shop'),
            sub: '',
            active: false,
            onTap: _openShopSheet,
            showLabel: false,
          ),
        ),
      ],
    ),
  );
}

  Widget _actionButton({
    required IconData icon,
    required String label,
    String? sub,
    required bool active,
    required VoidCallback onTap,
    double? height,
    bool showLabel = true,
    bool showSub = true,
  }) {
    final scale = uiScale;
    final h = height ?? (74.0 * scale);

    return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          height: h,
          margin: EdgeInsets.symmetric(horizontal: 5 * scale),
          padding: EdgeInsets.symmetric(horizontal: 10 * scale, vertical: 10 * scale),
          decoration: BoxDecoration(
            color: active ? const Color(0xFF1B2A57).withOpacity(0.90) : const Color(0xFF0E1A3B).withOpacity(0.78),
            borderRadius: BorderRadius.circular(16 * scale),
            border: Border.all(color: active ? const Color(0xFF7DF9FF).withOpacity(0.60) : Colors.white.withOpacity(0.06)),
            boxShadow: [
              if (active)
                BoxShadow(
                  color: const Color(0xFF7DF9FF).withOpacity(0.20),
                  blurRadius: 18 * scale,
                  spreadRadius: 1,
                )
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 32 * scale, color: Colors.white.withOpacity(0.98)),
              SizedBox(height: 4 * scale),
              if (showSub && sub != null && sub!.isNotEmpty)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.diamond, size: 14, color: Color(0xFFB388FF)),
                    SizedBox(width: 3 * scale),
                    Text(
                      sub!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: _neon(13 * scale, opacity: 0.95),
                    ),
                  ],
                )
              else if (showLabel)
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: _neon(12 * scale, opacity: 0.92),
                  ),
                ),
            ],
          ),
        ),
    );
  }

  // ===== Sheets / dialogs =====

  void _openShopSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF06102C),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) {
        final offers = const [
          (50, 2),
          (100, 3),
          (250, 5),
          (500, 8),
          (1000, 15),
        ];
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(t('shopTitle'), style: _neon(20, opacity: 0.98)),
              const SizedBox(height: 12),
              ...offers.map((o) {
                final gems = o.$1;
                final usd = o.$2;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: GestureDetector(
                    onTap: () {
                      setState(() => diamonds += gems);
                      Navigator.pop(ctx);
                      _animateDiamondGain(gems);
                      _saveToBlob();
                      _showToast('+$gems 💎');
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: Colors.white.withOpacity(0.12)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.diamond, color: Color(0xFFB388FF)),
                          const SizedBox(width: 10),
                          Text('$gems 💎', style: _neon(16)),
                          const Spacer(),
                          Text('\$$usd', style: _neon(16, opacity: 0.9)),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.white.withOpacity(0.14)),
                            ),
                            child: Text(t('buy'), style: _neon(12, opacity: 0.9)),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
              const SizedBox(height: 6),
              Text(
                'Note: This shop UI is a placeholder. (Real Google Play Billing can be integrated in the full project.)',
                style: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 11, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      },
    );
  }

  void _openSettingsSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF06102C),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(t('settings'), style: _neon(20, opacity: 0.98)),
              const SizedBox(height: 12),
              _settingsRow(
                title: 'Language',
                child: SegmentedButton<AppLang>(
                  segments: const [
                    ButtonSegment(value: AppLang.en, label: Text('EN')),
                    ButtonSegment(value: AppLang.de, label: Text('DE')),
                  ],
                  selected: {lang},
                  onSelectionChanged: (s) => setState(() => lang = s.first),
                ),
              ),
              const SizedBox(height: 10),
              _settingsRow(
                title: 'Reset',
                child: FilledButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _resetBoard(hard: true);
                  },
                  child: const Text('Hard reset'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _settingsRow({required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Row(
        children: [
          Expanded(child: Text(title, style: _neon(13, opacity: 0.9))),
          const SizedBox(width: 10),
          child,
        ],
      ),
    );
  }

  void _openPauseDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0B163A),
        title: Text(t('pause'), style: _neon(18)),
        content: Text(
          'Swap / Tokmak modunu kapatıp oyuna dönebilir veya yeniden başlatabilirsin.',
          style: TextStyle(color: Colors.white.withOpacity(0.75)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(t('resume'))),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _resetBoard(hard: true);
            },
            child: Text(t('restart')),
          ),
        ],
      ),
    );
  }
}

Color _lighten(Color c, double amount) {
  final hsl = HSLColor.fromColor(c);
  final l = (hsl.lightness + amount).clamp(0.0, 1.0) as double;
  return hsl.withLightness(l).toColor();
}

Color _darken(Color c, double amount) {
  final hsl = HSLColor.fromColor(c);
  final l = (hsl.lightness - amount).clamp(0.0, 1.0) as double;
  return hsl.withLightness(l).toColor();
}

class _GemFxDot extends StatefulWidget {
  final _GemFlyFx fx; final VoidCallback onDone;
  const _GemFxDot({required this.fx, required this.onDone});
  @override State<_GemFxDot> createState() => _GemFxDotState();
}
class _GemFxDotState extends State<_GemFxDot> {
  @override Widget build(BuildContext context) {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now < widget.fx.startMs) { Future.delayed(Duration(milliseconds: widget.fx.startMs-now),(){ if(mounted) setState((){});}); return const SizedBox.shrink(); }
    final p = (((now-widget.fx.startMs).clamp(0,760))/760.0).toDouble();
    if (p >= 1.0) { WidgetsBinding.instance.addPostFrameCallback((_)=>widget.onDone()); return const SizedBox.shrink(); }
    final pos = Offset.lerp(widget.fx.from, widget.fx.to, Curves.easeOutCubic.transform(p))! + Offset(0, -sin(p*pi)*34);
    WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) setState(() {}); });
    return Transform.translate(offset: pos, child: const Icon(Icons.diamond, size: 14, color: Color(0xFFB388FF)));
  }
}
class _CoinFxDot extends StatefulWidget {
  final _CoinFlyFx fx; final VoidCallback onDone;
  const _CoinFxDot({required this.fx, required this.onDone});
  @override State<_CoinFxDot> createState() => _CoinFxDotState();
}
class _CoinFxDotState extends State<_CoinFxDot> {
  @override Widget build(BuildContext context) {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now < widget.fx.startMs) { Future.delayed(Duration(milliseconds: widget.fx.startMs-now),(){ if(mounted) setState((){});}); return const SizedBox.shrink(); }
    final p = (((now-widget.fx.startMs).clamp(0,660))/660.0).toDouble();
    if (p >= 1.0) { WidgetsBinding.instance.addPostFrameCallback((_)=>widget.onDone()); return const SizedBox.shrink(); }
    final pos = Offset.lerp(widget.fx.from, widget.fx.to, Curves.easeOutCubic.transform(p))! + Offset(0, -sin(p*pi)*26);
    WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) setState(() {}); });
    return Transform.translate(offset: pos, child: const Icon(Icons.monetization_on, size: 13, color: Color(0xFFFFD54F)));
  }
}

@immutable
class Pos {
  final int r;
  final int c;
  const Pos(this.r, this.c);

  @override
  bool operator ==(Object other) => other is Pos && other.r == r && other.c == c;

  @override
  int get hashCode => Object.hash(r, c);
}

class _NeonPathPainter extends CustomPainter {
  final List<Pos> points;
  final List<Color> colors;
  final double cellSize;
  final double gap;

  const _NeonPathPainter({
    required this.points,
    required this.colors,
    required this.cellSize,
    required this.gap,
  });

  Offset _center(Pos p) {
    final x = p.c * (cellSize + gap) + cellSize / 2;
    final y = p.r * (cellSize + gap) + cellSize / 2;
    return Offset(x, y);
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;

    for (int i = 0; i < points.length - 1; i++) {
      final c = (i < colors.length ? colors[i] : Colors.white.withOpacity(0.65));

      final glow = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 12
        ..strokeCap = StrokeCap.round
        ..color = c.withOpacity(0.22);

      final core = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round
        ..color = c.withOpacity(0.80);

      final a = _center(points[i]);
      final b = _center(points[i + 1]);
      canvas.drawLine(a, b, glow);
      canvas.drawLine(a, b, core);
    }
  }

  @override
  bool shouldRepaint(covariant _NeonPathPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.colors != colors ||
        oldDelegate.cellSize != cellSize ||
        oldDelegate.gap != gap;
  }
}


class _TileFall {
  final BigInt v;
  final int fromR;
  const _TileFall({required this.v, required this.fromR});
}

class _VanishFx {
  final Pos pos;
  final BigInt value;
  final int tick;
  const _VanishFx({required this.pos, required this.value, required this.tick});
}
class _GemFlyWidget extends StatefulWidget {
  final _GemFlyFx fx;
  const _GemFlyWidget({required this.fx});

  @override
  State<_GemFlyWidget> createState() => _GemFlyWidgetState();
}

class _GemFlyWidgetState extends State<_GemFlyWidget> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  Timer? _delay;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 780));
    final delay = max(0, widget.fx.startMs - DateTime.now().millisecondsSinceEpoch);
    _delay = Timer(Duration(milliseconds: delay), () {
      if (!mounted) return;
      setState(() => _started = true);
      _c.forward();
    });
  }

  @override
  void dispose() {
    _delay?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_started) return const SizedBox.shrink();
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final p = Curves.easeOutCubic.transform(_c.value.clamp(0.0, 1.0));
        final pos = Offset.lerp(widget.fx.from, widget.fx.to, p)! + Offset(0, -sin(p * pi) * 34);
        return Stack(children: [
          Positioned(
          left: pos.dx - 12,
          top: pos.dy - 12,
          child: Opacity(
            opacity: (1 - (_c.value * 0.15)).clamp(0.0, 1.0),
            child: Transform.scale(
              scale: 0.95 + (1 - p) * 0.30,
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: const Color(0xFF7DF9FF).withOpacity(0.28), blurRadius: 10)],
                ),
                child: const Icon(Icons.diamond, color: Color(0xFFB388FF), size: 20),
              ),
            ),
          ),
        )]);
      },
    );
  }
}

class _CoinFlyWidget extends StatefulWidget {
  final _CoinFlyFx fx;
  const _CoinFlyWidget({required this.fx});

  @override
  State<_CoinFlyWidget> createState() => _CoinFlyWidgetState();
}

class _CoinFlyWidgetState extends State<_CoinFlyWidget> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  Timer? _delay;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 660));
    final delay = max(0, widget.fx.startMs - DateTime.now().millisecondsSinceEpoch);
    _delay = Timer(Duration(milliseconds: delay), () {
      if (!mounted) return;
      setState(() => _started = true);
      _c.forward();
    });
  }

  @override
  void dispose() {
    _delay?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_started) return const SizedBox.shrink();
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final p = Curves.easeOutCubic.transform(_c.value.clamp(0.0, 1.0));
        final pos = Offset.lerp(widget.fx.from, widget.fx.to, p)! + Offset(0, -sin(p * pi) * 24);
        return Stack(children: [
          Positioned(
          left: pos.dx - 11,
          top: pos.dy - 11,
          child: Opacity(
            opacity: (1 - (_c.value * 0.25)).clamp(0.0, 1.0),
            child: Transform.scale(
              scale: 0.95 + (1 - p) * 0.20,
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const RadialGradient(colors: [Color(0xFFFFF59D), Color(0xFFFFB300)]),
                  border: Border.all(color: Colors.white.withOpacity(0.65), width: 1),
                  boxShadow: [BoxShadow(color: const Color(0x66FFC107).withOpacity(0.7), blurRadius: 10)],
                ),
                child: const Center(child: Icon(Icons.circle, size: 4, color: Colors.white70)),
              ),
            ),
          ),
        )]);
      },
    );
  }
}
