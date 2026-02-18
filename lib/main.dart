import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

void main() {
  runApp(const MergeBlocksApp());
}

class MergeBlocksApp extends StatelessWidget {
  const MergeBlocksApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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

enum AppLang { tr, en, de }

class UltraGamePage extends StatefulWidget {
  const UltraGamePage({super.key});

  @override
  State<UltraGamePage> createState() => _UltraGamePageState();
}

class _UltraGamePageState extends State<UltraGamePage> with TickerProviderStateMixin {
  // ===== Board config =====
  static const int cols = 5;
  static const int rows = 8;
  static const double kGap = 10.0;
  static const double kBannerHeight = 60.0; // fixed banner height (Phase 1)

  final Random _rng = Random();

  late List<List<BigInt?>> grid;

  int levelIdx = 1; // Level 1 starts
  BigInt score = BigInt.zero;
  BigInt best = BigInt.zero;
  int diamonds = 0; // starts with 0 diamonds

  bool swapMode = false;
  bool hammerMode = false;
  Pos? _swapFirst;

  final List<Pos> _path = [];
  final List<Color> _pathColors = <Color>[]; // per-segment chain line colors
  bool _dragging = false;

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

  AppLang lang = AppLang.en;

  // ===== Localization =====
  static const Map<String, String> _en = {
    'now': 'NOW',
    'max': 'MAX',
    'next': 'GOAL',
    'swap': 'SWAP',
    'hammer': 'HAMMER',
    'watchAd': 'AD',
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

  static const Map<String, String> _tr = {
    'now': 'ŞİMDİ',
    'max': 'EN BÜYÜK',
    'next': 'HEDEF',
    'swap': 'TAKAS',
    'hammer': 'TOKMAK',
    'watchAd': 'REKLAM',
    'shop': 'MAĞAZA',
    'pause': 'DURAKLAT',
    'settings': 'Ayarlar',
    'resume': 'Devam',
    'restart': 'Yeniden başlat',
    'notEnoughDiamonds': 'Yeterli elmas yok',
    'broken': 'Kırıldı!',
    'shopTitle': 'Elmas Mağazası',
    'buy': 'Satın al',
  };

  String t(String key) {
    final dict = switch (lang) {
      AppLang.de => _de,
      AppLang.tr => _tr,
      AppLang.en => _en,
    };
    return dict[key] ?? key;
  }

  @override
  void initState() {
    super.initState();
    _resetBoard(hard: true);
  }

  @override
  void dispose() {
    _toastTimer?.cancel();
    super.dispose();
  }

  // ===== Game logic =====

  void _resetBoard({required bool hard}) {
    grid = List.generate(rows, (_) => List<BigInt?>.filled(cols, null));
    _initFirstBoard();
    _clearPath();
    if (hard) {
      score = BigInt.zero;
      levelIdx = 1;
      diamonds = 0;
    }
    _recalcBest();
    setState(() {});
  }

  void _initFirstBoard() {
    // Board on first open must contain 2,4,8,16,32,64 blocks.
    // We keep the board full (current game style) but guarantee at least one of each.
    final required = <BigInt>[
      BigInt.from(2),
      BigInt.from(4),
      BigInt.from(8),
      BigInt.from(16),
      BigInt.from(32),
      BigInt.from(64),
    ];

    final allPositions = <Pos>[];
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        allPositions.add(Pos(r, c));
      }
    }
    allPositions.shuffle(_rng);

    // Place required values first.
    for (int i = 0; i < required.length && i < allPositions.length; i++) {
      final p = allPositions[i];
      grid[p.r][p.c] = required[i];
    }

    // Fill the rest using the smart spawn pool (Phase 1).
    for (int i = required.length; i < allPositions.length; i++) {
      final p = allPositions[i];
      grid[p.r][p.c] = _spawnTile();
    }
  }

