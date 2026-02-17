import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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
  static const double kBannerHeight = 60.0; // fixed banner height (Phase 1)

  final Random _rng = Random();

  late List<List<BigInt?>> grid;

  int levelIdx = 1; // Level 1 starts
  BigInt score = BigInt.zero;
  BigInt best = BigInt.zero;
  int diamonds = 0; // starts with 0 diamonds

  // ===== Phase 2: combo + reward animation anchors =====
  final GlobalKey _diamondKey = GlobalKey();
  final GlobalKey _boardKey = GlobalKey();
  bool _levelRewardDialogOpen = false;
  final List<BigInt> _pendingLevelRewards = [];

  bool swapMode = false;
  bool hammerMode = false;
  Pos? _swapFirst;

  final List<Pos> _path = [];
  BigInt? _pathValue;
  int _segmentCount = 0; // tiles selected in the current value segment
  bool _dragging = false;

  // Gravity fall animation for moved/spawned tiles
  final Map<Pos, int> _fallSteps = <Pos, int>{};
  int _fallTick = 0;

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

'superCombo': 'Super Combo',
'greatCombo': 'Great Combo',
'megaCombo': 'Mega Combo',
'rewardTitle': 'Level Reward',
'rewardCta': 'Watch ad → Get reward',
'noThanks': 'No thanks',
'watchingAd': 'Watching ad…',
'rewardGranted': 'Reward granted!',
    'noMerge': 'No merge',
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

'superCombo': 'Super-Kombo',
'greatCombo': 'Großartige Kombo',
'megaCombo': 'Mega-Kombo',
'rewardTitle': 'Level-Belohnung',
'rewardCta': 'Werbung ansehen → Belohnung',
'noThanks': 'Nein danke',
'watchingAd': 'Werbung läuft…',
'rewardGranted': 'Belohnung erhalten!',
    'noMerge': 'Kein Merge',
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

'superCombo': 'Süper Kombo',
'greatCombo': 'Harika Kombo',
'megaCombo': 'Muhteşem Kombo',
'rewardTitle': 'Seviye Ödülü',
'rewardCta': 'Reklam izle → Ödül al',
'noThanks': 'Hayır',
'watchingAd': 'Reklam izleniyor…',
'rewardGranted': 'Ödül alındı!',
    'noMerge': 'Birleşme yok',
  };

  String t(String key) {
    final dict = switch (lang) {
      AppLang.de => _de,
      AppLang.tr => _tr,
      AppLang.en => _en,
    };
    return dict[key] ?? key;
  }

  
  static const String _kPrefsKey = 'merge_blocks_save_v1';

  Future<void> _loadGame() async {
    try {
      grid = List.generate(rows, (_) => List<BigInt?>.filled(cols, null));
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kPrefsKey);
      if (raw == null || raw.isEmpty) {
        _resetBoard(hard: true);
                    _clearSavedGame();
        return;
      }
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final savedRows = (map['rows'] as int?) ?? rows;
      final savedCols = (map['cols'] as int?) ?? cols;
      if (savedRows != rows || savedCols != cols) {
        _resetBoard(hard: true);
                    _clearSavedGame();
        return;
      }

      final gridList = (map['grid'] as List?) ?? const [];
      for (int r = 0; r < rows; r++) {
        for (int c = 0; c < cols; c++) {
          BigInt? v;
          if (r < gridList.length) {
            final row = gridList[r];
            if (row is List && c < row.length) {
              final cell = row[c];
              if (cell is String && cell.isNotEmpty) {
                v = BigInt.tryParse(cell);
              } else if (cell is int) {
                v = BigInt.from(cell);
              }
            }
          }
          grid[r][c] = v;
        }
      }

      score = BigInt.tryParse(map['score']?.toString() ?? '') ?? BigInt.zero;
      diamonds = (map['diamonds'] as int?) ?? 0;
      levelIdx = (map['level'] as int?) ?? 1;

      final langStr = map['lang']?.toString();
      if (langStr == 'de') lang = AppLang.de;
      if (langStr == 'en') lang = AppLang.en;

      _recalcBest();
      // Spawn is derived from the current max tile, so no extra state is required.
      _updateSpawnCapsFromMax();
      setState(() {});
    } catch (_) {
      _resetBoard(hard: true);
                    _clearSavedGame();
    }
  }

  // Kept for backward compatibility with older saves/versions.
  // Spawn pool is computed on demand from the max tile, so this is intentionally a no-op.
  void _updateSpawnCapsFromMax() {}

  Future<void> _saveGame() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final gridOut = [
        for (int r = 0; r < rows; r++)
          [
            for (int c = 0; c < cols; c++)
              grid[r][c]?.toString(),
          ],
      ];
      final map = <String, dynamic>{
        'rows': rows,
        'cols': cols,
        'grid': gridOut,
        'score': score.toString(),
        'diamonds': diamonds,
        'level': levelIdx,
        'lang': lang.name,
      };
      await prefs.setString(_kPrefsKey, jsonEncode(map));
    } catch (_) {
      // ignore
    }
  }

  Future<void> _clearSavedGame() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kPrefsKey);
    } catch (_) {}
  }

