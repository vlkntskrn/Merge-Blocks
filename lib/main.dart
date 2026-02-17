import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

void main() => runApp(const MergeNeonApp());

class MergeNeonApp extends StatelessWidget {
  const MergeNeonApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Merge Blocks Neon Chain',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: const UltraGamePage(),
    );
  }
}

enum AppLang { tr, en, de }
enum FxMode { low, high }

const Map<AppLang, Map<String, String>> _i18n = {
  AppLang.en: {
    'title': 'MERGE BLOCKS NEON CHAIN',
    'level': 'Level',
    'score': 'Score',
    'best': 'Best',
    'max': 'Max',
    'target': 'Target',
    'move': 'Move',
    'now': 'NOW',
    'next': 'NEXT',
    'swapCost': 'SWAP',
    'hammerCost': 'HAMMER',
    'watchAd': 'AD',
    'shop': 'SHOP',
    'pause': 'PAUSE',
    'resume': 'Resume',
    'restart': 'Restart',
    'settings': 'Settings',
    'language': 'Language',
    'fx': 'Performance',
    'low': 'Low FX',
    'high': 'High FX',
    'offerTitle': 'Level reward',
    'offerBody': 'Watch an ad to receive a helper tile: {tile}.',
    'offerHint': 'A low tile will be replaced with the reward tile.',
    'offerWatch': 'Watch ad',
    'offerNoThanks': 'No thanks',
    'notEnoughDiamonds': 'Not enough diamonds',
    'comboSuper': 'Super Combo!',
    'comboGreat': 'Great Combo!',
    'comboEpic': 'Epic Combo!',
    'diamonds': 'Diamonds',
  },
  AppLang.tr: {
    'title': 'MERGE BLOCKS NEON CHAIN',
    'level': 'Seviye',
    'score': 'Skor',
    'best': 'En Büyük',
    'max': 'Maks',
    'target': 'Hedef',
    'move': 'Hamle',
    'now': 'ŞİMDİ',
    'next': 'SONRAKİ',
    'swapCost': 'TAKAS',
    'hammerCost': 'ÇEKİÇ',
    'watchAd': 'REKLAM',
    'shop': 'MAĞAZA',
    'pause': 'DURAKLAT',
    'resume': 'Devam',
    'restart': 'Yeniden',
    'settings': 'Ayarlar',
    'language': 'Dil',
    'fx': 'Performans',
    'low': 'Düşük FX',
    'high': 'Yüksek FX',
    'offerTitle': 'Seviye ödülü',
    'offerBody': 'Reklam izleyerek yardımcı blok kazan: {tile}.',
    'offerHint': 'En düşük blok silinir, yerine ödül bloğu gelir.',
    'offerWatch': 'Reklam izle',
    'offerNoThanks': 'Hayır',
    'notEnoughDiamonds': 'Yeterli elmas yok',
    'comboSuper': 'Süper Kombo!',
    'comboGreat': 'Harika Kombo!',
    'comboEpic': 'Muhteşem Kombo!',
    'diamonds': 'Elmas',
  },
  AppLang.de: {
    'title': 'MERGE BLOCKS NEON CHAIN',
    'level': 'Level',
    'score': 'Punkte',
    'best': 'Bestwert',
    'max': 'Max',
    'target': 'Ziel',
    'move': 'Zug',
    'now': 'JETZT',
    'next': 'NÄCHST',
    'swapCost': 'TAUSCH',
    'hammerCost': 'HAMMER',
    'watchAd': 'WERBUNG',
    'shop': 'SHOP',
    'pause': 'PAUSE',
    'resume': 'Weiter',
    'restart': 'Neustart',
    'settings': 'Einstellungen',
    'language': 'Sprache',
    'fx': 'Leistung',
    'low': 'Niedrige FX',
    'high': 'Hohe FX',
    'offerTitle': 'Level-Belohnung',
    'offerBody': 'Sieh dir eine Werbung an und erhalte einen Helfer-Block: {tile}.',
    'offerHint': 'Ein kleiner Block wird ersetzt.',
    'offerWatch': 'Werbung ansehen',
    'offerNoThanks': 'Nein, danke',
    'notEnoughDiamonds': 'Nicht genug Diamanten',
    'comboSuper': 'Super Combo!',
    'comboGreat': 'Tolle Combo!',
    'comboEpic': 'Epische Combo!',
    'diamonds': 'Diamanten',
  },
};

