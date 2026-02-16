// DartPad Tek Dosya - Merge Blocks Neon Chain FINAL
// Özellikler:
// - Campaign (1-100) + Endless (101+) mod
// - Dengeli hedef eğrisi (segmentli + log destekli), BigInt güvenli
// - Her 10 bölümde Episode farklılığı (mekanik varyasyonları)
// - Test Mode + Quick Skip
// - Swap-only ekonomi (bomba yok)
// - AdMob Rewarded entegrasyon noktası (mock servis)
// - Leaderboard altyapısı (local + online mock)
// - 5x8 grid, TR/EN, koyu premium arayüz

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';



// --------------------
// DartPad uyumlu basit kalıcı hafıza (SharedPreferences yerine).
// Flutter uygulamada gerçek SharedPreferences kullanmak istersen,
// bu sınıfı kaldırıp tekrar shared_preferences paketini ekleyebilirsin.
// --------------------

class AppPrefs {
  static SharedPreferences? _p;
  AppPrefs._();

  static Future<SharedPreferences> getInstance() async {
    _p ??= await SharedPreferences.getInstance();
    return _p!;
  }
}
class BlockerCrackPainter extends CustomPainter {
  final int hp;
  BlockerCrackPainter(this.hp);

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = hp == 2 ? 1.8 : 2.2
      ..color = Colors.black.withOpacity(hp == 2 ? 0.28 : 0.40)
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
        ..color = Colors.black.withOpacity(0.50)
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
      title: 'Merge Blocks Neon Puzzle',
      theme: ThemeData.dark(useMaterial3: true),
      home: const UltraGamePage(),
    );
  }
}

enum AppLang { en, de }
enum NumFmt { en, de }
enum FxMode { low, high }
enum GoalType { reachValue, clearBlockers, comboCount }
enum GameMode { campaign, endless }

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

class _UltraGamePageState extends State<UltraGamePage> with TickerProviderStateMixin, WidgetsBindingObserver {
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
    final base = _valuePalette[idx];
    // Biraz daha mat/sakin: neon yormasın
    return Color.lerp(base, const Color(0xFF0B0A16), 0.22)!;
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
  static const _kLb = 'u2248_v14.8_lb_local';

static const _kGridV = 'u2248_v14.8_grid_v';
static const _kGridB = 'u2248_v14.8_grid_b';
static const _kGridF = 'u2248_v14.8_grid_f';
static const _kScore = 'u2248_v14.8_score';
static const _kMoves = 'u2248_v14.8_moves';
static const _kBlockersRem = 'u2248_v14.8_blockers_rem';
static const _kLastMaxAd = 'u2248_v14.8_last_max_ad';
static const _kPendingDup = 'u2248_v14.8_pending_dup';
static const _kDiamonds = 'u2248_v15.0_diamonds';
static const _kLastMilestone = 'u2248_v15.0_last_milestone';

  final rnd = Random();
  final RewardedAdService adService = MockRewardedAdService();
  final OnlineLeaderboardService onlineLb = MockOnlineLeaderboardService();

  List<List<Cell>> grid = List.generate(8, (_) => List.generate(5, (_) => Cell(0)));
  Size _lastBoardSize = Size.zero; // cached for particle positioning

  late final List<LevelConfig> campaignLevels;

  int levelIdx = 0; // campaign index 0..99, endless logical >99
  int unlockedCampaign = 1;
  int moves = 0;

  int _lastOfferMove = -1;
  int score = 0;
  int best = 0;
  int swaps = 0;
  int diamonds = 0;
  int _lastMilestone = 0;

int _lastMaxAdTriggered = 0;
int? _pendingDuplicateValue;
  int blockersRemaining = 0;
  int bestComboThisLevel = 0;

  AppLang lang = AppLang.en;
  NumFmt numFmt = NumFmt.en;
  FxMode fxMode = FxMode.high;
  GameMode mode = GameMode.campaign;
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
  bool showEpisodeIntro = false;
  String episodeIntroTitle = '';
  String episodeIntroRule = '';
  static const _kBlockerTipSeen = 'u2248_v14.8_blocker_tip_seen';

  late final AnimationController glowCtrl;
  late final Animation<double> glowAnim;
late AnimationController hudPulseCtrl;
late Animation<double> hudPulseAnim;
late AnimationController electricCtrl;

late final AnimationController energyCtrl;
  late final Animation<double> energyAnim;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    glowCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 860))..repeat(reverse: true);
    glowAnim = Tween<double>(begin: 0.24, end: 0.92).animate(CurvedAnimation(parent: glowCtrl, curve: Curves.easeInOut));
    energyCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();