@override
  void initState() {
    super.initState();
    _loadGame();
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
    _saveGame();
  }

  void _initFirstBoard() {
    // Opening board must be FULL (no empty cells) and contain ONLY:
    // 2, 4, 8, 16, 32, 64. Also guarantee at least one of each value.
    const allowedInts = <int>[2, 4, 8, 16, 32, 64];
    final allowed = allowedInts.map(BigInt.from).toList(growable: false);

    final totalCells = rows * cols;
    final tiles = <BigInt>[];
    tiles.addAll(allowed); // guarantee at least one of each

    while (tiles.length < totalCells) {
      tiles.add(allowed[_rng.nextInt(allowed.length)]);
    }
    tiles.shuffle(_rng);

    int idx = 0;
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        grid[r][c] = tiles[idx++];
      }
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

  void _clearPath() {
    _path.clear();
    _pathValue = null;
    _segmentCount = 0;
    _dragging = false;
  }

  void _onCellDown(Pos p) {
    if (!_inBounds(p)) return;
    final v = grid[p.r][p.c];
    if (v == null) return;

    if (swapMode) {
      _handleSwapTap(p);
      return;
    }
    if (hammerMode) {
      _handleHammerTap(p);
      return;
    }

    _dragging = true;
    _path.clear();
    _path.add(p);
    _pathValue = v;
    _segmentCount = 1;
    setState(() {});
  }

  void _onCellEnter(Pos p) {
    if (!_dragging) return;
    if (!_inBounds(p)) return;

    if (_path.isNotEmpty && _path.last == p) return;

    // Backtrack one step if the user drags back onto the previous cell.
    if (_path.length >= 2 && _path[_path.length - 2] == p) {
      _path.removeLast();
      _recomputePathTailState();
      setState(() {});
      return;
    }

    // If the pointer "skips" cells (fast swipe), interpolate step-by-step so
    // long drags across rows/cols/diagonals still build a continuous chain.
    if (_path.isNotEmpty && !_isNeighbor8(_path.last, p)) {
      Pos cur = _path.last;
      while (cur != p) {
        final dr = (p.r - cur.r).clamp(-1, 1);
        final dc = (p.c - cur.c).clamp(-1, 1);
        final next = Pos(cur.r + dr, cur.c + dc);
        if (next == cur) break;

        // Allow backtracking during interpolation as well.
        if (_path.length >= 2 && _path[_path.length - 2] == next) {
          _path.removeLast();
          _recomputePathTailState();
          cur = _path.last;
          continue;
        }

        if (!_tryAppend(next)) break;
        cur = next;
      }
      setState(() {});
      return;
    }

    // Normal neighbor append.
    if (!_tryAppend(p)) return;
    setState(() {});
  }

  bool _tryAppend(Pos p) {
    if (!_inBounds(p)) return false;
    if (_path.isEmpty) return false;
    if (_path.last == p) return false;
    if (_path.contains(p)) return false;

    if (!_isNeighbor8(_path.last, p)) return false;

    final v = grid[p.r][p.c];
    if (v == null) return false;

    final cur = _pathValue;
    if (cur == null) return false;

    // Rule:
    // - You can extend the current value segment with unlimited same-value tiles.
    // - You can advance to exactly the next value (x2) only after selecting at least
    //   2 tiles of the current value consecutively (i.e., current segment has a pair).
    if (v == cur) {
      _path.add(p);
      _segmentCount += 1;
      return true;
    }

    if (v == cur * BigInt.from(2) && _segmentCount >= 2) {
      _path.add(p);
      _pathValue = v;
      _segmentCount = 1;
      return true;
    }

    return false;
  }

  void _recomputePathTailState() {
    if (_path.isEmpty) {
      _pathValue = null;
      _segmentCount = 0;
      return;
    }
    final last = _path.last;
    final lastV = grid[last.r][last.c];
    if (lastV == null) {
      _pathValue = null;
      _segmentCount = 0;
      return;
    }

    // Current segment is the run of identical values at the tail of the path.
    _pathValue = lastV;
    int cnt = 1;
    for (int i = _path.length - 2; i >= 0; i--) {
      final pv = grid[_path[i].r][_path[i].c];
      if (pv == lastV) {
        cnt += 1;
      } else {
        break;
      }
    }
    _segmentCount = cnt;
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
      if (chain.length < 2) return;

      // Read values along the dragged chain (must be occupied).
      final values = <BigInt>[];
      for (final p in chain) {
        final v = grid[p.r][p.c];
        if (v == null) return;
        values.add(v);
      }

      // Resolve merges IN ORDER using a stack.
      // IMPORTANT CHANGE:
      // - We no longer require the entire chain to collapse into a single tile.
      // - Any chain that respects the selection rules will produce one or more resulting tiles.
      //   (Example: 2-2-2 -> [2,4], 2-2-2-2-2-2 -> [4,8], etc.)
      final stack = <BigInt>[];
      int mergeOps = 0;
      BigInt gained = BigInt.zero;

      for (final v in values) {
        stack.add(v);
        while (stack.length >= 2) {
          final a = stack[stack.length - 1];
          final b = stack[stack.length - 2];
          if (a != b) break;
          stack.removeLast();
          stack.removeLast();
          final merged = a << 1;
          stack.add(merged);
          mergeOps += 1;
          gained += merged;
        }
      }

      if (mergeOps == 0) {
        _showToast(t('noMerge'));
        _clearPath();
        setState(() {});
        return;
      }

      // Sort results so the largest tile ends up at the end of the dragged chain.
      stack.sort((a, b) => a.compareTo(b));
      final k = stack.length;

      // Clear all selected cells first.
      for (final p in chain) {
        grid[p.r][p.c] = null;
      }

      // Place the resulting tiles into the tail of the chain.
      // Example: chain length 5, results length 2 -> write to positions 3 and 4.
      for (int i = 0; i < k; i++) {
        final pos = chain[chain.length - k + i];
        grid[pos.r][pos.c] = stack[i];
      }

      // Score: add sum of merged results (not raw remaining tiles).
      score += gained;

      _recalcBest();

      // Collapse the board (gravity) and then spawn into empties.
      _collapseAndFill();

      _handleCombo(mergeOps);
      _checkGoalAndMaybeAdvance();
      _maybeShowNextLevelReward();
      _saveGame();

      _clearPath();
      setState(() {});
    }

  int _cascadeFrom(Pos start) {
    // Chain merge (no collapse during cascade):
    // While the tile has an equal neighbour (8-direction), merge pairwise into this tile.
    int merges = 0;
    Pos cur = start;
    while (true) {
      final v = grid[cur.r][cur.c];
      // If the starting tile disappeared (shouldn't happen), stop and return merges so far.
      if (v == null) return merges;
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
      // No more equal neighbours -> cascade ends.
      if (neighborSame == null) break;

      grid[neighborSame.r][neighborSame.c] = null;
      final newV = v * BigInt.from(2);
      grid[cur.r][cur.c] = newV;
      score += newV;
      merges += 1;
      _recalcBest();
    }

    return merges;
  }


  void _collapseAndFill() {
    // Build a new grid applying gravity, while recording how many rows each tile fell.
    final old = grid;
    final newGrid = List.generate(rows, (_) => List<BigInt?>.filled(cols, null));
    _fallSteps.clear();

    for (int c = 0; c < cols; c++) {
      // Collect tiles from bottom to top.
      final tiles = <({BigInt v, int fromR})>[];
      for (int r = rows - 1; r >= 0; r--) {
        final v = old[r][c];
        if (v != null) tiles.add((v: v, fromR: r));
      }

      // Place them bottom-aligned in the new grid.
      int writeR = rows - 1;
      for (final t in tiles) {
        newGrid[writeR][c] = t.v;
        final steps = t.fromR - writeR;
        if (steps != 0) {
          _fallSteps[Pos(writeR, c)] = steps.abs();
        }
        writeR -= 1;
      }

      // Spawn remaining cells at the top, as if they fall from above the board.
      for (int r = writeR; r >= 0; r--) {
        newGrid[r][c] = _spawnTile();
        // Larger steps = feels like it falls from outside.
        _fallSteps[Pos(r, c)] = (writeR - r + 2);
      }
    }

    grid = newGrid;
    _fallTick++;
  }

  void _checkGoalAndMaybeAdvance() {
  // Level system: 2048 -> Level 1 complete, 4096 -> Level 2, 8192 -> Level 3 ...
  // On each level transition, we enqueue a rewarded popup (Phase 2).
  while (true) {
    final goal = _goalForLevel(levelIdx);
    final curMax = _maxOnBoard();
    if (curMax >= goal) {
      // Enqueue reward: one block of (goal / 2)
      _pendingLevelRewards.add(goal ~/ BigInt.from(2));
      levelIdx += 1;
      _showToast('LEVEL UP → $levelIdx');
      continue;
    }
    break;
  }
}

  
// ===== Phase 2: Combo + Level Reward =====
void _handleCombo(int merges) {
  if (merges <= 0) return;

  String? label;
  if (merges >= 11) {
    label = t('megaCombo');
  } else if (merges >= 8) {
    label = t('greatCombo');
  } else if (merges >= 5) {
    label = t('superCombo');
  }

  if (label != null) {
    _showToast('$label ×$merges');
  }

  if (merges >= 11) {
    diamonds += 1;
    _flyDiamondToBox();
  }
}

