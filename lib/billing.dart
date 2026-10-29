import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Play Console'daki tek seferlik ürünler (kimlikler birebir aynı olmalı).
class Skus {
  static const List<String> diamondPacks = [
    'diamonds_150',
    'diamonds_250',
    'diamonds_500',
    'diamonds_750',
    'diamonds_1000',
  ];
  static const String noAds = 'no_ads';
  static Set<String> get all => {...diamondPacks, noAds};

  /// 'diamonds_750' -> 750
  static int diamondsFor(String id) => int.tryParse(id.split('_').last) ?? 0;
}

/// Google Play Billing sarmalayıcısı.
///
/// - Elmas paketleri tüketilebilir: satın alınınca elmas eklenir ve ürün tüketilir.
/// - "no_ads" kalıcı: satın alınınca banner kapanır; yeniden kurulumda geri yüklenir.
/// - Aynı satın alma iki kez gelirse (uygulama kapanıp açılınca vb.) ikinci kez ödül verilmez.
class Billing {
  Billing._();
  static final Billing instance = Billing._();

  static const _kNoAds = 'billing_no_ads';
  static const _kGranted = 'billing_granted_ids';

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _sub;

  bool available = false;
  final Map<String, ProductDetails> products = {};

  /// Reklamsız satın alındı mı.
  final ValueNotifier<bool> noAds = ValueNotifier<bool>(false);

  /// Elmas teslim edilecek yer (oyun durumu). init'ten önce atanır.
  void Function(int diamonds, String productId)? onDiamonds;

  /// Kullanıcıya kısa mesaj göstermek için (ör. "Satın alma iptal edildi").
  void Function(String message)? onMessage;

  final Set<String> _granted = {};

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    noAds.value = prefs.getBool(_kNoAds) ?? false;
    _granted.addAll(prefs.getStringList(_kGranted) ?? const []);

    try {
      available = await _iap.isAvailable();
    } catch (_) {
      available = false;
    }
    if (!available) return;

    _sub = _iap.purchaseStream.listen(_onPurchases, onError: (Object e) {
      debugPrint('Billing stream hatası: $e');
    });

    await refreshProducts();
    // Reklamsız gibi kalıcı ürünleri geri yükle (yeniden kurulum / yeni telefon).
    try {
      await _iap.restorePurchases();
    } catch (_) {}
  }

  Future<void> refreshProducts() async {
    if (!available) return;
    try {
      final resp = await _iap.queryProductDetails(Skus.all);
      products
        ..clear()
        ..addEntries(resp.productDetails.map((p) => MapEntry(p.id, p)));
      if (resp.notFoundIDs.isNotEmpty) {
        debugPrint('Play\'de bulunamayan ürünler: ${resp.notFoundIDs}');
      }
    } catch (e) {
      debugPrint('Ürün sorgu hatası: $e');
    }
  }

  /// Satın almayı başlatır. Sonuç purchaseStream üzerinden gelir.
  Future<bool> buy(String productId) async {
    final p = products[productId];
    if (!available || p == null) return false;
    final param = PurchaseParam(productDetails: p);
    try {
      if (productId == Skus.noAds) {
        return await _iap.buyNonConsumable(purchaseParam: param);
      }
      return await _iap.buyConsumable(purchaseParam: param, autoConsume: true);
    } catch (e) {
      debugPrint('Satın alma başlatılamadı: $e');
      return false;
    }
  }

  Future<void> _onPurchases(List<PurchaseDetails> list) async {
    for (final pd in list) {
      switch (pd.status) {
        case PurchaseStatus.pending:
          onMessage?.call('pending');
          break;
        case PurchaseStatus.canceled:
          onMessage?.call('canceled');
          break;
        case PurchaseStatus.error:
          onMessage?.call('error');
          break;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          await _deliver(pd);
          break;
      }
      if (pd.pendingCompletePurchase) {
        try {
          await _iap.completePurchase(pd);
        } catch (e) {
          debugPrint('completePurchase hatası: $e');
        }
      }
    }
  }

  Future<void> _deliver(PurchaseDetails pd) async {
    final prefs = await SharedPreferences.getInstance();
    if (pd.productID == Skus.noAds) {
      if (!noAds.value) {
        noAds.value = true;
        await prefs.setBool(_kNoAds, true);
        if (pd.status == PurchaseStatus.purchased) onMessage?.call('noAds');
      }
      return;
    }
    final amount = Skus.diamondsFor(pd.productID);
    if (amount <= 0) return;
    // Aynı siparişi iki kez teslim etme.
    final key = pd.purchaseID ?? pd.verificationData.serverVerificationData;
    if (key.isNotEmpty && _granted.contains(key)) return;
    if (key.isNotEmpty) {
      _granted.add(key);
      // Liste büyümesin: son 200 sipariş yeterli.
      final keep = _granted.toList();
      await prefs.setStringList(_kGranted, keep.length > 200 ? keep.sublist(keep.length - 200) : keep);
    }
    onDiamonds?.call(amount, pd.productID);
  }

  void dispose() {
    _sub?.cancel();
  }
}
