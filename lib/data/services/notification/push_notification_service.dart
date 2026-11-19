import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';

// ============================================================
// サービス
// ============================================================

/// Firebase Cloud Messaging（FCM）を包むサービス
/// 状態を持たず、FCMの結果をそのまま返す（トークンのFirestoreへの登録・通知のデータの読み取りは[NotificationRepository]が行う）
class PushNotificationService {
  PushNotificationService(this._messaging);

  // ---- 状態・初期化 ----

  /// FCMのインスタンス
  final FirebaseMessaging _messaging;

  // ---- 許可 ----

  /// 通知の許可を求め、アプリを開いているときの表示方法を設定する
  /// アプリを開いているときはOSの通知センターに出さない（アプリ内バナーで知らせるため。iOSの二重表示の防止）
  Future<void> requestPermissionAndConfigure() async {
    await _messaging.requestPermission();
    await _messaging.setForegroundNotificationPresentationOptions(alert: false, badge: true, sound: false);
  }

  /// 端末の設定で、このアプリの通知が許可されていないか
  /// まだ許可を求めていない場合はfalse
  Future<bool> isPermissionDenied() async {
    final settings = await _messaging.getNotificationSettings();
    return settings.authorizationStatus == AuthorizationStatus.denied;
  }

  // ---- トークン ----

  /// この端末のFCMトークン
  /// 取得できなければnull
  ///
  /// iOSでは、APNsトークンが届く前に取ると`apns-token-not-set`で失敗するため、届くまで待ってから取る
  /// （起動直後・許可を求めた直後は、まだ届いていないことがある）
  Future<String?> token() async {
    if (Platform.isIOS && await _waitForApnsToken() == null) return null;
    // firebase_messaging 17 で非推奨になった。代わりの register() は FCM トークンではなく FID を返し、
    // サーバーの送信方法も変える必要があるため、今は FCM トークンのまま使う
    // ignore: deprecated_member_use
    return _messaging.getToken();
  }

  /// APNsトークンが届くまで、1秒ごとに最大[_apnsTokenWaitSeconds]秒待つ
  /// 届かなければnull
  Future<String?> _waitForApnsToken() async {
    for (var i = 0; i < _apnsTokenWaitSeconds; i++) {
      final apnsToken = await _messaging.getAPNSToken();
      if (apnsToken != null) return apnsToken;
      await Future<void>.delayed(const Duration(seconds: 1));
    }
    return _messaging.getAPNSToken();
  }

  /// APNsトークンを待つ最大の秒数
  static const _apnsTokenWaitSeconds = 30;

  /// FCMトークンが更新されたときに流れる
  // getToken と同じ理由で、非推奨の onTokenRefresh のまま使う
  // ignore: deprecated_member_use
  Stream<String> get onTokenRefresh => _messaging.onTokenRefresh;

  // ---- 受信 ----

  /// アプリを開いているときに受信した通知
  Stream<RemoteMessage> get onForegroundMessage => FirebaseMessaging.onMessage;

  /// アプリがバックグラウンドのときに、通知のタップでアプリを開いたときに流れる
  Stream<RemoteMessage> get onNotificationOpened => FirebaseMessaging.onMessageOpenedApp;

  /// アプリが終了していたときに、通知のタップで起動した場合のその通知
  /// それ以外はnull
  Future<RemoteMessage?> initialNotification() => _messaging.getInitialMessage();
}