void _flyDiamondToBox() {
  final overlay = Overlay.maybeOf(context);
  if (overlay == null) return;

  final boardBox = _boardKey.currentContext?.findRenderObject() as RenderBox?;
  final diamondBox = _diamondKey.currentContext?.findRenderObject() as RenderBox?;
  if (boardBox == null || diamondBox == null) return;

  final start = boardBox.localToGlobal(boardBox.size.center(Offset.zero));
  final end = diamondBox.localToGlobal(diamondBox.size.center(Offset.zero));

  late final OverlayEntry entry;
  final controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 650));
  final tween = Tween<Offset>(begin: start, end: end)
      .animate(CurvedAnimation(parent: controller, curve: Curves.easeInOutCubic));
  final scale = Tween<double>(begin: 1.3, end: 0.6)
      .animate(CurvedAnimation(parent: controller, curve: Curves.easeInOut));

  entry = OverlayEntry(
    builder: (context) {
      return AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          final p = tween.value;
          return Positioned(
            left: p.dx - 14,
            top: p.dy - 14,
            child: Transform.scale(
              scale: scale.value,
              child: Icon(Icons.star, size: 28, color: Colors.amber.withOpacity(0.95)),
            ),
          );
        },
      );
    },
  );

  overlay.insert(entry);
  controller.forward().whenComplete(() {
    entry.remove();
    controller.dispose();
    _showToast('+1 💎');
    setState(() {});
  });
}

