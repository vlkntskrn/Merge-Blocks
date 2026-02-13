// DartPad Tek Dosya - Merge Blocks Neon Chain FINAL
// Özellikler:
// - Campaign (1-100) + Endless (101+) mod
// - Dengeli hedef eğrisi (segmentli + log destekli), BigInt güvenli
// - Her 10 bölümde  farklılığı (mekanik varyasyonları)
// - Test Mode + 
// - Swap-only ekonomi (bomba yok)
// - AdMob Rewarded entegrasyon noktası (mock servis)
// - Leaderboard altyapısı (local + online mock)
// - 5x8 grid, TR/EN, koyu premium arayüz

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';


class BlockerCrackPainter extends CustomPainter {
  final int hp;
  BlockerCrackPainter(this.hp);

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = hp == 2 ? 1.8 : 2.2
      ..color = Colors.black.withValues(alpha: hp == 2 ? 0.28 : 0.40)
      ..strokeCap = StrokeCap.round;

    if (hp >= 3) return;

    // crack layer 1 (hp <=2)
    final path1 = Path()
      ..moveTo(size.width * 0.20, size.height * 0.15)
      ..lineTo(size.width * 0.35, size.height * 0.32)
      ..lineTo(size.width * 0.30, size.height * 0.48)
      ..lineTo(size.width * 0.42, size.height * 0.63)
      ..lineTo(size.width * 0.38, size.height * 0.86);
    canvas.drawPath(path1, p);

    final branch = Path()
      ..moveTo(size.width * 0.30, size.height * 0.48)
      ..lineTo(size.width * 0.18, size.height * 0.60);
    canvas.drawPath(branch, p);

    if (hp <= 1) {
      // crack layer 2 (deeper)
      final p2 = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..color = Colors.black.withValues(alpha: 0.50)
        ..strokeCap = StrokeCap.round;

      final path2 = Path()
        ..moveTo(size.width * 0.78, size.height * 0.12)
        ..lineTo(size.width * 0.66, size.height * 0.30)
        ..lineTo(size.width * 0.72, size.height * 0.46)
        ..lineTo(size.width * 0.58, size.height * 0.68)
        ..lineTo(size.width * 0.62, size.height * 0.88);
      canvas.drawPath(path2, p2);

      final branch2 = Path()
        ..moveTo(size.width * 0.72, size.height * 0.46)
        ..lineTo(size.width * 0.84, size.height * 0.58);
      canvas.drawPath(branch2, p2);
    }
  }

  @override
  bool shouldRepaint(covariant BlockerCrackPainter oldDelegate) => oldDelegate.hp != hp;
}

void main() => runApp(const Ultra2248App());

class Ultra2248App extends StatelessWidget {
  const Ultra2248App({super.key});
  @override
  

Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Merge Blocks Neon Chain Premium v14.8',
      theme: ThemeData.dark(useMaterial3: true),
      home: const UltraGamePage(),
    );
  }
}

enum AppLang { tr, en }
enum NumFmt { tr, en }
enum FxMode { low, high }
enum GoalType { reachValue, clearBlockers, comboCount }
enum GameMode { endless }

class Cell {
  int value;
  bool blocked;
  bool frozen;
  int blockerHp = 0; // frozen tile: bir kez çözülmesi gerekir
  Cell(this.value, {this.blocked = false, this.frozen = false});
}

class Pos {
  final int r, c;
  const Pos(this.r, this.c);
  @override
  bool operator ==(Object other) => other is Pos && other.r == r && other.c == c;
  @override
  int get hashCode => Object.hash(r, c);
}

class FallingTile {
  final int fromR, toR, c, value;
  final bool blocked, frozen;
  FallingTile({
    required this.fromR,
    required this.toR,
    required this.c,
    required this.value,
    this.blocked = false,
    this.frozen = false,
  });
}

class Particle {
  final Offset origin;
  final double angle, speed;
  final Color color;
  Particle(this.origin, this.angle, this.speed, this.color);
}

class LevelConfig {
  final int index;
  final BigInt targetBig;
  final GoalType goalType;
  final int goalAmount;
  final int blockerCount;
  final int move3, move2, move1;
  final String episodeName;
  final bool frozenEnabled;
  final bool valueGateEnabled;
  final int? valueGateMin;
  const LevelConfig({
    required this.index,
    required this.targetBig,
    this.goalType = GoalType.reachValue,
    this.goalAmount = 0,
    this.blockerCount = 0,
    this.move3 = 30,
    this.move2 = 45,
    this.move1 = 60,
    this.episodeName = 'Classic',
    this.frozenEnabled = false,
    this.valueGateEnabled = false,
    this.valueGateMin,
  });
}

class LeaderboardEntry {
  final String name;
  final int score;
  final int level;
  final DateTime date;
  final GameMode mode;
  const LeaderboardEntry({
    required this.name,
    required this.score,
    required this.level,
    required this.date,
    required this.mode,
  });
}

// ---------- Rewarded Ad ----------
abstract class RewardedAdService {
  Future<void> initialize();
  Future<bool> isAdReady();
  Future<void> loadAd();
  Future<void> showAd({required VoidCallback onReward});
}

class MockRewardedAdService implements RewardedAdService {
  bool _ready = true;
  @override
  Future<void> initialize() async => _ready = true;
  @override
  Future<bool> isAdReady() async => _ready;
  @override
  Future<void> loadAd() async => _ready = true;
  @override
  Future<void> showAd({required VoidCallback onReward}) async {
    await Future.delayed(const Duration(milliseconds: 450));
    onReward();
    _ready = false;
    await loadAd();
  }
}

// ---------- Online LB ----------
abstract class OnlineLeaderboardService {
  Future<List<LeaderboardEntry>> fetchTop({required GameMode mode, int limit = 30});
  Future<void> submitScore(LeaderboardEntry entry);
}

class MockOnlineLeaderboardService implements OnlineLeaderboardService {
  final List<LeaderboardEntry> _list = [];
  @override
  Future<List<LeaderboardEntry>> fetchTop({required GameMode mode, int limit = 30}) async {
    final m = _list.where((e) => e.mode == mode).toList();
    m.sort((a, b) => b.score.compareTo(a.score));
    return m.take(limit).toList();
  }

  @override
  Future<void> submitScore(LeaderboardEntry entry) async => _list.add(entry);
}

class UltraGamePage extends StatefulWidget {
  const UltraGamePage({super.key});
  @override
  State<UltraGamePage> createState() => _UltraGamePageState();
}

class _UltraGamePageState extends State<UltraGamePage> with TickerProviderStateMixin {
  // === Stable unique colors by tile VALUE ===
  final Map<int, int> _valueColorIndex = {}; // value -> palette index
  static const List<Color> _valuePalette = [
    Color(0xFF42A5F5), // mavi
    Color(0xFF66BB6A), // yeşil
    Color(0xFFFFA726), // turuncu
    Color(0xFFEC407A), // pembe
    Color(0xFFEF5350), // kırmızı
    Color(0xFF3949AB), // lacivert
    Color(0xFF26C6DA),
    Color(0xFFAB47BC),
    Color(0xFFFF7043),
    Color(0xFF8D6E63),
    Color(0xFF7E57C2),
    Color(0xFF26A69A),
  ];

  Color _colorForValue(int v) {
    if (v <= 0) return const Color(0xFF37474F);
    // Stable, unique color per numeric value (2,4,8,16,...)
    final idx = _valueColorIndex.putIfAbsent(v, () => _valueColorIndex.length % _valuePalette.length);
    return _valuePalette[idx];
  }


  static const int rows = 8, cols = 5;

  // Blocker hit FX maps
  final Map<String, double> blockerHitFlash = {};
  final Map<String, double> blockerHitShake = {};

  String _k(int r, int c) => '$r:$c';

  Future<void> _hitBlockerFx(int r, int c) async {
    final key = _k(r, c);
    blockerHitFlash[key] = 1.0;
    blockerHitShake[key] = 1.0;
    if (mounted) setState(() {});
    await Future.delayed(const Duration(milliseconds: 70));
    blockerHitFlash[key] = 0.6;
    blockerHitShake[key] = 0.6;
    if (mounted) setState(() {});
    await Future.delayed(const Duration(milliseconds: 70));
    blockerHitFlash.remove(key);
    blockerHitShake.remove(key);
    if (mounted) setState(() {});
  }

  Future<void> _damageAdjacentBlockers(List<Pos> popped) async {
    const dirs = <Pos>[Pos(-1,0), Pos(1,0), Pos(0,-1), Pos(0,1)];
    for (final p in popped) {
      for (final d in dirs) {
        final rr = p.r + d.r;
        final cc = p.c + d.c;
        if (rr < 0 || rr >= rows || cc < 0 || cc >= cols) continue;
        final c = grid[rr][cc];
        if (c.blocked) {
          c.blockerHp -= 1;
          await _hitBlockerFx(rr, cc);
          if (c.blockerHp <= 0) {
            c.blocked = false;
            c.blockerHp = 0;
            blockersRemaining = (blockersRemaining - 1).clamp(0, 999);
          }
        }
      }
    }
  }
  static const double boardPadding = 3, cellGap = 4;

