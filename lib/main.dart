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

  final Random _rng = Random();

  late List<List<BigInt?>> grid;

  int levelIdx = 52;
  BigInt score = BigInt.zero;
  BigInt best = BigInt.zero;
  int diamonds = 979;

  bool swapMode = false;
  bool hammerMode = false;
  Pos? _swapFirst;

  final List<Pos> _path = [];
  BigInt? _pathValue;
  bool _dragging = false;

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
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        grid[r][c] = _spawnTile(levelIdx);
      }
    }
    _clearPath();
    if (hard) {
      score = BigInt.zero;
    }
    _recalcBest();
    setState(() {});
  }

  BigInt _spawnTile(int level) {
    final basePow = max(0, (level ~/ 18) - 1);
    final roll = _rng.nextDouble();
    int pow;
    if (roll < 0.75) {
      pow = basePow;
    } else if (roll < 0.93) {
      pow = basePow + 1;
    } else {
      pow = basePow + 2;
    }
    return BigInt.from(1) << pow;
  }

  BigInt _goalForLevel(int level) {
    final step = max(1, level ~/ 6);
    return BigInt.from(1) << (step + 7);
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
    setState(() {});
  }

  void _onCellEnter(Pos p) {
    if (!_dragging) return;
    if (!_inBounds(p)) return;

    if (_path.isNotEmpty && _path.last == p) return;

    if (_path.length >= 2 && _path[_path.length - 2] == p) {
      _path.removeLast();
      setState(() {});
      return;
    }

    final v = grid[p.r][p.c];
    if (v == null) return;

    if (!_isNeighbor8(_path.last, p)) return;
    if (v != _pathValue) return;
    if (_path.contains(p)) return;

    _path.add(p);
    setState(() {});
  }

  void _onCellUp() {
    if (!_dragging) return;
    _dragging = false;

    if (_path.length >= 2 && _pathValue != null) {
      _applyMergeChain(_path.toList(), _pathValue!);
    } else {
      _clearPath();
      setState(() {});
    }
  }

  void _applyMergeChain(List<Pos> chain, BigInt val) {
    final targetPos = chain.last;
    for (final p in chain) {
      grid[p.r][p.c] = null;
    }
    final merged = val * BigInt.from(2);
    grid[targetPos.r][targetPos.c] = merged;

    score += merged * BigInt.from(max(1, chain.length - 1));
    _recalcBest();

    _clearPath();
    _collapseAndFill();

    _cascadeFrom(targetPos);

    _checkGoalAndMaybeAdvance();
    setState(() {});
  }

  void _cascadeFrom(Pos start) {
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

      grid[neighborSame.r][neighborSame.c] = null;
      final newV = v * BigInt.from(2);
      grid[cur.r][cur.c] = newV;
      score += newV;
      _recalcBest();
      _collapseAndFill();

      cur = _findTileClosest(cur, newV) ?? cur;
    }
  }

  Pos? _findTileClosest(Pos around, BigInt value) {
    Pos? bestPos;
    int bestDist = 1 << 30;
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        if (grid[r][c] == value) {
          final d = (r - around.r).abs() + (c - around.c).abs();
          if (c == around.c && d < bestDist) {
            bestDist = d;
            bestPos = Pos(r, c);
          } else if (bestPos == null && d < bestDist) {
            bestDist = d;
            bestPos = Pos(r, c);
          }
        }
      }
    }
    return bestPos;
  }

  void _collapseAndFill() {
    for (int c = 0; c < cols; c++) {
      final colVals = <BigInt>[];
      for (int r = rows - 1; r >= 0; r--) {
        final v = grid[r][c];
        if (v != null) colVals.add(v);
      }
      int idx = 0;
      for (int r = rows - 1; r >= 0; r--) {
        if (idx < colVals.length) {
          grid[r][c] = colVals[idx++];
        } else {
          grid[r][c] = null;
        }
      }
      for (int r = 0; r < rows; r++) {
        if (grid[r][c] == null) {
          grid[r][c] = _spawnTile(levelIdx);
        }
      }
    }
  }

  void _checkGoalAndMaybeAdvance() {
    final goal = _goalForLevel(levelIdx);
    final curMax = _maxOnBoard();
    if (curMax >= goal) {
      levelIdx += 1;
      diamonds += 10;
      _showToast('+10 💎');
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
    const letters = 'abcdefghijklmnopqrstuvwxyz';
    if (n < BigInt.from(1000)) return '${n}a';
    BigInt x = n;
    int idx = 0;
    while (x >= BigInt.from(1000) && idx < letters.length - 1) {
      x = x ~/ BigInt.from(1000);
      idx++;
    }
    return '${x}${letters[idx]}';
  }

  Color _tileColor(BigInt v) {
    final int p = (v.bitLength - 1).clamp(0, 30);
    final hues = <Color>[
      const Color(0xFF8E24AA),
      const Color(0xFF5E35B1),
      const Color(0xFF3949AB),
      const Color(0xFF1E88E5),
      const Color(0xFF00897B),
      const Color(0xFF43A047),
      const Color(0xFFF9A825),
      const Color(0xFFF57C00),
      const Color(0xFFE53935),
      const Color(0xFFD81B60),
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
                bottom: 98,
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
      bottomNavigationBar: SafeArea(top: false, child: _buildBottomBar()),
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
        final boardW = min(constraints.maxWidth, 430.0);
        final gap = 10.0;
        final cellSize = (boardW - (cols - 1) * gap) / cols;
        final boardH = rows * cellSize + (rows - 1) * gap;

        return Center(
          child: SizedBox(
            width: boardW,
            height: boardH,
            child: GestureDetector(
              onPanEnd: (_) => _onCellUp(),
              onPanCancel: _onCellUp,
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
                  if (_path.length >= 2)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: CustomPaint(
                          painter: _PathPainter(path: _path.toList(), cellSize: cellSize, gap: gap),
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

    return Listener(
      onPointerDown: (_) => _onCellDown(p),
      onPointerMove: (_) => _onCellEnter(p),
      onPointerUp: (_) => _onCellUp(),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: v == null ? Colors.white.withOpacity(0.05) : _tileColor(v).withOpacity(0.92),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: (selected || isSwapFirst) ? Colors.white.withOpacity(0.90) : Colors.white.withOpacity(0.10),
            width: (selected || isSwapFirst) ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(selected ? 0.55 : 0.35),
              blurRadius: selected ? 20 : 14,
              offset: const Offset(0, 10),
            )
          ],
        ),
        child: Center(
          child: v == null ? const SizedBox.shrink() : Text(_fmtBig(v), style: _neon(size * 0.26, opacity: 0.96)),
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

class _PathPainter extends CustomPainter {
  final List<Pos> path;
  final double cellSize;
  final double gap;

  _PathPainter({required this.path, required this.cellSize, required this.gap});

  @override
  void paint(Canvas canvas, Size size) {
    if (path.length < 2) return;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withOpacity(0.55);

    Offset center(Pos p) {
      final x = p.c * (cellSize + gap) + cellSize / 2;
      final y = p.r * (cellSize + gap) + cellSize / 2;
      return Offset(x, y);
    }

    final p0 = center(path.first);
    final pathObj = Path()..moveTo(p0.dx, p0.dy);
    for (int i = 1; i < path.length; i++) {
      final pi = center(path[i]);
      pathObj.lineTo(pi.dx, pi.dy);
    }
    canvas.drawPath(pathObj, paint);
  }

  @override
  bool shouldRepaint(covariant _PathPainter oldDelegate) {
    return oldDelegate.path != path || oldDelegate.cellSize != cellSize || oldDelegate.gap != gap;
  }
}