// Mini HUD pulse + electric animations
hudPulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 420));
hudPulseAnim = CurvedAnimation(parent: hudPulseCtrl, curve: Curves.easeOutCubic);
electricCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat();
    energyAnim = CurvedAnimation(parent: energyCtrl, curve: Curves.linear);

    campaignLevels = List.generate(100, (i) => _generateCampaignLevel(i + 1));
    adService.initialize();
    mode = GameMode.endless;
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    
    _loadProgress();
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    glowCtrl.dispose();
    energyCtrl.dispose();
    hudPulseCtrl.dispose();
    electricCtrl.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }


@override
void didChangeAppLifecycleState(AppLifecycleState state) {
  if (state == AppLifecycleState.paused ||
      state == AppLifecycleState.inactive ||
      state == AppLifecycleState.detached) {
    _saveProgress();
  }
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
    String ep = 'Endless Classic';
    int blockers = 0;
    bool frozen = false;
    bool gate = false;
    int? gateMin;
    GoalType goal = GoalType.reachValue;
    int goalAmount = 0;

    switch (epCycle) {
      case 0:
        ep = 'Endless Classic';
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
    if (mode == GameMode.campaign) {
      return campaignLevels[levelIdx.clamp(0, 99)];
    }
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


  int _maxTile() {
    int m = 0;
    for (final row in grid) {
      for (final c in row) {
        if (c.value > m) m = c.value;
      }
    }
    return m;
  }

  void _showToast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg), duration: const Duration(milliseconds: 900)));
  }


  int _currentMaxValueOnBoard() {
    int m = 0;
    for (final row in grid) {
      for (final c in row) {
        if (c.value > m) m = c.value;
      }
    }
    return m;
  }

  List<int> _spawnPoolForLevel(int logicalLevel) {
  // Spawn kuralı:
  // - 2048'e kadar: 2-4-8-16-32-64
  // - 2048 ve sonrası: ekrandaki MAX değere göre spawn tabanı yükselir.
  //   Örn max=2048 => 4..128, max=4096 => 8..256, max=8192 => 16..512 (6 kademelik pencere)
  final maxSeen = _currentMaxValueOnBoard();
  if (maxSeen < 2048) {
    return const <int>[2, 4, 8, 16, 32, 64];
  }
  final maxExp = (log(maxSeen) / ln2).floor(); // 2048=2^11
  final baseExp = max(2, maxExp - 9); // 11->2 (4), 12->3 (8) ...
  return List<int>.generate(6, (i) => 1 << (baseExp + i));
}

  // ---------- Persistence ----------
  Future<void> _loadProgress() async {
  final p = await AppPrefs.getInstance();

  levelIdx = (p.getInt(_kLevel) ?? 100).clamp(0, 999999);
  unlockedCampaign = (p.getInt(_kUnlocked) ?? 1).clamp(1, 100);
  best = p.getInt(_kBest) ?? 0;
  swaps = p.getInt(_kSwaps) ?? 0;
  diamonds = p.getInt(_kDiamonds) ?? 0;
  _lastMilestone = p.getInt(_kLastMilestone) ?? 0;

  lang = (p.getString(_kLang) ?? 'tr') == 'en' ? AppLang.en : AppLang.de;
  numFmt = (p.getString(_kNumFmt) ?? 'tr') == 'en' ? NumFmt.en : NumFmt.de;
  sfxOn = p.getBool(_kSfx) ?? true;
  fxMode = (p.getString(_kFx) ?? 'high') == 'low' ? FxMode.low : FxMode.high;
  testMode = p.getBool(_kTest) ?? false;

  mode = GameMode.endless;
  if (levelIdx < 100) levelIdx = 100;

  final v = p.getStringList(_kGridV) ?? const <String>[];
  final b = p.getStringList(_kGridB) ?? const <String>[];
  final f = p.getStringList(_kGridF) ?? const <String>[];
  final hasSnap = v.length == rows * cols && b.length == rows * cols && f.length == rows * cols;

  if (!hasSnap) {
    _startLevel(levelIdx, hardReset: false);
    _rebuildValueColorMapFromGrid();
    if (mounted) setState(() {});
    return;
  }

  score = p.getInt(_kScore) ?? 0;
  moves = p.getInt(_kMoves) ?? 0;
  blockersRemaining = p.getInt(_kBlockersRem) ?? 0;
  _lastMaxAdTriggered = p.getInt(_kLastMaxAd) ?? 0;
  final pd = p.getInt(_kPendingDup) ?? 0;
  _pendingDuplicateValue = (pd > 0) ? pd : null;

  int k = 0;
  for (int r = 0; r < rows; r++) {
    for (int c = 0; c < cols; c++) {
      final cell = grid[r][c];
      cell.value = int.tryParse(v[k]) ?? 0;
      cell.blocked = b[k] == '1';
      cell.frozen = f[k] == '1';
      if (cell.blocked && cell.blockerHp <= 0) cell.blockerHp = 3;
      k++;
    }
  }

  _rebuildValueColorMapFromGrid();
  if (mounted) setState(() {});
}