void _maybeShowNextLevelReward() {
  if (_levelRewardDialogOpen) return;
  if (_pendingLevelRewards.isEmpty) return;
  _levelRewardDialogOpen = true;
  final reward = _pendingLevelRewards.removeAt(0);
  _showLevelRewardDialog(reward).whenComplete(() {
    _levelRewardDialogOpen = false;
    _maybeShowNextLevelReward();
  });
}

Future<void> _showLevelRewardDialog(BigInt rewardValue) async {
  final accepted = await showDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (context) {
      return AlertDialog(
        backgroundColor: const Color(0xFF0B1546),
        title: Text(t('rewardTitle'), style: _neon(18)),
        content: Text(
          '${t('rewardCta')}\n\n+${_fmtBig(rewardValue)}',
          style: _neon(14, opacity: 0.9),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(t('noThanks')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(t('rewardCta')),
          ),
        ],
      );
    },
  );

  if (accepted == true) {
    await _showFakeRewardedAd();
    _grantLevelRewardBlock(rewardValue);
    _showToast(t('rewardGranted'));
    setState(() {});
  }
}

Future<void> _showFakeRewardedAd() async {
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      return Dialog(
        backgroundColor: const Color(0xFF0B1546),
        insetPadding: const EdgeInsets.all(26),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(t('watchingAd'), style: _neon(16)),
              const SizedBox(height: 16),
              const SizedBox(height: 36, width: 36, child: CircularProgressIndicator()),
            ],
          ),
        ),
      );
    },
  ).timeout(const Duration(milliseconds: 1400), onTimeout: () {
    Navigator.of(context, rootNavigator: true).maybePop();
  });
}