  // storage
  static const _kLevel = 'u2248_v14.8_level_idx';
  static const _kUnlocked = 'u2248_v14.8_unlocked';
  static const _kBest = 'u2248_v14.8_best';
  static const _kSwaps = 'u2248_v14.8_swaps';
  static const _kLang = 'u2248_v14.8_lang';
  static const _kNumFmt = 'u2248_v14.8_numfmt';
  static const _kSfx = 'u2248_v14.8_sfx';
  static const _kFx = 'u2248_v14.8_fx';
  static const _kTest = 'u2248_v14.8_test';
  static const _kMode = 'u2248_v14.8_mode';
  static const _kLb = 'u2248_v14.8_lb_local';

  final rnd = Random();
  final RewardedAdService adService = MockRewardedAdService();
  final OnlineLeaderboardService onlineLb = MockOnlineLeaderboardService();

  List<List<Cell>> grid = List.generate(rows, (_) => List.generate(cols, (_) => Cell(2)));
  late final List<LevelConfig> campaignLevels;

  int levelIdx = 0; // campaign index 0..99, endless logical >99
  int unlockedCampaign = 1;
  int moves = 0;
  int score = 0;
  int best = 0;
  int swaps = 0;
  int blockersRemaining = 0;
  int bestComboThisLevel = 0;

  AppLang lang = AppLang.tr;
  NumFmt numFmt = NumFmt.tr;
  FxMode fxMode = FxMode.high;
  GameMode mode = GameMode.endless;
  bool sfxOn = true;
  bool testMode = false;
  bool autoNextOn = true;

  bool swapMode = false;
  bool isBusy = false;
  Pos? swapFirst;

  final Set<String> selected = {};
  final List<Pos> path = [];

  bool showFallLayer = false;
  List<FallingTile> fallingTiles = [];

  bool showMergePop = false;
  Set<Pos> poppedCells = {};
  bool hidePoppedTargets = false;

  bool showParticles = false;
  List<Particle> particles = [];

  bool showPraise = false;
  String praiseText = '';
  Map<String, double> cellShakeAmp = {};

  // blocker tooltip + episode intro overlays
  bool showBlockerTip = false;
  bool showIntro = false;
  String episodeIntroTitle = '';
  String episodeIntroRule = '';
  static const _kBlockerTipSeen = 'u2248_v14.8_blocker_tip_seen';

  late final AnimationController glowCtrl;
  late final Animation<double> glowAnim;
  late final AnimationController energyCtrl;
  late final Animation<double> energyAnim;

