import 'package:flutter/foundation.dart';

import 'account_plan_limits.dart';
import 'app_flavor.dart';

/// App Store・Google Playの月額サブスクリプションの商品（機能仕様書4.6.4）。
///
/// 商品IDは`{Bundle ID}.plan.{プラン}.monthly`。App Store Connectでは2つとも同じ
/// サブスクリプショングループに入れる（アップグレード・ダウングレードをAppleが扱うため）。
/// Google Playでは同じIDのサブスクリプションに、基本プラン`monthly`を1つ作る。
/// どの商品がどのプランかはRevenueCatのentitlementでも対応づける。変更時は両方を更新すること。
abstract final class StoreProducts {
  /// 有料プラン（画面に並べる順）。
  static const paidPlans = [AccountPlanLimits.grade1Plan, AccountPlanLimits.grade2Plan];

  /// RevenueCatの公開SDKキー（ダッシュボードのAPI Keys）。空の間は購入できない。
  static const _appStoreApiKey = '';
  static const _playStoreApiKey = '';

  /// この端末のストアのRevenueCatの公開SDKキー
  static String get apiKey => defaultTargetPlatform == TargetPlatform.android ? _playStoreApiKey : _appStoreApiKey;

  static String get _bundleId => switch (currentFlavor) {
    AppFlavor.dev => 'com.example.orto.dev',
    AppFlavor.prod => 'com.example.orto',
  };

  /// [plan]の商品ID
  static String productIdFor(String plan) => '$_bundleId.plan.$plan.monthly';

  /// 商品ID（[productIdFor]の値）のプラン。有料プランの商品でなければnull
  static String? planForProductId(String productId) {
    for (final plan in paidPlans) {
      if (productIdFor(plan) == productId) return plan;
    }
    return null;
  }

  /// App Storeの解約・プラン変更の画面。
  static final appStoreSubscriptionsUri = Uri.parse('https://apps.apple.com/account/subscriptions');

  /// Google Playの解約・プラン変更の画面。
  static final playStoreSubscriptionsUri = Uri.parse('https://play.google.com/store/account/subscriptions');
}