  BigInt _spawnTile() {
    // Smart spawn rules:
    // - Until 2048 is reached: max spawn = 64
    // - When 2048 is reached: remove 2, max spawn = 128
    // - When 4096 is reached: remove 4, min becomes 8, max spawn = 256
    // - Continues similarly: each milestone removes the smallest spawn and increases max.
    final m = _maxOnBoard();
    final int maxPowReached = m <= BigInt.zero ? 1 : (m.bitLength - 1);

    int minPow = 1; // 2
    if (maxPowReached >= 11) {
      // Reached at least 2048 (2^11)
      minPow = max(2, maxPowReached - 9); // 2048->4, 4096->8, 8192->16 ...
    }
    final int maxPow = minPow + 5; // keep pool width stable

    // Weighted selection favouring smaller values.
    final roll = _rng.nextDouble();
    int pow;
    if (roll < 0.70) {
      pow = minPow;
    } else if (roll < 0.92) {
      pow = minPow + 1;
    } else if (roll < 0.985) {
      pow = minPow + 2;
    } else {
      pow = minPow + 3;
    }
    pow = pow.clamp(minPow, maxPow);
    return BigInt.one << pow;
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


  Pos? _hitTestPos(Offset local, double cellSize, double gap) {
    final span = cellSize + gap;
    int c = ((local.dx + gap / 2) / span).floor();
    int r = ((local.dy + gap / 2) / span).floor();
    if (r < 0 || r >= rows || c < 0 || c >= cols) return null;
    return Pos(r, c);
  }


void _clearPath() {
  _path.clear();
  _pathColors.clear();
  _dragging = false;
  _baseValue = null;
  _baseCount = 0;
  _armed = false;
  _stageValue = null;
    _stageCount = 0;
}

BigInt? _valueAt(Pos p) => _inBounds(p) ? grid[p.r][p.c] : null;

Color _chainColorForStep(int step) {
  const palette = <Color>[
    Color(0xFF7AA7FF),
    Color(0xFF7FE3C3),
    Color(0xFFFFC58A),
    Color(0xFFD7A8FF),
    Color(0xFFFF9FB3),
    Color(0xFFA9E2FF),
    Color(0xFFCBEA8D),
    Color(0xFFF2E38B),
  ];
  return palette[step % palette.length].withOpacity(0.78);
}

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
  _armed = false;
  _stageValue = null;
  _stageCount = 0;
  _lastValue = v;

  _path.add(p);
  _pathColors.add(_chainColorForIndex(0));
  setState(() {});
}

void _onCellEnter(Pos p) {
  if (_path.isEmpty) return;
  if (!_inBounds(p)) return;
  if (_path.contains(p)) return;

  final last = _path.last;
  if (!_isNeighbor8(last, p)) return;

  final v = _valueAt(p);
  if (v == null) return;

  // Rule:
  // - First, we must form a base pair: the first two picks must be the same value.
  // - After the base pair is formed, every next pick must be either:
  //   * same as the last picked value, OR
  //   * exactly double the last picked value.
  if (!_armed) {
    if (_baseValue == null) return;
    if (v != _baseValue) return;

    _path.add(p);
    _pathColors.add(_chainColorForIndex(_path.length - 1));
    _baseCount++;

    if (_baseCount >= 2) {
      _armed = true;
      _lastValue = v;
    }
    setState(() {});
    return;
  }

  final lv = _lastValue ?? _baseValue!;
  if (v == lv || v == (lv << 1)) {
    _path.add(p);
    _pathColors.add(_chainColorForIndex(_path.length - 1));
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

  final vals = <BigInt>[];
  final pos = <Pos>[];
  for (final p in chain) {
    final v = _valueAt(p);
    if (v == null) break;
    vals.add(v);
    pos.add(p);
  }
  if (vals.length < 2) {
    _clearPath();
    return;
  }

  // Stack-merge simulation on the selected sequence.
  // We only commit the *longest prefix* that collapses into a single value.
  final stack = <BigInt>[];
  int bestN = 0;
  BigInt bestMerged = BigInt.zero;
  BigInt bestScoreAdd = BigInt.zero;
  int bestMerges = 0;

  BigInt scoreAcc = BigInt.zero;
  int mergesAcc = 0;

  for (int i = 0; i < vals.length; i++) {
    stack.add(vals[i]);
    // Merge while top two equal
    while (stack.length >= 2 && stack[stack.length - 1] == stack[stack.length - 2]) {
      final v = stack.removeLast();
      stack.removeLast();
      final nv = v << 1;
      stack.add(nv);
      scoreAcc += nv;
      mergesAcc += 1;
    }
    if (i >= 1 && stack.length == 1) {
      bestN = i + 1;
      bestMerged = stack.single;
      bestScoreAdd = scoreAcc;
      bestMerges = mergesAcc;
    }
  }

  // Need at least 1 merge (2 tiles).
  if (bestN < 2) {
    _clearPath();
    setState(() {});
    return;
  }

  // Clear used tiles
  for (int i = 0; i < bestN; i++) {
    final p = pos[i];
    grid[p.r][p.c] = null;
  }

  final targetPos = pos[bestN - 1];
  grid[targetPos.r][targetPos.c] = bestMerged;

  score += bestScoreAdd;
  _recalcBest();

  _clearPath();
  _cascadeFrom(targetPos);
  _collapseAndFill();

  _handleCombo(bestMerges);
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
    if (merges < 5) return;

    String msg;
    if (merges >= 11) {
      diamonds += 1;
      msg = lang == AppLang.de
          ? 'MEGA KOMBO! +1 💎'
          : (lang == AppLang.tr ? 'MUHTEŞEM KOMBO! +1 💎' : 'MEGA COMBO! +1 💎');
    } else if (merges >= 8) {
      msg = lang == AppLang.de
          ? 'TOLLE KOMBO!'
          : (lang == AppLang.tr ? 'HARİKA KOMBO!' : 'AWESOME COMBO!');
    } else {
      msg = lang == AppLang.de
          ? 'SUPER KOMBO!'
          : (lang == AppLang.tr ? 'SÜPER KOMBO!' : 'SUPER COMBO!');
    }
    _showToast(msg);
  }

  void _maybeShowNextLevelReward() {
    // Phase 2 rewarded flow is not wired in this DartPad-safe build.
    // Kept as no-op so we don't break existing call sites.
  }

  void _saveGame() {
    // Persistence is disabled in DartPad. In the full app you can wire this to
    // SharedPreferences without changing call sites.
  }

  void _checkGoalAndMaybeAdvance() {
    // Phase 1: level increases when reaching targets (2048, 4096, 8192 ...).
    // No automatic diamond reward here (rewarded flow will be Phase 2).
    while (true) {
      final goal = _goalForLevel(levelIdx);
      final curMax = _maxOnBoard();
      if (curMax >= goal) {
        levelIdx += 1;
        _showToast('LEVEL UP → $levelIdx');
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
      _swapFirst = null;
      _showToast('-10 💎');
    } else {
      swapMode = false;
      _swapFirst = null;
    }
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
    setState(() {});
  }

  void _watchAdReward() {
    diamonds += 10;
    _showToast('+10 💎');
    setState(() {});
  }

  // ===== UI helpers =====

  void _showToast(String msg) {
    _toastTimer?.cancel();
    setState(() => _toast = msg);
    _toastTimer = Timer(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      setState(() => _toast = null);
    });
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
      const Color(0xFF264653), // deep teal
      const Color(0xFF2A4D69), // muted blue
      const Color(0xFF4B3F72), // muted purple
      const Color(0xFF556B2F), // olive
      const Color(0xFF8D7B68), // warm taupe
      const Color(0xFF7A4E3A), // terracotta
      const Color(0xFF5B6770), // slate
      const Color(0xFF3D5A80), // steel blue
    ];
    return hues[p % hues.length];
  }