String shortNumBig(BigInt n) {
  final thousand = BigInt.from(1000);
  final million = BigInt.from(1000000);
  final billion = BigInt.from(1000000000);
  final trillion = BigInt.from(1000000000000);
  if (n < thousand) return n.toString();
  if (n < million) return '${(n ~/ thousand)}K';
  if (n < billion) return '${(n ~/ million)}M';
  if (n < trillion) return '${(n ~/ billion)}B';
  return '${(n ~/ trillion)}T';
}

String shortNumInt(int n) => shortNumBig(BigInt.from(n));

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

class UltraGamePage extends StatefulWidget {
  const UltraGamePage({super.key});
  @override
  State<UltraGamePage> createState() => _UltraGamePageState();
}

class _UltraGamePageState extends State<UltraGamePage> with TickerProviderStateMixin {
  static const int rows = 6;
  static const int cols = 6;

  late List<List<int>> grid;
  int score = 0;
  int best = 0;
  int moves = 0;
  int levelIdx = 1;
  int diamonds = 0;

  AppLang lang = AppLang.tr;
  FxMode fxMode = FxMode.high;
  bool isBusy = false;

  final List<Pos> _path = [];
  int? _pathValue;
  bool _dragging = false;

  late final AnimationController glowCtrl;
  late final AnimationController energyCtrl;
  late final AnimationController hudPulseCtrl;
  late final AnimationController diamondPulseCtrl;

  String? _comboText;
  Timer? _comboTimer;

  final List<_Particle> _particles = [];
  Timer? _particleTimer;

