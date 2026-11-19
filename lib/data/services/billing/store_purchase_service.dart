import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../../../config/store_products.dart';

// ============================================================
// モデル・例外
// ============================================================

/// サブスクリプションを契約しているストア
enum SubscriptionStore {
  /// App Store
  appStore,

  /// Google Play
  playStore;

  /// この端末のストア
  static SubscriptionStore get current =>
      defaultTargetPlatform == TargetPlatform.android ? SubscriptionStore.playStore : SubscriptionStore.appStore;
}

/// 有効なサブスクリプション
/// [productId]は、Google Playでは`商品ID:基本プランID`の形になる
typedef ActiveSubscription = ({SubscriptionStore store, String productId});

/// 次回の更新で変わる予定のサブスクリプション
/// [startsAt]は変わる日時
typedef ScheduledSubscriptionChange = ({String productId, DateTime startsAt});

/// 購入の確認シートが閉じられた
class PurchaseCancelledException implements Exception {
  const PurchaseCancelledException();
}

/// 保護者の承認などを待っている。承認されると、次にSDKが動いたときに反映される
class PurchasePendingException implements Exception {
  const PurchasePendingException();
}

/// すでに契約中、または変更を予約済みの商品を購入しようとした
class PurchaseAlreadyOwnedException implements Exception {
  const PurchaseAlreadyOwnedException();
}

// ============================================================
// サービス
// ============================================================

/// App Store・Google Playの購入を扱うサービス（RevenueCatのSDK、機能仕様書4.6.4）
///
/// SDKはSET-07で初めて動かす。RevenueCatは同じストアアカウントの購入を、購入・復元した
/// App User IDへ移す設定のため、起動のたびに動かすと、端末を共用する別のuidの購入が動きかねない
class StorePurchaseService {

  // ---- 状態・初期化 ----

  /// Apple Accountの契約を尋ねるチャンネル（AppDelegate.swift）
  static const _renewalChannel = MethodChannel('com.example.orto/store_renewal');

  /// 購入できる設定になっているか
  bool get isAvailable => StoreProducts.apiKey.isNotEmpty;

  /// [billingId]でSDKを使える状態にする
  /// 匿名のApp User IDを作らないよう、最初からIDを渡す。別のuidに切り替わったら[Purchases.logIn]で切り替える
  Future<void> start(String billingId) async {
    if (!await Purchases.isConfigured) {
      await Purchases.configure(PurchasesConfiguration(StoreProducts.apiKey)..appUserID = billingId);
    } else if (await Purchases.appUserID != billingId) {
      await Purchases.logIn(billingId);
    }
  }

  // ---- 読み取り ----

  /// [productIds]の商品を取得する
  Future<List<StoreProduct>> fetchProducts(Set<String> productIds) => Purchases.getProducts(productIds.toList());

  /// 有効なサブスクリプションを取得する。無ければnull
  Future<ActiveSubscription?> fetchActiveSubscription() async {
    final customerInfo = await Purchases.getCustomerInfo();
    for (final entitlement in customerInfo.entitlements.active.values) {
      final store = switch (entitlement.store) {
        Store.appStore => SubscriptionStore.appStore,
        Store.playStore => SubscriptionStore.playStore,
        _ => null,
      };
      if (store != null) return (store: store, productId: entitlement.productIdentifier);
    }
    return null;
  }

  /// App Storeで予約中のプラン変更を取得する。無ければnull
  /// ダウングレードは次回の更新日まで今の商品のentitlementのままで、RevenueCatのSDKでは変更先を取得できないため、
  /// StoreKitの更新情報を読む。Google Playには同じ手段が無く、常にnullになる
  Future<ScheduledSubscriptionChange?> fetchScheduledChange() async {
    if (defaultTargetPlatform != TargetPlatform.iOS) return null;
    final customerInfo = await Purchases.getCustomerInfo();
    for (final entitlement in customerInfo.entitlements.active.values) {
      final startsAt = DateTime.tryParse(entitlement.expirationDate ?? '');
      if (entitlement.store != Store.appStore || startsAt == null) continue;
      final current = entitlement.productIdentifier;
      final next = await _renewalChannel.invokeMethod<String>('autoRenewProductId', current);
      if (next != null && next != current) return (productId: next, startsAt: startsAt);
    }
    return null;
  }

  /// このApple Accountで有効なサブスクリプションの商品IDを取得する
  /// RevenueCatの顧客とは別に、ストアの契約そのものを見る（退会して作り直すと顧客は変わるが、契約は残る）。
  /// Google Playには同じ手段が無く、常に空になる
  Future<List<String>> fetchStoreProductIds() async {
    if (defaultTargetPlatform != TargetPlatform.iOS) return const [];
    return await _renewalChannel.invokeListMethod<String>('activeProductIds') ?? const [];
  }

  // ---- 操作 ----

  /// [product]を購入する（ストアの確認シートを出す）
  /// [replacing]があれば、Google Playでそのサブスクリプションから変更する。[upgrade]なら即時、そうでなければ次回の更新時に変わる
  /// 閉じられたら[PurchaseCancelledException]、承認待ちなら[PurchasePendingException]、
  /// 契約中・予約済みなら[PurchaseAlreadyOwnedException]を投げる
  Future<void> purchase(StoreProduct product, {String? replacing, bool upgrade = false}) async {
    try {
      await Purchases.purchase(
        PurchaseParams.storeProduct(
          product,
          productChangeInfo: replacing == null
              ? null
              : StoreProductChangeInfo(
                  replacing,
                  replacementMode: upgrade ? StoreReplacementMode.chargeProratedPrice : StoreReplacementMode.deferred,
                ),
        ),
      );
    } on PlatformException catch (error) {
      throw switch (PurchasesErrorHelper.getErrorCode(error)) {
        PurchasesErrorCode.purchaseCancelledError => const PurchaseCancelledException(),
        PurchasesErrorCode.paymentPendingError => const PurchasePendingException(),
        PurchasesErrorCode.productAlreadyPurchasedError => const PurchaseAlreadyOwnedException(),
        _ => error,
      };
    }
  }

  /// 購入を復元する
  /// 有効な購入があればtrueを返す
  Future<bool> restore() async {
    final customerInfo = await Purchases.restorePurchases();
    return customerInfo.entitlements.active.isNotEmpty;
  }
}