  Color _chainColorForIndex(int idx) {
    // Muted neon-ish colors for the chain line; changes per added block.
    final double hue = (200 + (idx * 37)) % 360;
    final hsv = HSVColor.fromAHSV(0.70, hue, 0.55, 0.95);
    return hsv.toColor();
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
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.55),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.18)),
                    ),
                    child: Text(_toast!, style: _neon(14)),
                  ),
                ),
              ),
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
        margin: const EdgeInsets.fromLTRB(14, 0, 14, 10),
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
              Text(_fmtBig(score), style: _neon(34, opacity: 0.98)),
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

  Widget _pill({required Widget child}) {
    return Container(
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
        final boardW = min(constraints.maxWidth, 430.0) * 0.96;
        final gap = kGap;
        final cellSize = (boardW - (cols - 1) * gap) / cols;
        final boardH = rows * cellSize + (rows - 1) * gap;

        return Center(
          child: SizedBox(
            width: boardW,
            height: boardH,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanStart: (d) {
                final p = _hitTestPos(d.localPosition, cellSize, gap);
                if (p != null) _onCellDown(p);
              },
              onPanUpdate: (d) {
                final p = _hitTestPos(d.localPosition, cellSize, gap);
                if (p != null) _onCellEnter(p);
              },
              onPanEnd: (_) => _onCellUp(),
              onPanCancel: _onCellUp,
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
                  
                  // Vanish FX for consumed tiles
                  for (final fx in _vanishFx)
                    Positioned(
                      left: fx.pos.c * (cellSize + gap),
                      top: fx.pos.r * (cellSize + gap),
                      width: cellSize,
                      height: cellSize,
                      child: IgnorePointer(
                        child: TweenAnimationBuilder<double>(
                          key: ValueKey('van_${fx.pos.r}_${fx.pos.c}_${fx.tick}'),
                          tween: Tween<double>(begin: 1.0, end: 0.0),
                          duration: const Duration(milliseconds: 280),
                          curve: Curves.easeIn,
                          builder: (context, t, _) {
                            return Opacity(
                              opacity: t.clamp(0.0, 1.0),
                              child: Transform.scale(
                                scale: 0.85 + 0.15 * t,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: _tileColor(fx.value).withOpacity(0.35),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
if (_path.length >= 2)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: CustomPaint(
                          painter: _NeonPathPainter(points: _path.toList(), colors: _pathColors.toList(), cellSize: cellSize, gap: gap),
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

  Widget _cellWidget(Pos p, double size) {
  final v = grid[p.r][p.c];
  final selected = _path.contains(p);
  final isSwapFirst = (swapMode && _swapFirst == p);

  final steps = _fallSteps[p] ?? 0;
  final beginDy = steps <= 0 ? 0.0 : -(steps * (size + kGap));

  final baseColor = v == null ? Colors.white.withOpacity(0.05) : _tileColor(v).withOpacity(0.92);
  final top = _lighten(baseColor, 0.08);
  final bottom = _darken(baseColor, 0.16);

  return Listener(
    onPointerDown: (_) => _onCellDown(p),
    onPointerMove: (_) => _onCellEnter(p),
    onPointerUp: (_) => _onCellUp(),
    child: TweenAnimationBuilder<double>(
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
    ),
  );
}


  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
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
              sub: '10 💎',
              active: swapMode,
              onTap: _toggleSwap,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _actionButton(
              icon: hammerMode ? Icons.close : Icons.gavel,
              label: t('hammer'),
              sub: '7 💎',
              active: hammerMode,
              onTap: _toggleHammer,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _actionButton(
              icon: Icons.smart_display,
              label: t('watchAd'),
              sub: '+10 💎',
              active: false,
              onTap: _watchAdReward,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _actionButton(
              icon: Icons.shopping_cart,
              label: t('shop'),
              sub: '',
              active: false,
              onTap: _openShopSheet,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _actionButton(
              icon: Icons.pause,
              label: t('pause'),
              sub: '',
              active: false,
              onTap: _openPauseDialog,
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required String sub,
    required bool active,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: active
                ? [Colors.white.withOpacity(0.18), Colors.white.withOpacity(0.08)]
                : [Colors.white.withOpacity(0.12), Colors.white.withOpacity(0.05)],
          ),
          border: Border.all(color: Colors.white.withOpacity(active ? 0.22 : 0.10)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.35), blurRadius: 14, offset: const Offset(0, 10))],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 22, color: Colors.white.withOpacity(0.95)),
            const SizedBox(height: 6),
            Text(label, style: TextStyle(color: Colors.white.withOpacity(0.95), fontSize: 11, fontWeight: FontWeight.w900)),
            if (sub.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(sub, style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 10, fontWeight: FontWeight.w800)),
            ],
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
                'Not: Bu sayfa şimdilik “test purchase” gibi çalışır. Gerçek IAP entegrasyonunu istersen ekleriz.',
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
                    ButtonSegment(value: AppLang.tr, label: Text('TR')),
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
