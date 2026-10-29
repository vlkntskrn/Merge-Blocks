import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'billing.dart';

/// AdMob reklam birimi kimlikleri.
///
/// Android: gerçek AdMob birimleri (uygulama ca-app-pub-5300613532774934~9633273706).
/// iOS: henüz AdMob'da iOS uygulaması yok, Google test kimlikleri kullanılıyor.
/// Geliştirirken kendi reklamınıza tıklamayın; test için cihazı AdMob'da test cihazı olarak ekleyin.
class AdIds {
  static String get rewarded => Platform.isIOS
      ? 'ca-app-pub-3940256099942544/1712485313'
      : 'ca-app-pub-5300613532774934/8287092931'; // rewarded_main

  static String get banner => Platform.isIOS
      ? 'ca-app-pub-3940256099942544/2934735716'
      : 'ca-app-pub-5300613532774934/5417387015'; // banner_bottom
}

/// GDPR/UMP onayı + AdMob başlatma + ödüllü reklam yönetimi.
class Ads {
  Ads._();
  static final Ads instance = Ads._();

  bool _ready = false;
  bool get ready => _ready;

  RewardedAd? _rewarded;
  bool _loadingRewarded = false;

  /// Uygulama açılışında bir kez çağrılır. Hata olursa oyun reklamsız devam eder.
  Future<void> init() async {
    if (kIsWeb || !(Platform.isAndroid || Platform.isIOS)) return;
    try {
      await _gatherConsent();
      if (!await ConsentInformation.instance.canRequestAds()) return;
      await MobileAds.instance.initialize();
      _ready = true;
      loadRewarded();
    } catch (e) {
      debugPrint('Ads init hatası: $e');
    }
  }

  Future<void> _gatherConsent() {
    final done = Completer<void>();
    ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(),
      () {
        ConsentForm.loadAndShowConsentFormIfRequired((FormError? err) {
          if (!done.isCompleted) done.complete();
        });
      },
      (FormError err) {
        if (!done.isCompleted) done.complete();
      },
    );
    return done.future.timeout(const Duration(seconds: 15), onTimeout: () {});
  }

  /// Ayarlarda "Gizlilik seçenekleri" gerekip gerekmediği.
  Future<bool> privacyOptionsRequired() async {
    try {
      return await ConsentInformation.instance.getPrivacyOptionsRequirementStatus() ==
          PrivacyOptionsRequirementStatus.required;
    } catch (_) {
      return false;
    }
  }

  void showPrivacyOptions() {
    ConsentForm.showPrivacyOptionsForm((_) {});
  }

  void loadRewarded() {
    if (!_ready || _rewarded != null || _loadingRewarded) return;
    _loadingRewarded = true;
    RewardedAd.load(
      adUnitId: AdIds.rewarded,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewarded = ad;
          _loadingRewarded = false;
        },
        onAdFailedToLoad: (err) {
          _loadingRewarded = false;
          // Kısa bir beklemeden sonra yeniden dene.
          Timer(const Duration(seconds: 30), loadRewarded);
        },
      ),
    );
  }

  /// Ödüllü reklamı gösterir. Ödül hak edilirse [onReward] çağrılır.
  /// Reklam hazır değilse false döner.
  bool showRewarded(VoidCallback onReward) {
    final ad = _rewarded;
    if (ad == null) {
      loadRewarded();
      return false;
    }
    _rewarded = null;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        loadRewarded();
      },
      onAdFailedToShowFullScreenContent: (ad, err) {
        ad.dispose();
        loadRewarded();
      },
    );
    ad.show(onUserEarnedReward: (_, __) => onReward());
    return true;
  }
}

/// Alt kısımdaki sabit yükseklikli banner. Reklam yüklenmezse boş alan kalır
/// (tahta kaymasın diye yükseklik sabit).
class BannerSlot extends StatefulWidget {
  final double height;
  const BannerSlot({super.key, required this.height});

  @override
  State<BannerSlot> createState() => _BannerSlotState();
}

class _BannerSlotState extends State<BannerSlot> {
  BannerAd? _ad;
  bool _loaded = false;
  Timer? _retry;

  @override
  void initState() {
    super.initState();
    _tryLoad();
  }

  void _tryLoad() {
    if (!mounted) return;
    if (!Ads.instance.ready) {
      // Onay/başlatma henüz bitmediyse biraz sonra tekrar dene.
      _retry = Timer(const Duration(seconds: 2), _tryLoad);
      return;
    }
    final ad = BannerAd(
      adUnitId: AdIds.banner,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, err) {
          ad.dispose();
          _ad = null;
          _retry = Timer(const Duration(seconds: 60), _tryLoad);
        },
      ),
    );
    _ad = ad;
    ad.load();
  }

  @override
  void dispose() {
    _retry?.cancel();
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: Billing.instance.noAds,
      builder: (context, noAds, _) => noAds ? const SizedBox.shrink() : _slot(),
    );
  }

  Widget _slot() {
    final ad = _ad;
    return SizedBox(
      height: widget.height,
      child: (ad != null && _loaded)
          ? Center(
              child: SizedBox(
                width: ad.size.width.toDouble(),
                height: ad.size.height.toDouble(),
                child: AdWidget(ad: ad),
              ),
            )
          : const SizedBox.shrink(),
    );
  }
}