void _grantLevelRewardBlock(BigInt rewardValue) {
  Pos? minPos;
  BigInt? minVal;
  for (int r = 0; r < rows; r++) {
    for (int c = 0; c < cols; c++) {
      final v = grid[r][c];
      if (v == null) continue;
      if (minVal == null || v < minVal) {
        minVal = v;
        minPos = Pos(r, c);
      }
    }
  }
  if (minPos == null) {
    grid[rows - 1][cols ~/ 2] = rewardValue;
    return;
  }
  grid[minPos.r][minPos.c] = rewardValue;
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
    // Plain numeric rendering (no suffix letters like "2a").
    final s = n.toString();
    // Add thousands separators for readability.
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      final posFromEnd = s.length - i;
      buf.write(s[i]);
      if (posFromEnd > 1 && posFromEnd % 3 == 1) {
        buf.write(',');
      }
    }
    return buf.toString();
  }

  Color _shade(Color c, double lightnessDelta) {
    final hsl = HSLColor.fromColor(c);
    final l = (hsl.lightness + lightnessDelta).clamp(0.0, 1.0);
    return hsl.withLightness(l).toColor();
  }

  Color _tileColor(BigInt v) {
    final int p = (v.bitLength - 1).clamp(0, 30);
        final hues = <Color>[
      // Muted, distinct palette (less eye-strain than neon).
      const Color(0xFF5568B3), // muted indigo
      const Color(0xFF4B8BBE), // muted blue
      const Color(0xFF2F8F83), // muted teal
      const Color(0xFF5A8F4E), // muted green
      const Color(0xFF9B8B3C), // muted olive
      const Color(0xFFB07A3F), // muted amber
      const Color(0xFFA85A4A), // muted terracotta
      const Color(0xFF9A4E7C), // muted magenta
      const Color(0xFF6E5A8F), // muted purple
      const Color(0xFF4F6A72), // muted slate
    ];
    return hues[p % hues.length];
  }

  
  String _scoreLabel() {
    // Score is accumulated as raw merge-sum. Display rule:
    // - Until reaching 1 point (1000), show raw value.
    // - From 1000+, show points = raw/1000 with 1 decimal.
    final raw = score;
    if (raw < BigInt.from(1000)) return raw.toString();
    final ten = (raw * BigInt.from(10)) ~/ BigInt.from(1000); // points * 10
    final intPart = ten ~/ BigInt.from(10);
    final frac = (ten % BigInt.from(10)).toInt();
    if (frac == 0) return intPart.toString();
    return '${intPart.toString()}.$frac';
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
                Expanded(child: _buildBoard(key: _boardKey)),
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
              KeyedSubtree(
                key: _diamondKey,
                child: _pill(
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
              )
              ),
              const Spacer(),
              Text(_scoreLabel(), style: _neon(34, opacity: 0.98)),
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

  Widget _buildBoard({Key? key}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final boardW = min(constraints.maxWidth, 430.0);
        const gap = 10.0;
        final cellSize = (boardW - (cols - 1) * gap) / cols;
        final boardH = rows * cellSize + (rows - 1) * gap;

        Pos? posFromLocal(Offset local) {
          final x = local.dx;
          final y = local.dy;
          if (x < 0 || y < 0 || x > boardW || y > boardH) return null;
          final step = cellSize + gap;
          final c = (x / step).floor();
          final r = (y / step).floor();
          if (r < 0 || r >= rows || c < 0 || c >= cols) return null;

          // Ignore touches inside the gap area between cells.
          final dxIn = x - c * step;
          final dyIn = y - r * step;
          if (dxIn > cellSize || dyIn > cellSize) return null;

          return Pos(r, c);
        }

        void handleDown(Offset local) {
          final p = posFromLocal(local);
          if (p == null) return;
          _onCellDown(p);
        }

        void handleMove(Offset local) {
          final p = posFromLocal(local);
          if (p == null) return;
          _onCellEnter(p);
        }

        return Center(
          child: SizedBox(
            key: key,
            width: boardW,
            height: boardH,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanStart: (d) => handleDown(d.localPosition),
              onPanUpdate: (d) => handleMove(d.localPosition),
              onPanEnd: (_) => _onCellUp(),
              onPanCancel: _onCellUp,
              onTapDown: (d) => handleDown(d.localPosition),
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
                        child: _cellWidget(Pos(r, c), cellSize, gap),
                      ),
                  if (_path.length >= 2)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: CustomPaint(
                          painter: _NeonPathPainter(
                            points: _path,
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

Widget _cellWidget(Pos p, double size, double gap) {
    final v = grid[p.r][p.c];
    final selected = _path.contains(p);
    final isSwapFirst = (swapMode && _swapFirst == p);
    final fall = _fallSteps[p] ?? 0;

    final tile = AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        // 3D-ish look: subtle gradient + inner highlight, muted colors
        gradient: v == null
            ? null
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  _tileColor(v).withOpacity(0.92),
                  _tileColor(v).withOpacity(0.78),
                ],
              ),
        color: v == null ? Colors.white.withOpacity(0.05) : null,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: (selected || isSwapFirst) ? Colors.white.withOpacity(0.90) : Colors.white.withOpacity(0.12),
          width: (selected || isSwapFirst) ? 2 : 1,
        ),
        boxShadow: [
          // Outer shadow
          BoxShadow(
            color: Colors.black.withOpacity(selected ? 0.50 : 0.32),
            blurRadius: selected ? 18 : 14,
            offset: const Offset(0, 10),
          ),
          // Soft highlight (fake inner bevel)
          if (v != null)
            BoxShadow(
              color: Colors.white.withOpacity(0.10),
              blurRadius: 0,
              spreadRadius: 0,
              offset: const Offset(-2, -2),
            ),
        ],
      ),
      child: Stack(
        children: [
          if (v != null)
            Positioned(
              left: 10,
              top: 10,
              right: 10,
              child: Container(
                height: 10,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withOpacity(0.18),
                      Colors.white.withOpacity(0.02),
                    ],
                  ),
                ),
              ),
            ),
          Center(
            child: v == null
                ? const SizedBox.shrink()
                : Text(
                    v.toString(), // ONLY number, no suffix
                    style: _neon(size * 0.26, opacity: 0.96),
                  ),
          ),
        ],
      ),
    );

    Widget animated = tile;

    // Gravity fall: new/moved tiles "drop" into place from above with a soft bounce.
    if (fall > 0) {
      final dy = -(fall.toDouble() * (size + gap));
      animated = TweenAnimationBuilder<double>(
        key: ValueKey('fall_${p.r}_${p.c}_${v?.toString() ?? "null"}_$_fallTick'),
        tween: Tween<double>(begin: dy, end: 0),
        duration: Duration(milliseconds: min(520, 220 + fall * 60)),
        curve: Curves.easeOutBack,
        builder: (context, y, child) => Transform.translate(offset: Offset(0, y), child: child),
        child: tile,
      );
    }

    return Listener(
      onPointerDown: (_) => _onCellDown(p),
      onPointerMove: (_) => _onCellEnter(p),
      onPointerUp: (_) => _onCellUp(),
      child: animated,
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
                      _saveGame();
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
                              borderRadius: BorderRadius.circular(12),
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
                    ButtonSegment(value: AppLang.en, label: Text('EN')),
                    ButtonSegment(value: AppLang.de, label: Text('DE')),
                  ],
                  selected: {lang},
                  onSelectionChanged: (s) {
                    setState(() => lang = s.first);
                    _saveGame();
                  },
                ),
              ),
              const SizedBox(height: 10),
              _settingsRow(
                title: 'Reset',
                child: FilledButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _resetBoard(hard: true);
                    _clearSavedGame();
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
                    _clearSavedGame();
            },
            child: Text(t('restart')),
          ),
        ],
      ),
    );
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
  final double cellSize;
  final double gap;

  _NeonPathPainter({required this.points, required this.cellSize, required this.gap});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;

    // Simple neon-like stroke (fast, no heavy shaders).
    final glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withOpacity(0.18);

    final core = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withOpacity(0.70);

    Offset center(Pos p) {
      final x = p.c * (cellSize + gap) + cellSize / 2;
      final y = p.r * (cellSize + gap) + cellSize / 2;
      return Offset(x, y);
    }

    final p0 = center(points.first);
    final pathObj = Path()..moveTo(p0.dx, p0.dy);
    for (int i = 1; i < points.length; i++) {
      final pi = center(points[i]);
      pathObj.lineTo(pi.dx, pi.dy);
    }
    canvas.drawPath(pathObj, glow);
    canvas.drawPath(pathObj, core);
  }

  @override
  bool shouldRepaint(covariant _NeonPathPainter oldDelegate) {
    return oldDelegate.points != points || oldDelegate.cellSize != cellSize || oldDelegate.gap != gap;
  }
}