  @override
  void initState() {
    super.initState();
    glowCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 860))..repeat(reverse: true);
    glowAnim = Tween<double>(begin: 0.24, end: 0.92).animate(CurvedAnimation(parent: glowCtrl, curve: Curves.easeInOut));
    energyCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();
    energyAnim = CurvedAnimation(parent: energyCtrl, curve: Curves.linear);

    campaignLevels = List.generate(100, (i) => _generateCampaignLevel(i + 1));
    adService.initialize();
    _startLevel(0, hardReset: true);
    _loadProgress();
  }

  @override
  void dispose() {
    glowCtrl.dispose();
    energyCtrl.dispose();
    super.dispose();
  }

  // ---------- Level Generation ----------
  LevelConfig _generateCampaignLevel(int n) {
    final target = _targetForLevel(n);
    final ep = _episodeForLevel(n);

    GoalType goal = GoalType.reachValue;
    int blockerCount = 0;
    int goalAmount = 0;
    bool frozen = false;
    bool gate = false;
    int? gateMin;

    // episode-based variation
    switch (ep.id) {
      case 1: // classic
        break;
      case 2: // blocker light
        blockerCount = 3 + ((n - 1) % 3);
        goal = GoalType.clearBlockers;
        goalAmount = blockerCount;
        break;
      case 3: // combo hunt
        goal = GoalType.comboCount;
        goalAmount = 6 + ((n - 1) % 3);
        break;
      case 4: // limited swap (economy same, mechanic no special)
        break;
      case 5: // break walls
        blockerCount = 5;
        goal = GoalType.clearBlockers;
        goalAmount = blockerCount;
        break;
      case 6: // gravity shift placeholder
        break;
      case 7: // frozen tiles
        frozen = true;
        break;
      case 8: // timed style - here combo condition
        goal = GoalType.comboCount;
        goalAmount = 7;
        break;
      case 9: // value gate
        gate = true;
        gateMin = _pow2(max(1, n ~/ 6));
        break;
      case 10: // master mix
        blockerCount = 4;
        frozen = true;
        gate = true;
        gateMin = _pow2(max(2, n ~/ 7));
        goal = GoalType.reachValue;
        break;
    }

    return LevelConfig(
      index: n,
      targetBig: target,
      goalType: goal,
      goalAmount: goalAmount,
      blockerCount: blockerCount,
      move3: 30,
      move2: 45,
      move1: 60,
      episodeName: ep.name,
      frozenEnabled: frozen,
      valueGateEnabled: gate,
      valueGateMin: gateMin,
    );
  }

  ({int id, String name}) _episodeForLevel(int n) {
    final block = ((n - 1) ~/ 10) + 1;
    switch (block) {
      case 1: return (id: 1, name: 'Classic');
      case 2: return (id: 2, name: 'Blocker Light');
      case 3: return (id: 3, name: 'Combo Hunt');
      case 4: return (id: 4, name: 'Limited Swap');
      case 5: return (id: 5, name: 'Break Walls');
      case 6: return (id: 6, name: 'Gravity Shift');
      case 7: return (id: 7, name: 'Frozen Tiles');
      case 8: return (id: 8, name: 'Timed Bonus');
      case 9: return (id: 9, name: 'Value Gate');
      default: return (id: 10, name: 'Master Mix');
    }
  }

  LevelConfig _generateEndlessLevel(int n) {
    final target = _targetForLevel(n);
    final epCycle = ((n - 101) ~/ 10) % 5;
    String ep = '';
    int blockers = 0;
    bool frozen = false;
    bool gate = false;
    int? gateMin;
    GoalType goal = GoalType.reachValue;
    int goalAmount = 0;

    switch (epCycle) {
      case 0:
        ep = '';
        break;
      case 1:
        ep = 'Endless Blockers';
        blockers = 4 + ((n - 101) % 3);
        goal = GoalType.clearBlockers;
        goalAmount = blockers;
        break;
      case 2:
        ep = 'Endless Combo';
        goal = GoalType.comboCount;
        goalAmount = 7 + ((n - 101) % 3);
        break;
      case 3:
        ep = 'Endless Frozen';
        frozen = true;
        break;
      case 4:
        ep = 'Endless Gate';
        gate = true;
        gateMin = _pow2(max(2, n ~/ 8));
        break;
    }

    return LevelConfig(
      index: n,
      targetBig: target,
      goalType: goal,
      goalAmount: goalAmount,
      blockerCount: blockers,
      move3: 30,
      move2: 45,
      move1: 60,
      episodeName: ep,
      frozenEnabled: frozen,
      valueGateEnabled: gate,
      valueGateMin: gateMin,
    );
  }

  int _pow2(int p) => p <= 0 ? 1 : (1 << p);

  // Segmentli + log destekli hedef eğrisi
  BigInt _targetForLevel(int n) {
    final base = BigInt.from(2248);
    if (n <= 20) {
      return base * (BigInt.one << (n - 1));
    } else if (n <= 50) {
      // target20 * 2^((n-20)*0.75) yaklaşık, pow2 snap
      final t20 = base * (BigInt.one << 19);
      final exp = ((n - 20) * 0.75).floor();
      return t20 * (BigInt.one << exp);
    } else if (n <= 100) {
      final t20 = base * (BigInt.one << 19);
      final t50 = t20 * (BigInt.one << ((30 * 0.75).floor()));
      final exp = ((n - 50) * 0.55).floor();
      return t50 * (BigInt.one << exp);
    } else {
      final t100 = _targetForLevel(100);
      final e1 = (sqrt((n - 100).toDouble()) * 0.45).floor();
      final logFactor = 1.0 + log((n - 99).toDouble()) * 0.12;
      final logScale = (logFactor * 1000).floor(); // fixed-point
      final scaled = (t100 * (BigInt.one << e1) * BigInt.from(logScale)) ~/ BigInt.from(1000);
      // hedef yine 2'nin kuvvetine snap edilsin (merge mantığı için)
      return _snapToPow2(scaled);
    }
  }

  BigInt _snapToPow2(BigInt v) {
    if (v <= BigInt.one) return BigInt.one;
    int bit = v.bitLength - 1;
    final low = BigInt.one << bit;
    final high = BigInt.one << (bit + 1);
    return (v - low) < (high - v) ? low : high;
  }

  LevelConfig get lv {
    final logical = max(101, levelIdx + 1);
    return _generateEndlessLevel(logical);
  }

  BigInt _maxTileBig() {
    int m = 0;
    for (final row in grid) {
      for (final c in row) {
        if (c.value > m) m = c.value;
      }
    }
    return BigInt.from(m);
  }

  List<int> _spawnPoolForLevel(int logicalLevel) {
    // Endless custom spawn sequence
    const seq = <int>[
      2,4,8,16,32,64,128,256,512,1024,2048,4096,8192,
      10000,20000,40000,80000,160000,320000,640000,
      1250000,2500000,5000000,10000000,20000000,40000000,80000000,
      160000000,320000000,640000000,
      1250000000,2500000000,5000000000,10000000000,20000000000,40000000000,80000000000,
      160000000000,320000000000,640000000000
    ];

    final currentMax = _maxTileBig();

    // 2048'e ulaşana kadar: 32'den büyük spawn yok.
    if (currentMax < BigInt.from(2048)) {
      return const [2, 4, 8, 16, 32];
    }

    // 2048 sonrası: her yeni maksimum kademede aktif en küçük değer 1 kademe yukarı kayar.
    int maxIdx = 0;
    for (int i = 0; i < seq.length; i++) {
      if (BigInt.from(seq[i]) <= currentMax) maxIdx = i;
    }

    // seq[10] = 2048. maxIdx her arttığında minIdx de 1 artsın.
    int minIdx = min(maxIdx - 10, seq.length - 7);
    if (minIdx < 0) minIdx = 0;

    // Aktif havuz her zaman 7 sayı
    final end = min(minIdx + 7, seq.length);
    return seq.sublist(minIdx, end);
  }

  // ---------- Persistence ----------
  Future<void> _loadProgress() async {
    final p = await SharedPreferences.getInstance();
    setState(() {
      levelIdx = (p.getInt(_kLevel) ?? 0).clamp(0, 999999).toInt();
      unlockedCampaign = (p.getInt(_kUnlocked) ?? 1).clamp(1, 100).toInt();
      best = p.getInt(_kBest) ?? 0;
      swaps = p.getInt(_kSwaps) ?? 0;
      lang = (p.getString(_kLang) ?? 'tr') == 'en' ? AppLang.en : AppLang.tr;
      numFmt = (p.getString(_kNumFmt) ?? 'tr') == 'en' ? NumFmt.en : NumFmt.tr;
      sfxOn = p.getBool(_kSfx) ?? true;
      fxMode = (p.getString(_kFx) ?? 'high') == 'low' ? FxMode.low : FxMode.high;
      testMode = p.getBool(_kTest) ?? false;
      mode = GameMode.endless;
      if (mode == GameMode.endless && levelIdx < 100) levelIdx = 100;
    });
    _startLevel(levelIdx);
                  _rebuildValueColorMapFromGrid();
  }

  Future<void> _saveProgress() async {
    final p = await SharedPreferences.getInstance();
    await p.setInt(_kLevel, levelIdx);
    await p.setInt(_kUnlocked, unlockedCampaign);
    await p.setInt(_kBest, best);
    await p.setInt(_kSwaps, swaps);
    await p.setString(_kLang, lang == AppLang.en ? 'en' : 'tr');
    await p.setString(_kNumFmt, numFmt == NumFmt.en ? 'en' : 'tr');
    await p.setBool(_kSfx, sfxOn);
    await p.setString(_kFx, fxMode == FxMode.low ? 'low' : 'high');
    await p.setBool(_kTest, testMode);
    await p.setString(_kMode, mode == GameMode.endless ? 'endless' : 'campaign');
  }

  Future<List<LeaderboardEntry>> _loadLocalLb() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getStringList(_kLb) ?? [];
    return raw.map((e) {
      final s = e.split('|');
      return LeaderboardEntry(
        name: s[0],
        score: int.tryParse(s[1]) ?? 0,
        level: int.tryParse(s[2]) ?? 1,
        date: DateTime.tryParse(s[3]) ?? DateTime.now(),
        mode: GameMode.endless,
      );
    }).toList();
  }

  Future<void> _saveLocalLb(List<LeaderboardEntry> list) async {
    final p = await SharedPreferences.getInstance();
    final raw = list
        .map((e) => '${e.name}|${e.score}|${e.level}|${e.date.toIso8601String()}|${e.mode == GameMode.endless ? 'endless' : 'campaign'}')
        .toList();
    await p.setStringList(_kLb, raw);
  }

  Future<void> _submitLb() async {
    final entry = LeaderboardEntry(
      name: 'Player',
      score: score,
      level: lv.index,
      date: DateTime.now(),
      mode: mode,
    );
    final local = await _loadLocalLb();
    local.add(entry);
    local.sort((a, b) => b.score.compareTo(a.score));
    await _saveLocalLb(local.take(200).toList());
    await onlineLb.submitScore(entry);
  }

  Future<void> _showLeaderboardDialog() async {
    final local = await _loadLocalLb();
    final localCampaign = local.where((e) => e.mode == GameMode.endless).toList()
      ..sort((a, b) => b.score.compareTo(a.score));
    final localEndless = local.where((e) => e.mode == GameMode.endless).toList()
      ..sort((a, b) => b.score.compareTo(a.score));

    final onlineCampaign = await onlineLb.fetchTop(mode: GameMode.endless, limit: 30);
    final onlineEndless = await onlineLb.fetchTop(mode: GameMode.endless, limit: 30);

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF171129),
        title: const SizedBox.shrink(),
        content: SizedBox(
          width: 380,
          child: DefaultTabController(
            length: 4,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const TabBar(
                  isScrollable: true,
                  tabs: [
                    Tab(text: 'Local C'),
                    Tab(text: 'Online C'),
                    Tab(text: 'Local E'),
                    Tab(text: 'Online E'),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 280,
                  child: TabBarView(
                    children: [
                      _lbList(localCampaign),
                      _lbList(onlineCampaign),
                      _lbList(localEndless),
                      _lbList(onlineEndless),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
      ),
    );
  }

  Widget _lbList(List<LeaderboardEntry> list) {
    if (list.isEmpty) {
      return Center(child: Text(lang == AppLang.tr ? 'Kayıt yok' : 'No records'));
    }
    return ListView.builder(
      itemCount: list.length.clamp(0, 30),
      itemBuilder: (_, i) {
        final e = list[i];
        return ListTile(
          dense: true,
          leading: Text('#${i + 1}', style: const TextStyle(fontWeight: FontWeight.w900)),
          title: Text('${e.name} • ${e.score}'),
          subtitle: Text('${lang == AppLang.tr ? "" : "Level"} ${e.level}'),
        );
      },
    );
  }

  // ---------- Game ----------
  
  void _rebuildValueColorMapFromGrid() {
    final present = <int>{};
    for (final row in grid) {
      for (final cell in row) {
        if (!cell.blocked && !cell.frozen && cell.value > 0) {
          present.add(cell.value);
          _valueColorIndex.putIfAbsent(cell.value, () => _valueColorIndex.length % _valuePalette.length);
        }
      }
    }
    _valueColorIndex.removeWhere((k, v) => !present.contains(k));
  }

void _startLevel(int idx, {bool hardReset = false}) {
    levelIdx = max(100, idx).toInt();

    if (hardReset) {
      score = 0;
      best = 0;
      swaps = 0;
      unlockedCampaign = 1;
    }

    moves = 0;
    blockersRemaining = 0;
    bestComboThisLevel = 0;
    isBusy = false;
    swapMode = false;
    swapFirst = null;
    selected.clear();
    path.clear();
    showFallLayer = false;
    showMergePop = false;
    showParticles = false;
    cellShakeAmp.clear();

    final logicalLevel = lv.index;
    final seed = _spawnPoolForLevel(logicalLevel);

    grid = List.generate(rows, (_) => List.generate(cols, (_) => Cell(seed[rnd.nextInt(seed.length)])));

    // blockers
    blockersRemaining = lv.blockerCount;
    int placed = 0;
    while (placed < lv.blockerCount) {
      final r = rnd.nextInt(rows), c = rnd.nextInt(cols);
      if (!grid[r][c].blocked) {
        grid[r][c].blocked = true;
        placed++;
      }
    }

    // frozen
    if (lv.frozenEnabled) {
      int fCount = 4 + (logicalLevel % 3);
      int placedF = 0;
      while (placedF < fCount) {
        final r = rnd.nextInt(rows), c = rnd.nextInt(cols);
        if (!grid[r][c].blocked && !grid[r][c].frozen) {
          grid[r][c].frozen = true;
          placedF++;
        }
      }
    }

    setState(() {});
    _saveProgress();
    _maybeShowIntro();
    _maybeShowBlockerTooltip();
  }

  void _quickSkipLevel() {
    if (!testMode) return;
    _startLevel(levelIdx + 1);
    _saveProgress();
    setState(() {});
  }

  int _swapReward(int m) {
    if (m <= lv.move3) return 3;
    if (m <= lv.move2) return 2;
    if (m <= lv.move1) return 1;
    return 0;
  }

  bool _isNeighbor(Pos a, Pos b) {
    final dr = (a.r - b.r).abs(), dc = (a.c - b.c).abs();
    return dr <= 1 && dc <= 1 && !(dr == 0 && dc == 0);
  }

  bool _isOrthogonalOneStep(Pos a, Pos b) {
    final dr = (a.r - b.r).abs(), dc = (a.c - b.c).abs();
    return (dr == 1 && dc == 0) || (dr == 0 && dc == 1);
  }

  bool _canLink(Pos prev, Pos next) {
    if (!_isNeighbor(prev, next)) return false;
    final a = grid[prev.r][prev.c], b = grid[next.r][next.c];
    if (a.blocked || b.blocked) return false;
    if (a.frozen || b.frozen) return false;
    final v1 = a.value, v2 = b.value;

    // Value gate episode
    if (lv.valueGateEnabled && lv.valueGateMin != null) {
      if (v1 < lv.valueGateMin! || v2 < lv.valueGateMin!) return false;
    }

    // Rule: next must be same or double of previous
    return v2 == v1 || v2 == v1 * 2;
  }

  int _mergedValue(List<Pos> chain) {
    int s = 0;
    for (final p in chain) {
      s += grid[p.r][p.c].value;
    }
    int pow = 1;
    while (pow < max(2, s)) {
      pow <<= 1;
    }
    return pow;
  }

  bool _isLevelGoalCompleted() {
    final reachedTarget = _maxTileBig() >= lv.targetBig;
    if (testMode) return reachedTarget;
    if (reachedTarget) return true; // hızlı doğrulama

    switch (lv.goalType) {
      case GoalType.reachValue:
        return reachedTarget;
      case GoalType.clearBlockers:
        return blockersRemaining <= 0;
      case GoalType.comboCount:
        return bestComboThisLevel >= lv.goalAmount;
    }
  }

  String? _praise(int n) {
    if (lang == AppLang.tr) {
      if (n >= 12) return 'OLAĞANÜSTÜ!';
      if (n >= 10) return 'MÜKEMMEL!';
      if (n >= 8) return 'SÜPER!';
      if (n >= 6) return 'HARİKA!';
      if (n >= 4) return 'GÜZEL!';
    } else {
      if (n >= 12) return 'OUTSTANDING!';
      if (n >= 10) return 'EXCELLENT!';
      if (n >= 8) return 'SUPER!';
      if (n >= 6) return 'GREAT!';
      if (n >= 4) return 'NICE!';
    }
    return null;
  }

  Future<void> _sfxLight() async {
    if (!sfxOn) return;
    await HapticFeedback.selectionClick();
  }

  Future<void> _sfxMerge() async {
    if (!sfxOn) return;
    await HapticFeedback.mediumImpact();
  }

  Pos? _cellFromLocal(Offset local, Size boardSize) {
    final innerW = boardSize.width - boardPadding * 2;
    final innerH = boardSize.height - boardPadding * 2;
    final cw = (innerW - cellGap * (cols - 1)) / cols;
    final ch = (innerH - cellGap * (rows - 1)) / rows;
    final x = local.dx - boardPadding, y = local.dy - boardPadding;
    if (x < 0 || y < 0 || x > innerW || y > innerH) return null;
    final c = (x / (cw + cellGap)).floor(), r = (y / (ch + cellGap)).floor();
    if (r < 0 || r >= rows || c < 0 || c >= cols) return null;
    final lx = x - c * (cw + cellGap), ly = y - r * (ch + cellGap);
    if (lx > cw || ly > ch) return null;
    return Pos(r, c);
  }

  Offset _cellCenter(Pos p, Size boardSize) {
    final innerW = boardSize.width - boardPadding * 2;
    final innerH = boardSize.height - boardPadding * 2;
    final cw = (innerW - cellGap * (cols - 1)) / cols;
    final ch = (innerH - cellGap * (rows - 1)) / rows;
    return Offset(boardPadding + p.c * (cw + cellGap) + cw / 2, boardPadding + p.r * (ch + cellGap) + ch / 2);
  }

  Future<void> _shakeCell(Pos p) async {
    final key = _k(p.r, p.c);
    for (final a in [7.0, -6.0, 5.0, -4.0, 2.0, 0.0]) {
      cellShakeAmp[key] = a;
      setState(() {});
      await Future.delayed(Duration(milliseconds: fxMode == FxMode.high ? 20 : 12));
    }
    cellShakeAmp.remove(key);
    setState(() {});
  }

  Future<void> _mergePopAnimation(Set<Pos> popCells) async {
    if (fxMode == FxMode.low) {
      poppedCells = popCells;
      hidePoppedTargets = true;
      setState(() {});
      await Future.delayed(const Duration(milliseconds: 60));
      hidePoppedTargets = false;
      poppedCells = {};
      setState(() {});
      return;
    }
    poppedCells = popCells;
    showMergePop = true;
    hidePoppedTargets = false;
    setState(() {});
    await Future.delayed(const Duration(milliseconds: 150));
    hidePoppedTargets = true;
    setState(() {});
    await Future.delayed(const Duration(milliseconds: 70));
    showMergePop = false;
    hidePoppedTargets = false;
    poppedCells = {};
    setState(() {});
  }

  List<Color> _comboColors(int c) {
    if (c >= 12) return const [Color(0xFFFFFFFF), Color(0xFF00E5FF), Color(0xFFFFEA00), Color(0xFFFF1744)];
    if (c >= 10) return const [Color(0xFFB388FF), Color(0xFFFF80AB), Color(0xFF69F0AE)];
    if (c >= 8) return const [Color(0xFF40C4FF), Color(0xFFFFAB40), Color(0xFFFF5252)];
    if (c >= 6) return const [Color(0xFF7C4DFF), Color(0xFF18FFFF), Color(0xFFFFD740)];
    return const [Color(0xFFFFFFFF), Color(0xFFB0BEC5)];
  }

  void _spawnComboParticles(Offset center, int comboCount) {
    if (fxMode == FxMode.low) {
      showParticles = false;
      particles = [];
      return;
    }
    showParticles = true;
    final palette = _comboColors(comboCount);
    final int count = 18 + min(comboCount, 20).toInt();
    particles = List.generate(count, (i) {
      final angle = (i / count) * pi * 2 + rnd.nextDouble() * 0.2;
      final speed = 38 + rnd.nextDouble() * (40 + comboCount * 2);
      final color = palette[i % palette.length];
      return Particle(center, angle, speed, color);
    });
    setState(() {});
  }

  Future<void> _applyGravityAndRefill() async {
    final anim = <FallingTile>[];
    final seed = _spawnPoolForLevel(lv.index);

    for (int c = 0; c < cols; c++) {
      final vals = <Cell>[];
      final fromRows = <int>[];

      for (int r = rows - 1; r >= 0; r--) {
        final cell = grid[r][c];
        if (cell.value != 0 || cell.blocked || cell.frozen) {
          vals.add(Cell(cell.value, blocked: cell.blocked, frozen: cell.frozen));
          fromRows.add(r);
        }
      }

      int wr = rows - 1;
      int i = 0;
      while (i < vals.length) {
        final cell = vals[i];
        final fr = fromRows[i];
        grid[wr][c] = Cell(cell.value, blocked: cell.blocked, frozen: cell.frozen);
        if (fr != wr) {
          anim.add(FallingTile(fromR: fr, toR: wr, c: c, value: cell.value, blocked: cell.blocked, frozen: cell.frozen));
        }
        wr--;
        i++;
      }

      while (wr >= 0) {
        final v = seed[rnd.nextInt(seed.length)];
        bool f = false;
        if (lv.frozenEnabled && rnd.nextDouble() < 0.08) f = true;
        grid[wr][c] = Cell(v, blocked: false, frozen: f);
        anim.add(FallingTile(fromR: -1 - wr, toR: wr, c: c, value: v, blocked: false, frozen: f));
        wr--;
      }
    }

    fallingTiles = anim;
    showFallLayer = true;
    setState(() {});
    await Future.delayed(Duration(milliseconds: fxMode == FxMode.high ? 340 : 130));
    showFallLayer = false;
    setState(() {});
  }

  Future<void> _checkLevelState() async {
    if (_isLevelGoalCompleted()) {
      final earned = max(1, _swapReward(moves));
      swaps += earned;
      await _submitLb();

      await _saveProgress();
      if (!mounted) return;

      // Level Complete kısa animasyon (700ms) + auto-next öncesi küçük gecikme efekti
      await Future.delayed(const Duration(milliseconds: 700));
      if (!mounted) return;

      if (autoNextOn) {
        await Future.delayed(const Duration(milliseconds: 280)); // tiny continue-delay
        if (!mounted) return;

        _startLevel(levelIdx + 1);

        _rebuildValueColorMapFromGrid();
        await _saveProgress();
        if (mounted) setState(() {});
      }
      return;
    } else if (moves > lv.move1) {
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          backgroundColor: const Color(0xFF171129),
          title: Text(lang == AppLang.tr ? 'Başarısız' : 'Failed', style: _neon(const Color(0xFFFF4DFF), 22)),
          content: Text(lang == AppLang.tr ? '60 hamleyi aştın.' : 'You exceeded 60 moves.'),
          actions: [
            FilledButton(
              onPressed: () {
                Navigator.pop(context);
                _startLevel(levelIdx);
                  _rebuildValueColorMapFromGrid();
              },
              child: Text(lang == AppLang.tr ? 'Yeniden Dene' : 'Try Again'),
            ),
          ],
        ),
      );
    }
  }

  // ---------- UI Text ----------
  String t(String key) {
    const tr = {
      'title':'MERGE BLOCKS NEON CHAIN','level':'','score':'Skor','best':'En iyi','max':'En büyük','target':'','move':'Hamle',
      'mode':'Mod','campaign':'Kampanya','endless':'Sonsuz',
      'episode':'','goal':'Özel ','unlocked':'Açık ',
      'language':'Dil','numfmt':'Sayı','tr':'TR','en':'EN',
      'sfx':'Ses Efektleri','fx':'Performans','low':'Düşük FX','high':'Yüksek FX',
      'test':''
    };
    const en = {
      'title':'MERGE BLOCKS NEON CHAIN','level':'Level','score':'Score','best':'Best','max':'Max','target':'Target','move':'Move',
      'mode':'Mode','campaign':'Campaign','endless':'Endless',
      'episode':'','goal':'Special Goal','unlocked':'Unlocked',
      'language':'Language','numfmt':'Number','tr':'TR','en':'EN',
      'sfx':'Sound FX','fx':'Performance','low':'Low FX','high':'High FX',
      'test':'Test Mode'
    };
    return (lang == AppLang.tr ? tr : en)[key] ?? key;
  }


  String _episodeRuleText(LevelConfig cfg) {
    if (lang == AppLang.tr) {
      if (cfg.goalType == GoalType.clearBlockers) return 'Engeller zincire dahil olmaz. Önce engelleri temizle.';
      if (cfg.goalType == GoalType.comboCount) return 'Bu episode’da güçlü kombolar hedeflenir.';
      if (cfg.frozenEnabled) return 'Buzlu hücreler önce çözülmeli, sonra birleştirilebilir.';
      if (cfg.valueGateEnabled && cfg.valueGateMin != null) return 'Sadece ${shortNumInt(cfg.valueGateMin!)} ve üzeri değerler bağlanabilir.';
      return 'Standart kurallar: Aynı değer veya 2 katı değer bağlanır.';
    } else {
      if (cfg.goalType == GoalType.clearBlockers) return 'Blockers cannot be chained. Clear blockers first.';
      if (cfg.goalType == GoalType.comboCount) return 'This episode focuses on strong combos.';
      if (cfg.frozenEnabled) return 'Frozen cells must be thawed before merge.';
      if (cfg.valueGateEnabled && cfg.valueGateMin != null) return 'Only ${shortNumInt(cfg.valueGateMin!)} and above can be linked.';
      return 'Standard rules: Link same value or double value.';
    }
  }

    Future<void> _maybeShowIntro() async {
    // Her bölüm başlangıcında göster (test mode dahil) - PREMIUM / 2x süre
    final lvl = lv.index;
    final targetTxt = shortNumBig(lv.targetBig);

    showIntro = true;

    // Faz 1: 
    episodeIntroTitle = (lang == AppLang.tr) ? 'BÖLÜM $lvl' : 'LEVEL $lvl';
    episodeIntroRule = (lang == AppLang.tr) ? 'Hazır mısın?' : 'Are you ready?';
    if (mounted) setState(() {});
    await Future.delayed(const Duration(milliseconds: 2000)); // ~2x

    if (!mounted || !showIntro) return;

    // Faz 2: 
    episodeIntroTitle = (lang == AppLang.tr) ? 'HEDEF' : 'TARGET';
    episodeIntroRule = targetTxt;
    if (mounted) setState(() {});
    await Future.delayed(const Duration(milliseconds: 2600)); // ~2x

    if (!mounted || !showIntro) return;

    // Faz 3:  + kural
    episodeIntroTitle = 'EPISODE: ${lv.episodeName.toUpperCase()}';
    episodeIntroRule = _episodeRuleText(lv);
    if (mounted) setState(() {});
    await Future.delayed(const Duration(milliseconds: 2600)); // ~2x

    if (!mounted) return;
    showIntro = false;
    if (mounted) setState(() {});
  }

  Future<void> _maybeShowBlockerTooltip() async {
    if (lv.goalType != GoalType.clearBlockers && lv.blockerCount <= 0) return;
    final p = await SharedPreferences.getInstance();
    final seen = p.getBool(_kBlockerTipSeen) ?? false;
    if (seen) return;
    showBlockerTip = true;
    if (mounted) setState(() {});
    await Future.delayed(const Duration(milliseconds: 2200));
    showBlockerTip = false;
    if (mounted) setState(() {});
    await p.setBool(_kBlockerTipSeen, true);
  }


  // Küsuratsız kısa sayı
  String shortNumBig(BigInt n) {
    if (n < BigInt.from(1000)) return n.toString();

    String clean(BigInt scaled) {
      if (scaled < BigInt.from(10)) return scaled.toString();
      if (scaled < BigInt.from(100)) {
        final v = scaled.toInt();
        final r = ((v + 2) ~/ 5) * 5; // en yakın 5
        return r.toString();
      }
      final v = scaled.toInt();
      final r = ((v + 25) ~/ 50) * 50; // en yakın 50
      return r.toString();
    }

    if (numFmt == NumFmt.en) {
      const suf = ['K', 'M', 'B', 'T', 'Qa', 'Qi', 'Sx', 'Sp', 'Oc', 'No'];
      BigInt unit = BigInt.one;
      int i = -1;
      while (i < suf.length - 1 && (n ~/ unit) >= BigInt.from(1000)) {
        unit *= BigInt.from(1000);
        i++;
      }
      return '${clean(n ~/ unit)}${suf[i]}';
    } else {
      const suf = ['B', 'Mn', 'Mr', 'Tr', 'Ktr', 'Kent', 'Sek', 'Sep', 'Ok', 'Non'];
      BigInt unit = BigInt.one;
      int i = -1;
      while (i < suf.length - 1 && (n ~/ unit) >= BigInt.from(1000)) {
        unit *= BigInt.from(1000);
        i++;
      }
      return '${clean(n ~/ unit)}${suf[i]}';
    }
  }

  String shortNumInt(int n) => shortNumBig(BigInt.from(n));

  // stable palette
  Color _tileColor(int v) => _colorForValue(v);

  TextStyle _neon(Color c, double s) => TextStyle(
        color: c,
        fontSize: s,
        fontWeight: FontWeight.w900,
        shadows: [
          Shadow(color: c.withValues(alpha: 0.95), blurRadius: 10),
          Shadow(color: c.withValues(alpha: 0.45), blurRadius: 22),
        ],
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0A16),
      appBar: AppBar(
        backgroundColor: const Color(0xFF17132C),
        title: Text('${t('title')} • ${t('mode')}: ${t('endless')}',
            style: _neon(const Color(0xFF39FF14), 18)),
        centerTitle: true,
        actions: [
          if (testMode)
            IconButton(
              tooltip: '',
              onPressed: _quickSkipLevel,
              icon: const Icon(Icons.skip_next),
            ),
          IconButton(onPressed: _showLeaderboardDialog, icon: const Icon(Icons.emoji_events)),
          PopupMenuButton<String>(
            icon: const Icon(Icons.settings),
            onSelected: (v) async {
              if (v == 'quick_skip') {
                _quickSkipLevel();
                return;
              }
              setState(() {
                if (v == 'lang_tr') lang = AppLang.tr;
                if (v == 'lang_en') lang = AppLang.en;
                if (v == 'num_tr') numFmt = NumFmt.tr;
                if (v == 'num_en') numFmt = NumFmt.en;
                if (v == 'sfx') sfxOn = !sfxOn;
                if (v == 'fx_low') fxMode = FxMode.low;
                if (v == 'fx_high') fxMode = FxMode.high;
                if (v == 'auto_next') autoNextOn = !autoNextOn;
                if (v == 'test') testMode = !testMode;
                if (v == 'mode_campaign') {
                  mode = GameMode.endless;
                  levelIdx = (unlockedCampaign - 1).clamp(0, 99);
                  _startLevel(levelIdx);
                  _rebuildValueColorMapFromGrid();
                }
                if (v == 'mode_endless') {
                  mode = GameMode.endless;
                  if (levelIdx < 100) levelIdx = 100;
                  _startLevel(levelIdx);
                  _rebuildValueColorMapFromGrid();
                }
              });
              await _saveProgress();
            },
            itemBuilder: (_) => [              PopupMenuItem(value: 'sfx', child: Text('${t('sfx')}: ${sfxOn ? "ON" : "OFF"}')),
              PopupMenuItem(value: 'fx_high', child: Text('${t('fx')}: ${t('high')}')),
              PopupMenuItem(value: 'fx_low', child: Text('${t('fx')}: ${t('low')}')),            ],
          ),
          IconButton(onPressed: () => _startLevel(levelIdx), icon: const Icon(Icons.replay)),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          child: Column(
            children: [
              const SizedBox.shrink(),
              const SizedBox(height: 6),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, c) {
                    const toolW = 120.0;
                    final usableW = max(120.0, c.maxWidth - toolW * 2 - 8);
                    final usableH = c.maxHeight;
                    final ratio = rows / cols;

                    double boardW = usableW;
                    double boardH = boardW * ratio;
                    if (boardH > usableH) {
                      boardH = usableH;
                      boardW = boardH / ratio;
                    }
                    final boardSize = Size(boardW, boardH);

                    return Row(
                      children: [
                        SizedBox(width: toolW, child: _sidePanelLeft()), // tüm ikonlar burada
                        Expanded(
                          child: Center(
                            child: SizedBox(
                              width: boardW,
                              height: boardH,
                              child: _buildBoard(boardSize),
                            ),
                          ),
                        ),
                        SizedBox(width: toolW, child: _adPanelRight()), // boş tarafa reklam alanı
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sidePanelLeft() {
    return LayoutBuilder(
      builder: (context, c) => SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: c.maxHeight),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
        _sideBtn(
          icon: swapMode ? Icons.close : Icons.swap_horiz,
          label: '$swaps',
          onTap: (swaps > 0 && !isBusy)
              ? () {
                  setState(() {
                    swapMode = !swapMode;
                    if (!swapMode) swapFirst = null;
                  });
                  _saveProgress();
                }
              : null,
        ),
        const SizedBox(height: 6),
        _sideBtn(
          icon: Icons.play_circle_fill,
          label: '+1',
          onTap: !isBusy
              ? () async {
                  final ready = await adService.isAdReady();
                  if (!ready) await adService.loadAd();
                  await adService.showAd(onReward: () {
                    setState(() => swaps++);
                    _saveProgress();
                  });
                }
              : null,
        ),
        const SizedBox(height: 6),
        _sideBtn(icon: Icons.emoji_events, label: 'TOP', onTap: _showLeaderboardDialog),
            ],
          ),
        ),
      ),
    );
  }

  Widget _adPanelRight() {
    // Reklam SDK bağlama noktası: gerçek banner widget buraya yerleştirilebilir.
    return LayoutBuilder(
      builder: (context, c) => SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: c.maxHeight),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 52,
                height: 210,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF1A1533), Color(0xFF0F0B23)],
                  ),
                  border: Border.all(color: const Color(0xFF6A52D9), width: 1.2),
                  boxShadow: const [BoxShadow(color: Color(0x3300E5FF), blurRadius: 8)],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.campaign, color: Color(0xFF00E5FF), size: 18),
                    const SizedBox(height: 8),
                    RotatedBox(
                      quarterTurns: 3,
                      child: Text(
                        lang == AppLang.tr ? 'REKLAM BANNER' : 'AD BANNER',
                        style: const TextStyle(
                          color: Color(0xFFB0BEC5),
                          fontWeight: FontWeight.w800,
                          fontSize: 10,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: 34,
                      height: 70,
                      decoration: BoxDecoration(
                        color: const Color(0x2211CFFF),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0x5588E5FF)),
                      ),
                      alignment: Alignment.center,
                      child: const Text(
                        '320x50 / Adaptive',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF90A4AE),
                          fontSize: 8,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }


  Widget _sideBtn({required IconData icon, required String label, VoidCallback? onTap}) {
    return Material(
      color: const Color(0xFF231B42),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          width: 48,
          height: 56,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF6A52D9), width: 1.2),
            boxShadow: const [BoxShadow(color: Color(0x3300E5FF), blurRadius: 8)],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 22, color: Colors.white),
              if (label.isNotEmpty) Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800)),
            ],
          ),
        ),
      ),
    );
  }


  bool _isFallTarget(int r, int c) {
    for (final t in fallingTiles) {
      if (t.toR == r && t.c == c) return true;
    }
    return false;
  }

  Widget _buildBoard(Size boardSize) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (d) async {
        final p = _cellFromLocal(d.localPosition, boardSize);
        if (p == null || isBusy) return;

        if (swapMode && swaps > 0) {
          await _sfxLight();
          if (swapFirst == null) {
            final cell = grid[p.r][p.c];
            if (cell.blocked || cell.frozen) return;
            swapFirst = p;
            setState(() {});
          } else {
            final a = swapFirst!, b = p;
            if (_isOrthogonalOneStep(a, b) &&
                !grid[a.r][a.c].blocked && !grid[a.r][a.c].frozen &&
                !grid[b.r][b.c].blocked && !grid[b.r][b.c].frozen) {
              isBusy = true;
              final tmp = grid[a.r][a.c].value;
              grid[a.r][a.c].value = grid[b.r][b.c].value;
              grid[b.r][b.c].value = tmp;
              swaps--;
              moves++;
              swapFirst = null;
              swapMode = false;
              isBusy = false;
              _saveProgress();
              setState(() {});
              await _checkLevelState();
// Hard fallback: in case any async dialog/animation branch short-circuits in web build
if (_isLevelGoalCompleted() && mounted) {
  await Future.delayed(const Duration(milliseconds: 40));
  if (mounted) await _checkLevelState();
}
            } else {
              await _shakeCell(b);
            }
          }
        }
      },
      onPanStart: (d) {
        if (isBusy || swapMode) return;
        final p = _cellFromLocal(d.localPosition, boardSize);
        if (p == null) return;
        final cell = grid[p.r][p.c];
        if (cell.blocked || cell.frozen) return;
        selected.add(_k(p.r, p.c));
        path.add(p);
        _sfxLight();
        setState(() {});
      },
      onPanUpdate: (d) {
        if (isBusy || swapMode || path.isEmpty) return;
        final p = _cellFromLocal(d.localPosition, boardSize);
        if (p == null) return;
        final cell = grid[p.r][p.c];
        if (cell.blocked || cell.frozen) return;

        final key = _k(p.r, p.c), last = path.last;
        if (path.length >= 2) {
          final prev = path[path.length - 2];
          if (prev.r == p.r && prev.c == p.c) {
            selected.remove(_k(last.r, last.c));
            path.removeLast();
            setState(() {});
            return;
          }
        }

        if (selected.contains(key)) return;

        if (!_canLink(last, p)) {
          _shakeCell(p);
          return;
        }

        selected.add(key);
        path.add(p);
        if (fxMode == FxMode.high) _sfxLight();
        setState(() {});
      },
      onPanEnd: (_) async {
        if (isBusy || swapMode) return;

        if (path.length < 2) {
          selected.clear();
          path.clear();
          setState(() {});
          return;
        }

        isBusy = true;
        moves++;

        final target = path.last;
        final merged = _mergedValue(path);

        if (path.length > bestComboThisLevel) bestComboThisLevel = path.length;
        final pop = <Pos>{};
        for (int i = 0; i < path.length - 1; i++) pop.add(path[i]);

        await _mergePopAnimation(pop);
        await _damageAdjacentBlockers(pop.toList());

        for (final pp in pop) {
          final c = grid[pp.r][pp.c];
          if (c.blocked) {
            c.blocked = false;
            blockersRemaining = max(0, blockersRemaining - 1);
          }
          if (c.frozen) {
            c.frozen = false; // first touch to break freeze
          }
          c.value = 0;
        }

        final tCell = grid[target.r][target.c];
        if (tCell.frozen) {
          // frozen target önce çözülsün
          tCell.frozen = false;
        }
        tCell.value = merged;
        tCell.blocked = false;

        score += merged + path.length * 18;
        if (score > best) best = score;

        await _sfxMerge();
        _spawnComboParticles(_cellCenter(target, boardSize), path.length);
        await _applyGravityAndRefill();
        _rebuildValueColorMapFromGrid();

        final pr = _praise(path.length);
        if (pr != null) {
          praiseText = pr;
          showPraise = true;
          setState(() {});
          await Future.delayed(Duration(milliseconds: fxMode == FxMode.high ? 700 : 250));
          showPraise = false;
        }

        selected.clear();
        path.clear();
        showParticles = false;
        isBusy = false;
        await _saveProgress();
        setState(() {});
        await _checkLevelState();
      },
      child: AnimatedBuilder(
        animation: Listenable.merge([glowCtrl, energyCtrl]),
        builder: (_, __) => Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF120F22),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF46378A), width: 2),
              ),
            ),
            Positioned.fill(child: Padding(padding: const EdgeInsets.all(boardPadding), child: _buildFixedGrid(boardSize))),
            IgnorePointer(
              child: CustomPaint(
                size: boardSize,
                painter: PathPainter(
                  path: path,
                  rows: rows,
                  cols: cols,
                  glow: glowAnim.value,
                  energyPhase: fxMode == FxMode.high ? energyAnim.value : 0.0,
                  boardPadding: boardPadding,
                  gap: cellGap,
                  lowFx: fxMode == FxMode.low,
                ),
              ),
            ),
            if (showMergePop && fxMode == FxMode.high)
              Positioned.fill(
                child: IgnorePointer(
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: 1.0),
                    duration: const Duration(milliseconds: 190),
                    builder: (_, t, __) => CustomPaint(
                      size: boardSize,
                      painter: PopPainter(
                        cells: poppedCells.toList(),
                        rows: rows,
                        cols: cols,
                        t: t,
                        boardPadding: boardPadding,
                        gap: cellGap,
                      ),
                    ),
                  ),
                ),
              ),
            if (showParticles && fxMode == FxMode.high)
              Positioned.fill(
                child: IgnorePointer(
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: 1.0),
                    duration: const Duration(milliseconds: 420),
                    builder: (_, t, __) => CustomPaint(
                      size: boardSize,
                      painter: ParticlesPainter(particles: particles, t: Curves.easeOut.transform(t)),
                    ),
                  ),
                ),
              ),
            if (showFallLayer)
              Positioned.fill(
                child: IgnorePointer(
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: 1.0),
                    duration: Duration(milliseconds: fxMode == FxMode.high ? 330 : 120),
                    builder: (_, t, __) => CustomPaint(
                      size: boardSize,
                      painter: FallingPainter(
                        tiles: fallingTiles,
                        rows: rows,
                        cols: cols,
                        colorFor: _tileColor,
                        shortNum: shortNumInt,
                        t: Curves.easeInOut.transform(t),
                        boardPadding: boardPadding,
                        gap: cellGap,
                      ),
                    ),
                  ),
                ),
              ),
            if (showBlockerTip)
              Positioned(
                top: 12,
                left: 12,
                right: 12,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.85, end: 1.0),
                  duration: const Duration(milliseconds: 260),
                  builder: (_, s, child) => Transform.scale(scale: s, child: child),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xEE1A1430),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFFFAB40)),
                      boxShadow: const [BoxShadow(color: Color(0x55000000), blurRadius: 10)],
                    ),
                    child: Text(
                      lang == AppLang.tr
                          ? '🔒 Bu hücreler zincire dahil olmaz. Yanında birleşme yaparak kır (HP:3)'
                          : '🔒 These cells cannot be chained',
                      textAlign: TextAlign.center,
                      style: _neon(const Color(0xFFFFD740), 16),
                    ),
                  ),
                ),
              ),
            if (showIntro)
              Positioned.fill(
                child: GestureDetector(
                  onTap: () {
                    showIntro = false;
                    setState(() {});
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: const Alignment(0, -0.15),
                        radius: 0.95,
                        colors: [
                          const Color(0xCC1A1240),
                          const Color(0xE60E0A22),
                          Colors.black.withValues(alpha: 0.88),
                        ],
                      ),
                    ),
                    child: Center(
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.84, end: 1.0),
                        duration: const Duration(milliseconds: 560),
                        curve: Curves.elasticOut,
                        builder: (_, s, child) => Transform.scale(scale: s, child: child),
                        child: Container(
                          constraints: const BoxConstraints(maxWidth: 520),
                          padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 20),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(28),
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xFF35206E), Color(0xFF1B143B), Color(0xFF0F0B23)],
                            ),
                            border: Border.all(color: const Color(0xFF00E5FF), width: 1.8),
                            boxShadow: const [
                              BoxShadow(color: Color(0xAA00E5FF), blurRadius: 22, spreadRadius: 1),
                              BoxShadow(color: Color(0x66FF4DFF), blurRadius: 30, spreadRadius: 1),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.auto_awesome, color: Color(0xFFFFD740), size: 30),
                              const SizedBox(height: 8),
                              Text(
                                episodeIntroTitle,
                                style: _neon(const Color(0xFF39FF14), 36),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: const Color(0x4411CFFF),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0x8892F1FF)),
                                ),
                                child: Text(
                                  episodeIntroRule,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 18,
                                    letterSpacing: 0.2,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                lang == AppLang.tr ? 'Geçmek için dokun' : 'Tap to skip',
                                style: const TextStyle(
                                  color: Color(0xCCB0BEC5),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            if (showPraise)
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    gradient: const LinearGradient(colors: [Color(0xFFFFB300), Color(0xFFFF7043), Color(0xFFE53935)]),
                  ),
                  child: Text(praiseText, style: _neon(Colors.white, 28)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFixedGrid(Size boardSize) {
        final int maxOnBoard = _maxTileBig().toInt();
final innerW = boardSize.width - boardPadding * 2, innerH = boardSize.height - boardPadding * 2;
    final cw = (innerW - cellGap * (cols - 1)) / cols, ch = (innerH - cellGap * (rows - 1)) / rows;
    final children = <Widget>[];

    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        final cell = grid[r][c];
        final sel = selected.contains(_k(r, c));
        final sw = swapFirst != null && swapFirst!.r == r && swapFirst!.c == c;
        final hiddenByPop = hidePoppedTargets && poppedCells.contains(Pos(r, c));
        final fadeByFall = showFallLayer && _isFallTarget(r, c);
        final visible = !(hiddenByPop || fadeByFall);
        final key = _k(r, c);
        final shake = (cellShakeAmp[key] ?? 0.0) + ((blockerHitShake[key] ?? 0.0) * 1.2);

        Color blockerColor() {
          final total = max(1, lv.blockerCount);
          final ratio = (blockersRemaining / total).clamp(0.0, 1.0);
          if (ratio > 0.66) return const Color(0xFF5D4037); // kahve
          if (ratio > 0.33) return const Color(0xFFE65100); // turuncu
          return const Color(0xFFB71C1C); // kırmızı
        }

        final base = cell.blocked
            ? blockerColor()
            : cell.frozen
                ? const Color(0xFF455A64)
                : _tileColor(cell.value);

        final hsl = HSLColor.fromColor(base);
        final hi = hsl.withLightness((hsl.lightness + 0.11).clamp(0, 1).toDouble()).toColor();
        final lo = hsl.withLightness((hsl.lightness - 0.10).clamp(0, 1).toDouble()).toColor();

        children.add(Positioned(
          left: c * (cw + cellGap) + shake,
          top: r * (ch + cellGap),
          width: cw,
          height: ch,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 80),
            opacity: visible ? 1.0 : 0.0,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(13),
                gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [hi, base, lo]),
                border: Border.all(
                  color: sw ? Colors.cyanAccent : (sel ? Colors.white : Colors.black26),
                  width: sw ? 3 : (sel ? 2 : 1),
                ),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 7, offset: const Offset(0, 3)),
                  if (sel) BoxShadow(color: Colors.white.withValues(alpha: glowAnim.value), blurRadius: 8),
                ],
              ),
              child: Stack(
                children: [
                  Positioned(left: 5, right: 5, top: 4, child: Container(height: 8, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.22), borderRadius: BorderRadius.circular(8)))),
                  Center(
                    child: cell.blocked
                        ? Transform.scale(
                            scale: 1.0 + (0.08 * sin(glowAnim.value * pi * 2)),
                            child: Column(mainAxisSize: MainAxisSize.min, children: [

                        if (cell.blocked && (blockerHitFlash[key] ?? 0.0) > 0)
                          SizedBox.expand(
                            child: IgnorePointer(
                              child: Opacity(
                                opacity: (blockerHitFlash[key] ?? 0.0) * 0.45,
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(14),
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),

                                  Icon(Icons.lock, color: Colors.white.withValues(alpha: 0.95), size: 16),
                                  Text('HP ${cell.blockerHp}', style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900)),
                                ]),
                          )
                        : cell.frozen
                            ? const Icon(Icons.ac_unit, color: Colors.white, size: 17)
                            : Stack(
                                clipBehavior: Clip.none,
                                alignment: Alignment.center,
                                children: [
                                  Text(
                                    shortNumInt(cell.value),
                                    style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                      fontSize: cell.value >= 1000000 ? 14 : (cell.value >= 10000 ? 17 : 21),
                                      shadows: const [Shadow(color: Colors.black54, blurRadius: 5)],
                                    ),
                                  ),
                                  if (maxOnBoard >= 2048 && cell.value == maxOnBoard)
                                    const Positioned(
                                      top: -12,
                                      child: Text('👑', style: TextStyle(fontSize: 20)),
                                    ),
                                ],
                              ),
                  ),
                ],
              ),
            ),
          ),
        ));
      }
    }

    return Stack(children: children);
  }
}