bool _isPowerOfTwoInt(int v) => v > 0 && (v & (v - 1)) == 0;

int _milestoneDiamonds(int maxV) {
  // 2048 => 1, 4096 => 2, 8192 => 4, ...
  if (maxV < 2048) return 0;
  return maxV ~/ 2048;
}

void _grantDuplicateReward(int value) {
  // Place a duplicate tile of `value` into a random empty non-blocked cell.
  final empties = <Pos>[];
  for (int r = 0; r < rows; r++) {
    for (int c = 0; c < cols; c++) {
      final cell = grid[r][c];
      if (cell.blocked || cell.frozen) continue;
      if (cell.value == 0) empties.add(Pos(r, c));
    }
  }
  if (empties.isEmpty) return;
  final p = empties[rnd.nextInt(empties.length)];
  setState(() => grid[p.r][p.c].value = value);
  _rebuildValueColorMapFromGrid();
  _saveProgress();
}

Future<void> _maybeMilestoneRewardAndOffer() async {
  final maxNow = _maxTile();
  if (maxNow < 2048) return;
  if (!_isPowerOfTwoInt(maxNow)) return;

  if (maxNow <= _lastMilestone) return;
  _lastMilestone = maxNow;

  final d = _milestoneDiamonds(maxNow);
  if (d > 0) {
    diamonds += d;
    _showToast('+$d 💎');
    _saveProgress();
  }

  if (!mounted) return;

  final ok = await showDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (_) {
      final title = t('milestoneTitle').replaceAll('{m}', shortNumInt(maxNow));
      final body = t('milestoneBody').replaceAll('{m}', shortNumInt(maxNow));
      return AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.auto_awesome, color: Color(0xFFFFD24A)),
            const SizedBox(width: 10),
            Expanded(child: Text(title)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF0B0A16),
                    const Color(0xFFFFC94A),
                  ],
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.copy, color: Color(0xFF39FF14)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      body,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              t('milestoneHint'),
              style: TextStyle(color: Colors.white.withOpacity(0.65), fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(t('offerNoThanks')),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.play_circle_fill),
            label: Text(t('offerWatch')),
          ),
        ],
      );
    },
  );

  if (ok != true) return;

  final ready = await adService.isAdReady();
  if (!ready) await adService.loadAd();
  await adService.showAd(onReward: () {
    _grantDuplicateReward(maxNow);
    _showToast(t('duplicateGranted'));
  });
}



Future<void> _maybeOfferAdBoost() async {
  // Offer every 40 moves: watch an ad to double the current max tile.
  if (moves <= 0 || moves % 40 != 0) return;
  if (!mounted || isBusy) return;

  // Find current max tile (int).
  int maxV = 0;
  int mr = -1, mc = -1;
  for (int r = 0; r < rows; r++) {
    for (int c = 0; c < cols; c++) {
      final v = grid[r][c].value;
      if (v > maxV) {
        maxV = v;
        mr = r;
        mc = c;
      }
    }
  }
  if (maxV <= 0 || mr < 0) return;

  // Don't offer once player has already reached 2048+ (per requirement).
  if (maxV >= 2048) return;

  // Avoid spamming if max hasn't changed since the last offer.
  if (_hudMaxPrev == maxV) return;
  _hudMaxPrev = maxV;

  final ok = await showDialog<bool>(
        context: context,
        barrierDismissible: true,
        builder: (ctx) => AlertDialog(
          title: Text(t('adBoostTitle')),
          content: Text(t('adBoostBody').replaceAll('{x}', shortNumBig(BigInt.from(maxV)))),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(t('noThanks'))),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: Text(t('watchAd'))),
          ],
        ),
      ) ??
      false;

  if (!ok) return;

  // Try rewarded ad; if not ready, just return silently.
  final ready = await adService.isAdReady();
  if (!ready) await adService.loadAd();

  await adService.showAd(onReward: () {
    if (!mounted) return;
    setState(() {
      grid[mr][mc].value = grid[mr][mc].value * 2;
    });
    _rebuildValueColorMapFromGrid();
    _showToast(t('adBoostGranted'));
    _saveProgress();
  });
}