  final GlobalKey _diamondHudKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    glowCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 860))..repeat(reverse: true);
    energyCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();
    hudPulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 420));
    diamondPulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 320));
    _newGame();
  }

  @override
  void dispose() {
    glowCtrl.dispose();
    energyCtrl.dispose();
    hudPulseCtrl.dispose();
    diamondPulseCtrl.dispose();
    _comboTimer?.cancel();
    _particleTimer?.cancel();
    super.dispose();
  }

  String t(String key) => (_i18n[lang] ?? _i18n[AppLang.en]!) [key] ?? key;

  int get maxSeen {
    int m = 0;
    for (final row in grid) {
      for (final v in row) {
        m = max(m, v);
      }
    }
    return m;
  }

  int get targetForLevel => 2048 * (1 << (levelIdx - 1));

  int get spawnMin {
    final m = maxSeen;
    if (m < 2048) return 2;
    int k = 0;
    int cur = 2048;
    while (m >= cur) {
      k++;
      cur *= 2;
      if (k > 10) break;
    }
    return 2 << k;
  }

  int get spawnMax {
    final m = maxSeen;
    if (m < 2048) return 64;
    int k = 0;
    int cur = 2048;
    while (m >= cur) {
      k++;
      cur *= 2;
      if (k > 10) break;
    }
    return 64 << k;
  }

  void _newGame() {
    grid = List.generate(rows, (_) => List.filled(cols, 0));
    score = 0;
    moves = 0;
    levelIdx = 1;
    diamonds = 0;
    best = 0;

    final initialVals = <int>[2, 4, 8, 16, 32, 64];
    final rnd = Random();
    final empties = _emptyCells();
    empties.shuffle(rnd);
    final count = min(12, empties.length);
    for (int i = 0; i < count; i++) {
      grid[empties[i].r][empties[i].c] = initialVals[rnd.nextInt(initialVals.length)];
    }
    setState(() {});
  }

  List<Pos> _emptyCells() {
    final out = <Pos>[];
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        if (grid[r][c] == 0) out.add(Pos(r, c));
      }
    }
    return out;
  }

  bool _inBounds(Pos p) => p.r >= 0 && p.r < rows && p.c >= 0 && p.c < cols;

  bool _isNeighbor(Pos a, Pos b) {
    final dr = (a.r - b.r).abs();
    final dc = (a.c - b.c).abs();
    return (dr <= 1 && dc <= 1) && !(dr == 0 && dc == 0);
  }

  void _startPath(Pos p) {
    if (isBusy) return;
    final v = grid[p.r][p.c];
    if (v == 0) return;

    _path
      ..clear()
      ..add(p);
    _pathValue = v;
    _dragging = true;
    setState(() {});
  }

  void _extendPath(Pos p) {
    if (!_dragging || isBusy) return;
    if (!_inBounds(p)) return;
    final v = grid[p.r][p.c];
    if (v == 0) return;
    if (_pathValue != v) return;

    if (_path.isNotEmpty && p == _path.last) return;

    if (_path.length >= 2 && p == _path[_path.length - 2]) {
      _path.removeLast();
      setState(() {});
      return;
    }

    if (_path.isEmpty) {
      _path.add(p);
      setState(() {});
      return;
    }

    if (!_isNeighbor(_path.last, p)) return;
    if (_path.contains(p)) return;

    _path.add(p);
    setState(() {});
  }

  Future<void> _endPath() async {
    if (!_dragging) return;
    _dragging = false;

    if (_path.length < 2) {
      _path.clear();
      _pathValue = null;
      setState(() {});
      return;
    }

    await _performMerge(_path.toList());
    _path.clear();
    _pathValue = null;
    if (mounted) setState(() {});
  }

  Future<void> _performMerge(List<Pos> path) async {
    if (isBusy) return;
    isBusy = true;
    moves += 1;

    final v = grid[path.first.r][path.first.c];
    if (v == 0) {
      isBusy = false;
      return;
    }

    for (final p in path) {
      if (grid[p.r][p.c] != v) {
        isBusy = false;
        return;
      }
    }

    _showCombo(path.length);

    if (path.length >= 11) {
      diamonds += 1;
      _playDiamondFlyFx();
    }

    final newVal = v << (path.length - 1);
    final dest = path.last;

    if (fxMode == FxMode.high) {
      _spawnPop(path);
      await Future.delayed(const Duration(milliseconds: 140));
    }

    for (final p in path) {
      grid[p.r][p.c] = 0;
    }
    grid[dest.r][dest.c] = newVal;

    score += newVal;
    best = max(best, newVal);

    await _applyGravityFx();
    await _spawnNewTilesFx();

    if (maxSeen >= targetForLevel) {
      levelIdx += 1;
      await _maybeOfferLevelReward();
    }

    isBusy = false;
    if (mounted) setState(() {});
  }

  void _showCombo(int combo) {
    _comboTimer?.cancel();
    if (combo >= 11) {
      _comboText = t('comboEpic');
    } else if (combo >= 8) {
      _comboText = t('comboGreat');
    } else if (combo >= 5) {
      _comboText = t('comboSuper');
    } else {
      _comboText = null;
    }

    if (_comboText != null) {
      _comboTimer = Timer(const Duration(milliseconds: 900), () {
        if (!mounted) return;
        setState(() => _comboText = null);
      });
    }
    setState(() {});
  }

  Future<void> _applyGravityFx() async {
    for (int c = 0; c < cols; c++) {
      final values = <int>[];
      for (int r = 0; r < rows; r++) {
        if (grid[r][c] != 0) values.add(grid[r][c]);
      }
      final zeros = List<int>.filled(rows - values.length, 0);
      final newCol = zeros + values;
      for (int r = 0; r < rows; r++) {
        grid[r][c] = newCol[r];
      }
    }
    if (fxMode == FxMode.high) {
      await Future.delayed(const Duration(milliseconds: 120));
    }
  }

  Future<void> _spawnNewTilesFx() async {
    final empties = _emptyCells();
    if (empties.isEmpty) return;

    final rnd = Random();
    final spawnCount = min(2, empties.length);
    empties.shuffle(rnd);

    int pickVal() {
      final minV = spawnMin;
      final maxV = spawnMax;
      final opts = <int>[];
      int cur = minV;
      while (cur <= maxV) {
        opts.add(cur);
        cur *= 2;
        if (opts.length > 16) break;
      }
      final weights = <double>[];
      for (int i = 0; i < opts.length; i++) {
        weights.add(pow(0.45, i).toDouble());
      }
      final sum = weights.fold<double>(0, (a, b) => a + b);
      double x = rnd.nextDouble() * sum;
      for (int i = 0; i < opts.length; i++) {
        x -= weights[i];
        if (x <= 0) return opts[i];
      }
      return opts.last;
    }

    for (int i = 0; i < spawnCount; i++) {
      final p = empties[i];
      grid[p.r][p.c] = pickVal();
      if (fxMode == FxMode.high) {
        await Future.delayed(const Duration(milliseconds: 60));
      }
    }
  }

  Future<void> _maybeOfferLevelReward() async {
    final offerVal = targetForLevel ~/ 2;
    final tileStr = shortNumInt(offerVal);

    final accepted = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        title: Text(t('offerTitle')),
        content: Text(
          t('offerBody').replaceAll('{tile}', tileStr) + '\n\n' + t('offerHint'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(t('offerNoThanks'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(t('offerWatch'))),
        ],
      ),
    );

    if (accepted == true && mounted) {
      _grantOfferTile(offerVal);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('+$tileStr'), duration: const Duration(milliseconds: 900)),
      );
      setState(() {});
    }
  }

  void _grantOfferTile(int offerVal) {
    final empties = _emptyCells();
    if (empties.isNotEmpty) {
      grid[empties.first.r][empties.first.c] = offerVal;
      return;
    }

    int minV = 1 << 30;
    final minPositions = <Pos>[];
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        final v = grid[r][c];
        if (v == 0) continue;
        if (v < minV) {
          minV = v;
          minPositions
            ..clear()
            ..add(Pos(r, c));
        } else if (v == minV) {
          minPositions.add(Pos(r, c));
        }
      }
    }
    if (minPositions.isEmpty) return;
    final pick = minPositions[Random().nextInt(minPositions.length)];
    grid[pick.r][pick.c] = offerVal;
  }

  void _spawnPop(List<Pos> cells) {
    final rnd = Random();
    for (final p in cells) {
      for (int i = 0; i < 6; i++) {
        _particles.add(_Particle.cell(
          origin: p,
          angle: rnd.nextDouble() * 2 * pi,
          speed: 0.7 + rnd.nextDouble() * 1.4,
          life: 0.9 + rnd.nextDouble() * 0.4,
        ));
      }
    }
    _startParticleTick();
  }

  void _playDiamondFlyFx() {
    diamondPulseCtrl.forward(from: 0);
    hudPulseCtrl.forward(from: 0);

    final rnd = Random();
    for (int i = 0; i < 10; i++) {
      _particles.add(_Particle.free(
        x: 0.82 + rnd.nextDouble() * 0.12,
        y: 0.06 + rnd.nextDouble() * 0.06,
        angle: -pi / 2 + (rnd.nextDouble() - 0.5) * 0.9,
        speed: 0.25 + rnd.nextDouble() * 0.45,
        life: 0.8 + rnd.nextDouble() * 0.4,
        color: Colors.cyanAccent,
      ));
    }
    _startParticleTick();
  }

  void _startParticleTick() {
    _particleTimer?.cancel();
    _particleTimer = Timer.periodic(const Duration(milliseconds: 16), (t) {
      const dt = 0.016;
      for (final part in _particles) {
        part.step(dt);
      }
      _particles.removeWhere((p) => p.life <= 0);
      if (_particles.isEmpty) t.cancel();
      if (mounted) setState(() {});
    });
  }

  TextStyle _neon(Color c, double s, {double glow = 0.25, bool bold = false}) {
    return TextStyle(
      color: c,
      fontSize: s,
      fontWeight: bold ? FontWeight.w800 : FontWeight.w700,
      shadows: [
        Shadow(color: c.withOpacity(0.55), blurRadius: 16 * glow),
        Shadow(color: c.withOpacity(0.35), blurRadius: 28 * glow),
      ],
    );
  }

  Color _tileColor(int v) {
    const palette = <int, Color>{
      2: Color(0xFF00E5FF),
      4: Color(0xFF1DE9B6),
      8: Color(0xFF76FF03),
      16: Color(0xFFFFEA00),
      32: Color(0xFFFF9100),
      64: Color(0xFFFF1744),
      128: Color(0xFFD500F9),
      256: Color(0xFF651FFF),
      512: Color(0xFF2979FF),
      1024: Color(0xFF00B0FF),
      2048: Color(0xFF00E676),
      4096: Color(0xFFFFD600),
      8192: Color(0xFFFF6D00),
      16384: Color(0xFFFF1744),
    };
    return palette[v] ?? HSVColor.fromAHSV(1, (log(v) / ln2 * 34) % 360, 0.85, 1).toColor();
  }

  @override
  Widget build(BuildContext context) {
    final safe = MediaQuery.of(context).padding;
    final bottomBarH = 78.0 + safe.bottom;
    return Scaffold(
      backgroundColor: const Color(0xFF070911),
      body: Stack(
        children: [
          Positioned.fill(
            child: Column(
              children: [
                SafeArea(bottom: false, child: _buildHeader()),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(14, 10, 14, 10 + bottomBarH),
                    child: Center(
                      child: LayoutBuilder(
                        builder: (ctx, cons) {
                          final size = min(cons.maxWidth, cons.maxHeight);
                          return SizedBox(
                            width: size,
                            height: size,
                            child: _buildBoard(Size(size, size)),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(left: 0, right: 0, bottom: 0, child: SafeArea(top: false, child: _buildBottomBar())),
          if (_comboText != null)
            Positioned.fill(
              child: IgnorePointer(
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      color: Colors.black.withOpacity(0.35),
                      border: Border.all(color: Colors.white.withOpacity(0.18)),
                      boxShadow: [BoxShadow(blurRadius: 22, color: Colors.cyanAccent.withOpacity(0.18))],
                    ),
                    child: Text(_comboText!, style: _neon(Colors.white, 24, glow: 0.45, bold: true)),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final nextGoal = shortNumInt(targetForLevel);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(
            colors: [Colors.blueAccent.withOpacity(0.16), Colors.purpleAccent.withOpacity(0.12)],
          ),
          border: Border.all(color: Colors.white.withOpacity(0.12)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.35), blurRadius: 18, offset: const Offset(0, 8))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(t('title'), style: _neon(Colors.white, 18, glow: 0.25, bold: true)),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _miniStatChip(t('score'), shortNumInt(score))),
                const SizedBox(width: 8),
                Expanded(child: _miniStatChip(t('best'), shortNumInt(best))),
                const SizedBox(width: 8),
                Expanded(child: _miniStatChip(t('max'), shortNumInt(maxSeen))),
                const SizedBox(width: 8),
                _diamondPill(),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _levelPill(),
                const SizedBox(width: 10),
                Expanded(child: _goalProgressBar(nextGoal)),
                const SizedBox(width: 10),
                _langButton(),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _diamondPill() {
    return ScaleTransition(
      scale: Tween<double>(begin: 1, end: 1.08).animate(CurvedAnimation(parent: diamondPulseCtrl, curve: Curves.easeOutBack)),
      child: Container(
        key: _diamondHudKey,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.white.withOpacity(0.08),
          border: Border.all(color: Colors.white.withOpacity(0.18)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.diamond, size: 18, color: Colors.cyanAccent),
            const SizedBox(width: 6),
            Text('$diamonds', style: _neon(Colors.white, 16, glow: 0.25, bold: true)),
          ],
        ),
      ),
    );
  }

  Widget _levelPill() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white.withOpacity(0.07),
        border: Border.all(color: Colors.white.withOpacity(0.18)),
      ),
      child: Text('${t('level')} $levelIdx', style: _neon(Colors.white, 14, glow: 0.2, bold: true)),
    );
  }

  Widget _langButton() {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: _openSettingsSheet,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: Colors.white.withOpacity(0.07),
          border: Border.all(color: Colors.white.withOpacity(0.16)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.language, size: 18, color: Colors.white),
            const SizedBox(width: 8),
            Text(lang.name.toUpperCase(), style: _neon(Colors.white, 12, glow: 0.15, bold: true)),
          ],
        ),
      ),
    );
  }

  Widget _miniStatChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white.withOpacity(0.06),
        border: Border.all(color: Colors.white.withOpacity(0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 11, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(value, style: _neon(Colors.white, 14, glow: 0.18, bold: true)),
        ],
      ),
    );
  }

  Widget _goalProgressBar(String nextGoalText) {
    final cur = maxSeen;
    final tar = targetForLevel;
    final ratio = tar == 0 ? 0.0 : (cur / tar).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white.withOpacity(0.06),
        border: Border.all(color: Colors.white.withOpacity(0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('${t('target')}: $nextGoalText', style: TextStyle(color: Colors.white.withOpacity(0.82), fontSize: 11, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: SizedBox(
              height: 10,
              child: Stack(
                children: [
                  Positioned.fill(child: Container(color: Colors.white.withOpacity(0.08))),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: ratio,
                      child: Container(color: Colors.cyanAccent.withOpacity(0.55)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text('${shortNumInt(cur)} / ${shortNumInt(tar)}', textAlign: TextAlign.right, style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 10, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      height: 78,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.55),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.35), blurRadius: 18, offset: const Offset(0, -8))],
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.10))),
      ),
      child: Row(
        children: [
          Expanded(
            child: _actionChip(
              icon: Icons.refresh,
              label: t('restart'),
              onTap: () {
                if (isBusy) return;
                _newGame();
              },
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _actionChip(
              icon: Icons.pause,
              label: t('pause'),
              onTap: _openPauseDialog,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _actionChip(
              icon: fxMode == FxMode.high ? Icons.flash_on : Icons.flash_off,
              label: fxMode == FxMode.high ? t('high') : t('low'),
              onTap: () => setState(() => fxMode = fxMode == FxMode.high ? FxMode.low : FxMode.high),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionChip({required IconData icon, required String label, required VoidCallback onTap}) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(colors: [Colors.white.withOpacity(0.10), Colors.white.withOpacity(0.06)]),
          border: Border.all(color: Colors.white.withOpacity(0.14)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: Colors.white),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 12, fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }

  Future<void> _openPauseDialog() async {
    if (isBusy) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t('pause')),
        content: Text('${t('move')}: $moves\n${t('level')}: $levelIdx\n${t('diamonds')}: $diamonds'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(t('resume'))),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _newGame();
            },
            child: Text(t('restart')),
          ),
        ],
      ),
    );
  }

  void _openSettingsSheet() {
    if (isBusy) return;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: const Color(0xFF0E1120),
      builder: (ctx) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(t('settings'), style: _neon(Colors.white, 18, glow: 0.2, bold: true)),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(child: Text(t('language'), style: TextStyle(color: Colors.white.withOpacity(0.85), fontWeight: FontWeight.w700))),
                    const SizedBox(width: 10),
                    _pill(lang == AppLang.tr ? Colors.cyanAccent : Colors.white.withOpacity(0.12), 'TR', () => setState(() => lang = AppLang.tr)),
                    const SizedBox(width: 8),
                    _pill(lang == AppLang.en ? Colors.cyanAccent : Colors.white.withOpacity(0.12), 'EN', () => setState(() => lang = AppLang.en)),
                    const SizedBox(width: 8),
                    _pill(lang == AppLang.de ? Colors.cyanAccent : Colors.white.withOpacity(0.12), 'DE', () => setState(() => lang = AppLang.de)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: Text(t('fx'), style: TextStyle(color: Colors.white.withOpacity(0.85), fontWeight: FontWeight.w700))),
                    const SizedBox(width: 10),
                    _pill(fxMode == FxMode.low ? Colors.cyanAccent : Colors.white.withOpacity(0.12), t('low'), () => setState(() => fxMode = FxMode.low)),
                    const SizedBox(width: 8),
                    _pill(fxMode == FxMode.high ? Colors.cyanAccent : Colors.white.withOpacity(0.12), t('high'), () => setState(() => fxMode = FxMode.high)),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _pill(Color bg, String label, VoidCallback onTap) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: bg,
        ),
        child: Text(label, style: TextStyle(color: bg == Colors.cyanAccent ? Colors.black : Colors.white, fontWeight: FontWeight.w900, fontSize: 12)),
      ),
    );
  }

  Widget _buildBoard(Size boardSize) {
    return Listener(
      onPointerDown: (e) {
        final p = _posFromOffset(e.localPosition, boardSize);
        if (p != null) _startPath(p);
      },
      onPointerMove: (e) {
        final p = _posFromOffset(e.localPosition, boardSize);
        if (p != null) _extendPath(p);
      },
      onPointerUp: (_) => _endPath(),
      child: CustomPaint(
        painter: _BoardBgPainter(glow: glowCtrl, energy: energyCtrl),
        child: Stack(
          children: [
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: _buildGrid(boardSize),
              ),
            ),
            if (_path.length >= 2)
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _PathPainter(path: _path.toList()),
                  ),
                ),
              ),
            if (_particles.isNotEmpty)
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _ParticlesPainter(particles: _particles.toList()),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Pos? _posFromOffset(Offset o, Size boardSize) {
    const pad = 10.0;
    final inner = Size(boardSize.width - pad * 2, boardSize.height - pad * 2);
    final local = o - const Offset(pad, pad);
    if (local.dx < 0 || local.dy < 0 || local.dx >= inner.width || local.dy >= inner.height) return null;
    final cellW = inner.width / cols;
    final cellH = inner.height / rows;
    final c = (local.dx / cellW).floor();
    final r = (local.dy / cellH).floor();
    if (r < 0 || r >= rows || c < 0 || c >= cols) return null;
    return Pos(r, c);
  }

  Widget _buildGrid(Size boardSize) {
    const pad = 10.0;
    final innerW = boardSize.width - pad * 2;
    final innerH = boardSize.height - pad * 2;
    final cellW = innerW / cols;
    final cellH = innerH / rows;

    return Stack(
      children: [
        for (int r = 0; r < rows; r++)
          for (int c = 0; c < cols; c++)
            Positioned(
              left: c * cellW,
              top: r * cellH,
              width: cellW,
              height: cellH,
              child: _cell(r, c),
            ),
      ],
    );
  }

  Widget _cell(int r, int c) {
    final v = grid[r][c];
    final base = Colors.white.withOpacity(0.06);
    return Padding(
      padding: const EdgeInsets.all(5),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: v == 0 ? base : _tileColor(v).withOpacity(0.20),
          border: Border.all(color: v == 0 ? Colors.white.withOpacity(0.08) : _tileColor(v).withOpacity(0.70)),
          boxShadow: v == 0
              ? []
              : [
                  BoxShadow(color: _tileColor(v).withOpacity(0.30), blurRadius: 18, spreadRadius: 0),
                ],
        ),
        child: Center(
          child: v == 0
              ? const SizedBox.shrink()
              : Text(
                  shortNumInt(v),
                  style: _neon(Colors.white, v < 128 ? 22 : (v < 1024 ? 18 : 16), glow: 0.40, bold: true),
                ),
        ),
      ),
    );
  }
}