// ---------- Painters ----------
class PathPainter extends CustomPainter {
  final List<Pos> path;
  final int rows, cols;
  final double glow, energyPhase, boardPadding, gap;
  final bool lowFx;
  PathPainter({
    required this.path,
    required this.rows,
    required this.cols,
    required this.glow,
    required this.energyPhase,
    required this.boardPadding,
    required this.gap,
    required this.lowFx,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (path.length < 2) return;
    final innerW = size.width - boardPadding * 2, innerH = size.height - boardPadding * 2;
    final cw = (innerW - gap * (cols - 1)) / cols, ch = (innerH - gap * (rows - 1)) / rows;

    for (int i = 0; i < path.length - 1; i++) {
      final p1 = path[i], p2 = path[i + 1];
      final x1 = boardPadding + p1.c * (cw + gap) + cw / 2;
      final y1 = boardPadding + p1.r * (ch + gap) + ch / 2;
      final x2 = boardPadding + p2.c * (cw + gap) + cw / 2;
      final y2 = boardPadding + p2.r * (ch + gap) + ch / 2;

      final t = (i + 1) / max(1, path.length - 1);
      final base = Color.lerp(const Color(0xFF7C4DFF), const Color(0xFF00E5FF), t) ?? const Color(0xFF7C4DFF);
      final dark = HSLColor.fromColor(base).withLightness((0.62 - 0.30 * t).clamp(0.18, 0.62)).toColor();

      final mainPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = lowFx ? 6 : 10
        ..strokeCap = StrokeCap.round
        ..shader = LinearGradient(colors: [dark.withValues(alpha: 0.9), dark]).createShader(Rect.fromPoints(Offset(x1, y1), Offset(x2, y2)));

      if (!lowFx) {
        final glowPaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 16
          ..strokeCap = StrokeCap.round
          ..shader = LinearGradient(colors: [dark.withValues(alpha: 0.55), dark.withValues(alpha: 0.95)]).createShader(Rect.fromPoints(Offset(x1, y1), Offset(x2, y2)))
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
        canvas.drawLine(Offset(x1, y1), Offset(x2, y2), glowPaint);
      }

      canvas.drawLine(Offset(x1, y1), Offset(x2, y2), mainPaint);

      if (!lowFx) {
        final local = (energyPhase + i * 0.17) % 1.0;
        final ex = x1 + (x2 - x1) * local;
        final ey = y1 + (y2 - y1) * local;
        final eColor = Color.lerp(Colors.white, const Color(0xFF00E5FF), t)!.withValues(alpha: 0.95);
        final ePaint = Paint()..color = eColor..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
        canvas.drawCircle(Offset(ex, ey), 6.0, ePaint);
        canvas.drawCircle(Offset(ex, ey), 2.6, Paint()..color = Colors.white.withValues(alpha: 0.95));
      }

      final shine = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = lowFx ? 2 : 4
        ..strokeCap = StrokeCap.round
        ..color = Colors.white.withValues(alpha: (0.42 - 0.18 * t + glow * 0.15).clamp(0.12, 0.58));
      canvas.drawLine(Offset(x1, y1), Offset(x2, y2), shine);
    }
  }

  @override
  bool shouldRepaint(covariant PathPainter old) =>
      old.path != path || old.glow != glow || old.energyPhase != energyPhase || old.lowFx != lowFx;
}

class PopPainter extends CustomPainter {
  final List<Pos> cells;
  final int rows, cols;
  final double t, boardPadding, gap;
  PopPainter({required this.cells, required this.rows, required this.cols, required this.t, required this.boardPadding, required this.gap});