void _applyPendingDuplicateIfAny() {
  final v = _pendingDuplicateValue;
  if (v == null) return;

  final empties = <Pos>[];
  for (int r = 0; r < rows; r++) {
    for (int c = 0; c < cols; c++) {
      final cell = grid[r][c];
      if (!cell.blocked && !cell.frozen && cell.value == 0) {
        empties.add(Pos(r, c));
      }
    }
  }

  if (empties.isEmpty) return;
  final pick = empties[rnd.nextInt(empties.length)];
  grid[pick.r][pick.c].value = v;
  _pendingDuplicateValue = null;
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

      if (mode == GameMode.campaign) {
        if (levelIdx + 2 > unlockedCampaign) {
          unlockedCampaign = (levelIdx + 2).clamp(1, 100).toInt();
        }
      }

      await _saveProgress();
      if (!mounted) return;

      // Level Complete kısa animasyon (700ms) + auto-next öncesi küçük gecikme efekti
      await Future.delayed(const Duration(milliseconds: 700));
      if (!mounted) return;

      if (autoNextOn) {
        await Future.delayed(const Duration(milliseconds: 280)); // tiny continue-delay
        if (!mounted) return;

        if (mode == GameMode.campaign) {
          if (levelIdx < 99) {
            _startLevel(levelIdx + 1);
          } else {
            // Kampagne bitti -> endless
            mode = GameMode.endless;
            _startLevel(100);
          }
        } else {
          _startLevel(levelIdx + 1);
        }

        _rebuildValueColorMapFromGrid();
        await _saveProgress();
        if (mounted) setState(() {});
      }
      return;
    }
  }

  // ---------- UI Text ----------
  String t(String key) {
    const en = {
      'title':'MERGE BLOCKS NEON CHAIN','level':'Level','score':'Score','best':'Best','max':'Max','target':'Target','move':'Move','mode':'Mode','campaign':'Campaign','endless':'Endless','episode':'Episode','goal':'Special Goal','unlocked':'Unlocked','language':'Language','numfmt':'Number','tr':'TR','en':'EN','de':'DE','sfx':'Sound FX','fx':'Performance','low':'Low FX','high':'High FX','test':'Test Mode','offerTitle':'Bonus offer','offerBody':'Watch an ad to double your MAX tile: {from} → {to}.','offerHint':'Reward is applied instantly after the ad.','offerWatch':'Watch ad','offerNoThanks':'No thanks'
    ,'milestoneTitle':'Milestone {m}!','milestoneBody':'Watch an ad to duplicate your {m} tile.','milestoneHint':'A copy will be placed on an empty cell (if available).','duplicateGranted':'Duplicate granted!'};
    const de = {
      'title':'MERGE BLOCKS NEON CHAIN','level':'Level','score':'Punkte','best':'Bestwert','max':'Max','target':'Ziel','move':'Zug','mode':'Modus','campaign':'Kampagne','endless':'Endlos','episode':'Episode','goal':'Spezialziel','unlocked':'Freigeschaltet','language':'Sprache','numfmt':'Zahl','tr':'TR','en':'EN','de':'DE','sfx':'Soundeffekte','fx':'Leistung','low':'Niedrige FX','high':'Hohe FX','test':'Testmodus','offerTitle':'Bonus-Angebot','offerBody':'Sieh dir eine Werbung an und verdopple deinen MAX‑Block: {from} → {to}.','offerHint':'Die Belohnung wird direkt nach der Werbung angewendet.','offerWatch':'Werbung ansehen','offerNoThanks':'Nein, danke'
    ,'milestoneTitle':'Meilenstein {m}!','milestoneBody':'Sieh dir eine Werbung an und dupliziere deinen {m}-Block.','milestoneHint':'Eine Kopie wird in ein freies Feld gesetzt (falls möglich).','duplicateGranted':'Duplikat erhalten!'};
    return (lang == AppLang.de ? de : en)[key] ?? key;
  }


  String _episodeRuleText(LevelConfig cfg) {
    if (lang == AppLang.de) {
      if (cfg.goalType == GoalType.clearBlockers) return 'Blocker zählen nicht zur Kette. Entferne zuerst die Blocker.';
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

    Future<void> _maybeShowEpisodeIntro() async {
    // Her bölüm başlangıcında göster (test mode dahil) - PREMIUM / 2x süre
    final lvl = lv.index;
    final targetTxt = shortNumBig(lv.targetBig);

    showEpisodeIntro = true;

    // Faz 1: Level
    episodeIntroTitle = (lang == AppLang.de) ? 'BÖLÜM $lvl' : 'LEVEL $lvl';
    episodeIntroRule = (lang == AppLang.de) ? 'Hazır mısın?' : 'Are you ready?';
    if (mounted) setState(() {});
    await Future.delayed(const Duration(milliseconds: 2000)); // ~2x

    if (!mounted || !showEpisodeIntro) return;

    // Faz 2: Ziel
    episodeIntroTitle = (lang == AppLang.de) ? 'HEDEF' : 'TARGET';
    episodeIntroRule = targetTxt;
    if (mounted) setState(() {});
    await Future.delayed(const Duration(milliseconds: 2600)); // ~2x

    if (!mounted || !showEpisodeIntro) return;

    // Faz 3: Episode + kural
    episodeIntroTitle = 'EPISODE: ${lv.episodeName.toUpperCase()}';
    episodeIntroRule = _episodeRuleText(lv);
    if (mounted) setState(() {});
    await Future.delayed(const Duration(milliseconds: 2600)); // ~2x

    if (!mounted) return;
    showEpisodeIntro = false;
    if (mounted) setState(() {});
  }

  Future<void> _maybeShowBlockerTooltip() async {
    if (lv.goalType != GoalType.clearBlockers && lv.blockerCount <= 0) return;
    final p = await AppPrefs.getInstance();
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
          Shadow(color: c.withOpacity(0.95), blurRadius: 10),
          Shadow(color: c.withOpacity(0.45), blurRadius: 22),
        ],
      );

  // The '_chip' widget was not referenced anywhere. Removing it.
  /*
  Widget _chip(String txt, {Color color = const Color(0xFF39FF14)}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF21193C),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.60)),
          boxShadow: [BoxShadow(color: color.withOpacity(0.22), blurRadius: 10)],
        ),
        child: Text(
          txt,
          style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 12.5),
        ),
      );
  */


  bool _isFallTarget(int r, int c) {
    for (final t in fallingTiles) {
      if (t.toR == r && t.c == c) return true;
    }
    return false;
  }

  @override
Widget build(BuildContext context) {
  final mq = MediaQuery.of(context);
  final size = mq.size;

  // Daha okunaklı: küçük ekranlarda bile büyük HUD (A52 dahil).
  final ui = (size.shortestSide / 360.0).clamp(1.40, 2.20);

  Widget hudBtn({
    required IconData icon,
    required String title,
    required String sub,
    required Color accent,
    VoidCallback? onTap,
  }) {
    final enabled = onTap != null;
    return Opacity(
      opacity: enabled ? 1.0 : 0.50,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18 * ui),
          onTap: onTap,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 14 * ui, vertical: 10 * ui),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF2A214B), Color(0xFF17132C)]),
              borderRadius: BorderRadius.circular(18 * ui),
              border: Border.all(color: accent.withOpacity(0.70), width: 1.3),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.40), blurRadius: 18, offset: const Offset(0, 10))],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 22 * ui, color: accent),
                SizedBox(width: 8 * ui),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14 * ui)),
                    SizedBox(height: 2 * ui),
                    Text(sub, style: TextStyle(color: Colors.white.withOpacity(0.90), fontWeight: FontWeight.w800, fontSize: 12 * ui)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }


  return Scaffold(
    backgroundColor: const Color(0xFF0B0A16),

    // Üst panel: sadece Punkte / En Büyük / Ziel + Swap + Werbung butonları
    



appBar: PreferredSize(
  preferredSize: Size.fromHeight((78 * ui) * 1.75),
  child: SafeArea(
    bottom: false,
    child: Container(
      decoration: const BoxDecoration(
        color: Color(0xFF17132C),
        boxShadow: [BoxShadow(color: Color(0x66000000), blurRadius: 18, offset: Offset(0, 10))],
      ),
      padding: EdgeInsets.fromLTRB(10 * ui, 12 * ui, 16 * ui, 12 * ui),
      child: LayoutBuilder(
        builder: (context, c) {
  final w = c.maxWidth;
  final ultra = w < 360 * ui;
  final compact = w < 420 * ui;

  final gap = (ultra ? 6 : 10) * ui;

  // Right side fixed buttons
  final iconW = (ultra ? 40 : 46) * ui;
  final rightW = iconW * 2 + gap;

  // Left side 3 slots: Ad / Swap / Next
  final avail = (w - rightW - gap).clamp(0.0, double.infinity);
  final slotW = (avail / 3).clamp(90 * ui, 160 * ui);
  final slotH = (ultra ? 54 : (compact ? 58 : 62)) * ui;

  Widget slot(Widget child) => SizedBox(
        width: slotW,
        height: slotH,
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: child,
          ),
        ),
      );

  final swapBtn = slot(
    hudBtn(
      icon: swapMode ? Icons.close : Icons.swap_horiz,
      title: 'SWAP',
      sub: ultra ? '$swaps' : (lang == AppLang.de ? 'Übrig: $swaps' : 'Left: $swaps'),
      accent: const Color(0xFF39FF14),
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
  );

  
final diamondsChip = slot(
  hudBtn(
    icon: Icons.diamond,
    title: '💎',
    sub: diamonds.toString(),
    accent: const Color(0xFF39FF14),
    onTap: null,
  ),
);

final adBtn = slot(
    hudBtn(
      icon: Icons.play_circle_fill,
      title: ultra ? '+1' : '+1 SWAP',
      sub: ultra ? (lang == AppLang.de ? 'Ad' : 'Ad') : (lang == AppLang.de ? 'Werbung' : 'Ad'),
      accent: const Color(0xFFFFD24A),
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
  );

  final restartBtn = SizedBox(
    width: iconW,
    child: IconButton(
      tooltip: lang == AppLang.de ? 'Neustart' : 'Restart',
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
      onPressed: () {
        _startLevel(levelIdx, hardReset: true);
        _rebuildValueColorMapFromGrid();
      },
      icon: const Icon(Icons.restart_alt),
      iconSize: (ultra ? 22 : 24) * ui,
    ),
  );

  final settingsBtn = SizedBox(
    width: iconW,
    child: PopupMenuButton<String>(
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
      icon: const Icon(Icons.settings),
      iconSize: (ultra ? 22 : 24) * ui,
      onSelected: (v) async {
        setState(() {
          if (v == 'lang_de') lang = AppLang.de;
          if (v == 'lang_en') lang = AppLang.en;
          if (v == 'sfx') sfxOn = !sfxOn;
          if (v == 'fx_low') fxMode = FxMode.low;
          if (v == 'fx_high') fxMode = FxMode.high;
        });
        await _saveProgress();
      },
      itemBuilder: (_) => [
        PopupMenuItem(value: 'lang_de', child: Text('${t('language')}: DE')),
        PopupMenuItem(value: 'lang_en', child: Text('${t('language')}: EN')),
        const PopupMenuDivider(),
        PopupMenuItem(value: 'sfx', child: Text('${t('sfx')}: ${sfxOn ? "ON" : "OFF"}')),
        PopupMenuItem(value: 'fx_high', child: Text('${t('fx')}: ${t('high')}')),
        PopupMenuItem(value: 'fx_low', child: Text('${t('fx')}: ${t('low')}')),
      ],
    ),
  );

  return Row(
    children: [
      Expanded(
        child: Row(
          children: [
            diamondsChip,
            SizedBox(width: gap),
            adBtn,
            SizedBox(width: gap),
            swapBtn,
            SizedBox(width: gap),
          ],
        ),
      ),
      SizedBox(width: gap),
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          restartBtn,
          SizedBox(width: gap),
          settingsBtn,
        ],
      ),
    ],
  );
},
      ),
    ),
  ),
),


