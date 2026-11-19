import 'dart:async';
import 'dart:developer' as developer;

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// App Checkのプロバイダーを有効にする。
///
/// - [debug]（デバッグビルド。シミュレーター・エミュレーター含む）：Debug Provider。
/// - それ以外：AndroidはPlay Integrity。iOSは、[appAttest]（本番のflavor）ならApp Attestで、App Attestに
///   対応しない端末ではFirebase SDKがDeviceCheckを使う（`AppleAppAttestWithDeviceCheckFallbackProvider`）。
///   devのflavorはDeviceCheck（App Attestのentitlementも、dev側のFirebaseへの登録も無いため）。
///
/// Firebase SDKのフォールバックは「端末がApp Attestに対応しない」ときだけで、App Attestの検証が
/// サーバーで通らないとき（Appleのサーバーの障害、Firebaseの登録の誤りなど）はDeviceCheckに戻らない。
/// 本番は強制（Enforce）を有効にしているため、そのままだとトークンが取れず、サーバーにつながらなくなる。
/// そこで起動後にトークンの取得を確かめ、取れなければこの起動の間だけDeviceCheckに切り替える
/// （切り替え前と同じ強さに戻るだけで、今より弱くはならない）。次の起動ではまたApp Attestから試す。
///
/// App Attestでのトークンの取得が一度通るまでは、端末に残る古いトークン（1.1.1までのDeviceCheckのもの）を
/// 使わず、取得し直して確かめる。古いトークンの期限（1時間）が切れた後に初めて失敗が分かり、
/// その起動の間つながらなくなるのを防ぐため。
class AppCheckActivator {
  AppCheckActivator({
    required SharedPreferences preferences,
    required bool debug,
    required bool apple,
    required this.appAttest,
    Future<void> Function({
      required AndroidAppCheckProvider providerAndroid,
      required AppleAppCheckProvider providerApple,
    })?
    activate,
    Future<String?> Function({required bool forceRefresh})? getToken,
    this.verifyTimeout = const Duration(seconds: 20),
  }) : _preferences = preferences,
       _debug = debug,
       _apple = apple,
       _activate = activate ?? _activateWithFirebase,
       _getToken = getToken ?? _getTokenWithFirebase;

  /// App Attestでトークンが取れたことがあるかの保存先。
  static const appAttestVerifiedKey = 'appCheckAppAttestVerified';

  final SharedPreferences _preferences;
  final bool _debug;
  final bool _apple;

  /// iOSのリリースビルドでApp Attestを使うか（本番のflavorだけtrue）。
  final bool appAttest;
  final Future<void> Function({
    required AndroidAppCheckProvider providerAndroid,
    required AppleAppCheckProvider providerApple,
  })
  _activate;
  final Future<String?> Function({required bool forceRefresh}) _getToken;

  /// トークンの取得を待つ長さ。超えたら失敗として扱い、DeviceCheckに切り替える。
  final Duration verifyTimeout;

  AndroidAppCheckProvider get _androidProvider =>
      _debug ? const AndroidDebugProvider() : const AndroidPlayIntegrityProvider();

  /// プロバイダーを有効にする。iOSのリリースビルドでは、トークンの取得の確かめを裏で始める
  /// （起動はこの確かめを待たない。完了は[verification]で待てる）。
  Future<void> activate() async {
    final useAppAttest = _apple && !_debug && appAttest;
    final AppleAppCheckProvider appleProvider;
    if (_debug) {
      appleProvider = const AppleDebugProvider();
    } else if (appAttest) {
      appleProvider = const AppleAppAttestWithDeviceCheckFallbackProvider();
    } else {
      appleProvider = const AppleDeviceCheckProvider();
    }
    await _activate(providerAndroid: _androidProvider, providerApple: appleProvider);
    if (useAppAttest) {
      verification = _verifyAppAttest();
    }
  }

  /// iOSのリリースビルドでの、トークンの取得の確かめ。それ以外ではnull。
  Future<void>? verification;

  Future<void> _verifyAppAttest() async {
    final verified = _preferences.getBool(appAttestVerifiedKey) ?? false;
    try {
      final token = await _getToken(forceRefresh: !verified).timeout(verifyTimeout);
      if (token == null || token.isEmpty) {
        throw StateError('App Check token is empty');
      }
      if (!verified) {
        await _preferences.setBool(appAttestVerifiedKey, true);
      }
    } catch (error, stackTrace) {
      developer.log(
        'App Attest token failed; falling back to DeviceCheck for this launch',
        name: 'AppCheck',
        error: error,
        stackTrace: stackTrace,
      );
      await _preferences.setBool(appAttestVerifiedKey, false);
      try {
        await _activate(providerAndroid: _androidProvider, providerApple: const AppleDeviceCheckProvider());
        await _getToken(forceRefresh: true).timeout(verifyTimeout);
      } catch (error, stackTrace) {
        // オフラインなど。DeviceCheckのまま、Firebase SDKが次のリクエストで取り直す。
        developer.log('DeviceCheck token failed', name: 'AppCheck', error: error, stackTrace: stackTrace);
      }
    }
  }

  static Future<void> _activateWithFirebase({
    required AndroidAppCheckProvider providerAndroid,
    required AppleAppCheckProvider providerApple,
  }) {
    return FirebaseAppCheck.instance.activate(providerAndroid: providerAndroid, providerApple: providerApple);
  }

  static Future<String?> _getTokenWithFirebase({required bool forceRefresh}) {
    return FirebaseAppCheck.instance.getToken(forceRefresh);
  }
}