class _BoardBgPainter extends CustomPainter {
  final Animation<double> glow;
  final Animation<double> energy;
  _BoardBgPainter({required this.glow, required this.energy}) : super(repaint: Listenable.merge([glow, energy]));

  @override
  void paint(Canvas canvas, Size size) {
    final r = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(26));
    final bg = Paint()..color = const Color(0xFF0B0E1C);
    canvas.drawRRect(r, bg);

    final g = glow.value;
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..color = Colors.cyanAccent.withOpacity(0.25 + 0.25 * g);
    canvas.drawRRect(r.deflate(2), p);

    final e = energy.value;
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = Colors.purpleAccent.withOpacity(0.10 + 0.12 * g);
    final inset = 10 + 6 * sin(e * 2 * pi);
    canvas.drawRRect(r.deflate(inset), ring);
  }

  @override
  bool shouldRepaint(covariant _BoardBgPainter oldDelegate) => false;
}

class _PathPainter extends CustomPainter {
  final List<Pos> path;
  _PathPainter({required this.path});

  @override
  void paint(Canvas canvas, Size size) {
    if (path.length < 2) return;
    const pad = 10.0;
    final inner = Size(size.width - pad * 2, size.height - pad * 2);
    final cellW = inner.width / _UltraGamePageState.cols;
    final cellH = inner.height / _UltraGamePageState.rows;

    Offset center(Pos p) => Offset(p.c * cellW + cellW / 2 + pad, p.r * cellH + cellH / 2 + pad);

    final pts = path.map(center).toList();
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = 6
      ..color = Colors.cyanAccent.withOpacity(0.55);
    final glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = 12
      ..color = Colors.cyanAccent.withOpacity(0.18);

    final pth = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (int i = 1; i < pts.length; i++) {
      pth.lineTo(pts[i].dx, pts[i].dy);
    }
    canvas.drawPath(pth, glow);
    canvas.drawPath(pth, paint);
  }