body: SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(10 * ui, 10 * ui, 10 * ui, 12 * ui),
        child: Column(
          children: [
            // Mini HUD removed (MIN/MAX removed, NEXT moved to app bar)
            SizedBox(height: 0),

            // Board: maksimum alan (sağ/sol panel ve banner yok)
            Expanded(
              child: LayoutBuilder(
                builder: (context, c) {
                  final usableW = c.maxWidth;
                  final usableH = c.maxHeight;

                  final ratioWH = cols / rows;
                  double boardW = min(usableW, usableH * ratioWH);
                  double boardH = boardW / ratioWH;

                  return Center(
                    child: SizedBox(
                      width: boardW,
                      height: boardH,
                      child: _buildBoard(Size(boardW, boardH)),
                    ),
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

  Widget _buildBoard(Size boardSize) {
    
    _lastBoardSize = boardSize;
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
        // Offer opt-in rewarded boost every 40 moves
        await _maybeOfferAdBoost();
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

// Diamonds for combos:
// 8-10 => +1 💎, 11+ => +2 💎 (no diamonds for 2-7)
final comboLen = path.length;
int dAdd = 0;
if (comboLen >= 11) {
  dAdd = 2;
} else if (comboLen >= 8) {
  dAdd = 1;
}
if (dAdd > 0) {
  diamonds += dAdd;
  _showToast('+$dAdd 💎');
}

// Milestone diamonds + optional rewarded duplicate offer (2048+)
await _maybeMilestoneRewardAndOffer();
        if (score > best) best = score;

        await _sfxMerge(path.length);
        _spawnComboParticles(_cellCenter(target, _lastBoardSize), path.length);
        await _applyGravityAndRefill();
        _applyPendingDuplicateIfAny();
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
                      lang == AppLang.de
                          ? '🔒 Bu hücreler zincire dahil olmaz. Yanında birleşme yaparak kır (HP:3)'
                          : '🔒 These cells cannot be chained. Make merges next to them to break (HP:3)', // Added EN translation for blocker HP
                      textAlign: TextAlign.center,
                      style: _neon(const Color(0xFFFFD740), 16),
                    ),
                  ),
                ),
              ),
            if (showEpisodeIntro)
              Positioned.fill(
                child: GestureDetector(
                  onTap: () {
                    showEpisodeIntro = false;
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
                          Colors.black.withOpacity(0.88),
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
                                lang == AppLang.de ? 'Tippen zum Überspringen' : 'Tap to skip',
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

children.add(
  Positioned(
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
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [hi, base, lo],
          ),
          border: Border.all(
            color: sw ? Colors.cyanAccent : (sel ? Colors.white : Colors.black26),
            width: sw ? 3 : (sel ? 2 : 1),
          ),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.35), blurRadius: 7, offset: const Offset(0, 3)),
            if (sel) BoxShadow(color: Colors.white.withOpacity(glowAnim.value), blurRadius: 8),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              left: 5,
              right: 5,
              top: 4,
              child: Container(
                height: 8,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.22),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            Center(
              child: cell.blocked
                  ? Transform.scale(
                      scale: 1.0 + (0.08 * sin(glowAnim.value * pi * 2)),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.lock, color: Colors.white.withOpacity(0.95), size: 16),
                          Text(
                            'HP ${cell.blockerHp}',
                            style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900),
                          ),
                        ],
                      ),
                    )
                  : cell.frozen
                      ? const Icon(Icons.ac_unit, color: Colors.white, size: 17)
                      : Text(
                          shortNumInt(cell.value),
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            fontSize: cell.value >= 1000000 ? 11.8 : (cell.value >= 10000 ? 14 : 17),
                            shadows: const [Shadow(color: Colors.black54, blurRadius: 3)],
                          ),
                        ),
            ),
          ],
        ),
      ),
    ),
  ),
);
}
    }

    return Stack(children: children);
  }


  // -------------------- Missing helpers (added for stability) --------------------

  /// Rebuilds any cached color/value maps. In this single-file version we keep it minimal.
  void _rebuildValueColorMapFromGrid() {
    // no-op (kept for backward compatibility with earlier revisions)
  }

  Future<void> _saveProgress() async {
    final p = await AppPrefs.getInstance();
    await p.setInt('best', best);
    await p.setInt('score', score);
    await p.setInt('moves', moves);
    await p.setInt('swaps', swaps);
    await p.setInt('diamonds', diamonds);
    await p.setInt('unlockedCampaign', unlockedCampaign);
    await p.setInt('levelIdx', levelIdx);
    await p.setString('mode', mode.name);
    await p.setString('lang', lang.name);
    await p.setBool('sfxOn', sfxOn);
    await p.setString('fxMode', fxMode.name);

    // Save grid as CSV of ints (rows*cols)
    final flat = <int>[];
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        flat.add(grid[r][c].value);
      }
    }
    await p.setString('grid', flat.join(','));
  }

  void _startLevel(int idx, {bool hardReset = false}) {
    // Defensive clamp
    levelIdx = idx.clamp(1, 100);

    // Decide mode based on idx
    if (levelIdx >= 1 && levelIdx <= campaignLevels.length) {
      mode = GameMode.campaign;
    } else {
      mode = GameMode.endless;
    }

    // Reset run stats if requested
    if (hardReset) {
      score = 0;
      moves = 0;
      swaps = 0;
      diamonds = 0;
    }

    // Ensure grid exists
    final seed = _spawnPoolForLevel((levelIdx - 1).clamp(0, campaignLevels.length - 1));
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        final v = seed[rnd.nextInt(seed.length)];
        grid[r][c] = Cell(v);
      }
    }

    // Reset selection state
    selected.clear();
    path.clear();
    swapMode = false;
    swapFirst = null;
    isBusy = false;

    // Level-specific counters
    blockersRemaining = lv.blockerCount;
  }

  bool _isLevelGoalCompleted() {
    switch (lv.goalType) {
      case GoalType.reachValue:
        return _maxTileBig() >= lv.targetBig;
      case GoalType.clearBlockers:
        return blockersRemaining <= 0;
      case GoalType.comboCount:
        return bestComboThisLevel >= lv.goalAmount;
    }
}


  int _swapReward(int movesCount) {
    // Simple pacing: 1 swap every 25 moves in campaign.
    return max(1, (movesCount / 25).floor());
  }

  Future<void> _submitLb() async {
    // Leaderboard submit is intentionally a no-op in this single-file build.
  }

  Future<void> _sfxLight() async {
    // no-op (SFX disabled in this build)
  }

  Future<void> _sfxMerge(int combo) async {
    // no-op (SFX disabled in this build)
  }

  bool _isOrthogonalOneStep(Pos a, Pos b) {
    final dr = (a.r - b.r).abs();
    final dc = (a.c - b.c).abs();
    return (dr + dc) == 1;
  }

  bool _canLink(Pos a, Pos b) {
    if (!_isOrthogonalOneStep(a, b)) return false;
    final va = grid[a.r][a.c].value;
    final vb = grid[b.r][b.c].value;
    // Basic rule: chain only equal values (common merge rule).
    return va == vb && va > 0;
  }

  int _mergedValue(List<Pos> chain) {
    if (chain.isEmpty) return 0;
    final base = grid[chain.first.r][chain.first.c].value;
    // Merge result doubles with each extra tile in the chain.
    int v = base;
    for (int i = 1; i < chain.length; i++) {
      v = v * 2;
    }
    return v;
  }

  String _praise(int combo) {
    if (combo >= 12) return t('comboLegendary');
    if (combo >= 9) return t('comboEpic');
    if (combo >= 6) return t('comboGreat');
    if (combo >= 4) return t('comboNice');
    return t('comboGood');
  }

  int? _hudMaxPrev;

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
        ..shader = LinearGradient(colors: [dark.withOpacity(0.9), dark]).createShader(Rect.fromPoints(Offset(x1, y1), Offset(x2, y2)));

      if (!lowFx) {
        final glowPaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 16
          ..strokeCap = StrokeCap.round
          ..shader = LinearGradient(colors: [dark.withOpacity(0.55), dark.withOpacity(0.95)]).createShader(Rect.fromPoints(Offset(x1, y1), Offset(x2, y2)))
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
        canvas.drawLine(Offset(x1, y1), Offset(x2, y2), glowPaint);
      }

      canvas.drawLine(Offset(x1, y1), Offset(x2, y2), mainPaint);

      if (!lowFx) {
        final local = (energyPhase + i * 0.17) % 1.0;
        final ex = x1 + (x2 - x1) * local;
        final ey = y1 + (y2 - y1) * local;
        final eColor = Color.lerp(Colors.white, const Color(0xFF00E5FF), t)!.withOpacity(0.95);
        final ePaint = Paint()..color = eColor..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
        canvas.drawCircle(Offset(ex, ey), 6.0, ePaint);
        canvas.drawCircle(Offset(ex, ey), 2.6, Paint()..color = Colors.white.withOpacity(0.95));
      }

      final shine = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = lowFx ? 2 : 4
        ..strokeCap = StrokeCap.round
        ..color = Colors.white.withOpacity((0.42 - 0.18 * t + glow * 0.15).clamp(0.12, 0.58));
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
      canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(12)), Paint()..color = Colors.white.withOpacity(0.65 * alpha));
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
      canvas.drawCircle(pos, 1.7 + (1 - t) * 2.0, Paint()..color = p.color.withOpacity((1 - t).clamp(0.0, 1.0)));
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