  @override
  void paint(Canvas canvas, Size size) {
    if (cells.isEmpty) return;
    final innerW = size.width - boardPadding * 2, innerH = size.height - boardPadding * 2;
    final cw = (innerW - gap * (cols - 1)) / cols, ch = (innerH - gap * (rows - 1)) / rows;
    final scale = 1.0 - 0.7 * t, alpha = (1.0 - t).clamp(0.0, 1.0);

    for (final c in cells) {
      final cx = boardPadding + c.c * (cw + gap) + cw / 2, cy = boardPadding + c.r * (ch + gap) + ch / 2;
      final rect = Rect.fromCenter(center: Offset(cx, cy), width: cw * scale, height: ch * scale);
      canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(12)), Paint()..color = Colors.white.withValues(alpha: 0.65 * alpha));
    }
  }

  @override
  bool shouldRepaint(covariant PopPainter old) => old.t != t || old.cells != cells;
}

class ParticlesPainter extends CustomPainter {
  final List<Particle> particles;
  final double t;
  ParticlesPainter({required this.particles, required this.t});
  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final dx = cos(p.angle) * p.speed * t, dy = sin(p.angle) * p.speed * t;
      final pos = Offset(p.origin.dx + dx, p.origin.dy + dy);
      canvas.drawCircle(pos, 1.7 + (1 - t) * 2.0, Paint()..color = p.color.withValues(alpha: (1 - t).clamp(0.0, 1.0)));
    }
  }
  @override
  bool shouldRepaint(covariant ParticlesPainter old) => old.t != t || old.particles != particles;
}