  @override
  bool shouldRepaint(covariant _PathPainter oldDelegate) => true;
}

class _Particle {
  final Pos? origin;
  double x;
  double y;
  final double angle;
  final double speed;
  double life;
  final Color color;

  _Particle.cell({required this.origin, required this.angle, required this.speed, required this.life})
      : x = 0,
        y = 0,
        color = Colors.white;

  _Particle.free({required this.x, required this.y, required this.angle, required this.speed, required this.life, required this.color}) : origin = null;

  void step(double dt) {
    life -= dt;
    final vx = cos(angle) * speed;
    final vy = sin(angle) * speed;
    x += vx * dt;
    y += vy * dt;
  }
}

class _ParticlesPainter extends CustomPainter {
  final List<_Particle> particles;
  _ParticlesPainter({required this.particles});

  @override
  void paint(Canvas canvas, Size size) {
    const pad = 10.0;
    final inner = Size(size.width - pad * 2, size.height - pad * 2);
    final cellW = inner.width / _UltraGamePageState.cols;
    final cellH = inner.height / _UltraGamePageState.rows;

    for (final p in particles) {
      Offset pos;
      Color c;
      double radius;
      final alpha = p.life.clamp(0.0, 1.0);
      if (p.origin != null) {
        final base = Offset(p.origin!.c * cellW + cellW / 2 + pad, p.origin!.r * cellH + cellH / 2 + pad);
        pos = base + Offset(p.x * cellW, p.y * cellH);
        c = Colors.purpleAccent;
        radius = 2.6;
      } else {
        pos = Offset(p.x * size.width, p.y * size.height);
        c = p.color;
        radius = 2.2;
      }
      final paint = Paint()..color = c.withOpacity(0.55 * alpha);
      canvas.drawCircle(pos, radius, paint);
      canvas.drawCircle(pos, radius * 2.2, Paint()..color = c.withOpacity(0.12 * alpha));
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlesPainter oldDelegate) => true;
}