class FallingPainter extends CustomPainter {
  final List<FallingTile> tiles;
  final int rows, cols;
  final Color Function(int) colorFor;
  final String Function(int) shortNum;
  final double t, boardPadding, gap;
  FallingPainter({
    required this.tiles,
    required this.rows,
    required this.cols,
    required this.colorFor,
    required this.shortNum,
    required this.t,
    required this.boardPadding,
    required this.gap,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (tiles.isEmpty) return;
    final innerW = size.width - boardPadding * 2, innerH = size.height - boardPadding * 2;
    final cw = (innerW - gap * (cols - 1)) / cols, ch = (innerH - gap * (rows - 1)) / rows;

    for (final tile in tiles) {
      final fromY = boardPadding + tile.fromR * (ch + gap) + ch / 2;
      final toY = boardPadding + tile.toR * (ch + gap) + ch / 2;
      final x = boardPadding + tile.c * (cw + gap) + cw / 2;
      final y = fromY + (toY - fromY) * t;

      final rect = Rect.fromCenter(center: Offset(x, y), width: cw, height: ch);
      final rr = RRect.fromRectAndRadius(rect, const Radius.circular(13));

      final base = tile.blocked
          ? const Color(0xFF5D4037)
          : tile.frozen
              ? const Color(0xFF455A64)
              : colorFor(tile.value);

      final hsl = HSLColor.fromColor(base);
      final hi = hsl.withLightness((hsl.lightness + 0.11).clamp(0, 1).toDouble()).toColor();
      final lo = hsl.withLightness((hsl.lightness - 0.10).clamp(0, 1).toDouble()).toColor();

      final fill = Paint()..shader = LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [hi, base, lo]).createShader(rect);
      canvas.drawRRect(rr, fill);

      if (tile.blocked) {
        final tp = TextPainter(text: const TextSpan(text: '🔒', style: TextStyle(fontSize: 16)), textDirection: TextDirection.ltr)..layout();
        tp.paint(canvas, Offset(x - tp.width / 2, y - tp.height / 2));
      } else if (tile.frozen) {
        final tp = TextPainter(text: const TextSpan(text: '❄', style: TextStyle(fontSize: 16, color: Colors.white)), textDirection: TextDirection.ltr)..layout();
        tp.paint(canvas, Offset(x - tp.width / 2, y - tp.height / 2));
      } else {
        final tp = TextPainter(
          text: TextSpan(text: shortNum(tile.value), style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900, shadows: [Shadow(color: Colors.black54, blurRadius: 3)])),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(x - tp.width / 2, y - tp.height / 2));
      }
    }
  }

  @override
  bool shouldRepaint(covariant FallingPainter old) => old.t != t || old.tiles != tiles;
}
