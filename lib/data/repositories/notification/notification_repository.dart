import 'dart:io';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../../domain/models/account_notification_settings.dart';
import '../../../domain/models/notification_target.dart';
import '../../../domain/models/token_unregister_denied_exception.dart';
import '../../services/common/firestore_paths.dart';
import '../../services/notification/push_notification_service.dart';

export '../../../domain/models/account_notification_settings.dart';
export '../../../domain/models/notification_target.dart';
export '../../../domain/models/token_unregister_denied_exception.dart';

// ============================================================
// リポジトリ
// ============================================================

/// プッシュ通知のリポジトリ（機能仕様書4.4.6）
/// 通知の許可・FCMトークンの登録（Firestore）・アカウントごとの通知設定と、受信・タップした通知のデータの読み取りを扱う
///
/// 通知本文は、送信者・宛先アカウント名・メッセージ内容を含めない固定の文言（Cloud Functions側で組み立てる。firebase/functions/index.js）のため、本クラスは通知の内容を扱わない
class NotificationRepository {
  NotificationRepository(this._pushService, this._paths);

  // ---- 状態・初期化 ----

  /// FCMのサービス
  final PushNotificationService _pushService;

  /// Firestoreのパス（接続先）
  final FirestorePaths _paths;

  // ---- 許可 ----

  /// 通知の許可を求め、アプリを開いているときの表示方法を設定する
  /// アプリを開いているときはOSの通知センターに出さず、[foregroundNotifications]でアプリ内バナーに回す（機能仕様書4.4.6.2）
  Future<void> requestPermissionAndConfigure() => _pushService.requestPermissionAndConfigure();

  /// 端末の設定で、このアプリの通知が許可されていないか（機能仕様書4.6.1）
  /// まだ許可を求めていない場合はfalse
  Future<bool> isPermissionDenied() => _pushService.isPermissionDenied();

  // ---- トークン ----

  /// FCMトークンが更新されたときに流れる
  /// 流れたら、[registerToken]で登録し直す
  Stream<void> get onTokenRefresh => _pushService.onTokenRefresh;

  /// この端末のFCMトークンを、自分が持つ全アカウント（[accountIds]、削除済みを除く）に登録する（データ設計書3.2.2）
  /// 同じトークンは上書きし、`language`も更新する（[languageCode]はアプリの表示言語で、Cloud Functionsが通知文言の言語を選ぶのに使う）
  Future<void> registerToken(List<String> accountIds, {required String languageCode}) async {
    if (accountIds.isEmpty) return;
    final token = await _pushService.token();
    if (token == null) return;
    for (final ids in _groupsOfAccountIds(accountIds)) {
      final batch = _paths.batch();
      for (final accountId in ids) {
        batch.set(_paths.fcmTokens(accountId).doc(token), {
          'token': token,
          'platform': Platform.isIOS ? 'ios' : 'android',
          'language': languageCode,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
    }
  }

  /// この端末のFCMトークンを、アカウント[accountIds]から外す（管理者のログアウト、機能仕様書4.1.7）
  /// トークンを取得できなければ、登録もされていないため何もしない
  ///
  /// Firestoreの書き込みはオフラインだと完了しないため、全体を[_unregisterTimeout]で打ち切って例外を投げる
  /// ルールがログイン中の保有ユーザにだけ削除を許すため、サインアウトの前に呼ぶ（拒否されたら[TokenUnregisterDeniedException]を投げる）
  ///
  /// 途中のバッチで失敗すると、前のバッチの分だけ外れた状態で例外を投げる。外れた分をもう一度消しても成功するので、呼び直せば続きから完了する
  Future<void> unregisterToken(List<String> accountIds) async {
    if (accountIds.isEmpty) return;
    final token = await _pushService.token();
    if (token == null) return;
    try {
      await _deleteToken(token, accountIds).timeout(_unregisterTimeout);
    } on FirebaseException catch (e) {
      debugPrint('[NotificationRepository] unregisterToken failed: plugin=${e.plugin} code=${e.code}');
      if (e.code == 'permission-denied') throw const TokenUnregisterDeniedException();
      rethrow;
    }
  }

  /// [token]をアカウント[accountIds]から消す
  Future<void> _deleteToken(String token, List<String> accountIds) async {
    for (final ids in _groupsOfAccountIds(accountIds)) {
      final batch = _paths.batch();
      for (final accountId in ids) {
        batch.delete(_paths.fcmTokens(accountId).doc(token));
      }
      await batch.commit();
    }
  }

  /// [accountIds]を、1回のバッチに入れる単位に分ける
  static Iterable<List<String>> _groupsOfAccountIds(List<String> accountIds) sync* {
    for (var start = 0; start < accountIds.length; start += _accountsPerBatch) {
      yield accountIds.sublist(start, min(start + _accountsPerBatch, accountIds.length));
    }
  }

  /// 1回のバッチで扱うアカウントの数
  /// Firestoreのルールの参照は1回のバッチで20回までで、`isOwnerOfAccount`が1件につき2回参照するため
  static const _accountsPerBatch = 10;

  /// [unregisterToken]の完了を待つ最大の時間
  static const _unregisterTimeout = Duration(seconds: 10);

  // ---- アカウントごとの通知設定 ----

  /// アカウント[accountId]の通知設定を監視する（データ設計書3.1.1）
  /// [uid]はログイン中のユーザ（`users/{uid}/ownedAccounts/{accountId}`に持つ。本人しか読めない）
  Stream<AccountNotificationSettings> watchAccountSettings({required String uid, required String accountId}) => _paths
      .ownedAccounts(uid)
      .doc(accountId)
      .snapshots()
      .map((doc) => AccountNotificationSettings.fromData(doc.data()));

  /// アカウント[accountId]の通知設定を変える
  /// [messages]・[reactions]のうち、指定したものだけを書き換える
  Future<void> updateAccountSettings({
    required String uid,
    required String accountId,
    bool? messages,
    bool? reactions,
  }) {
    return _paths.ownedAccounts(uid).doc(accountId).update({
      AccountNotificationSettings.messagesField: ?messages,
      AccountNotificationSettings.reactionsField: ?reactions,
    });
  }

  /// アカウント[accountId]の、グループ[chatRoomId]の通知をオフ（[muted]）・オンにする（機能仕様書4.7.3.5）
  Future<void> setGroupMuted({
    required String uid,
    required String accountId,
    required String chatRoomId,
    required bool muted,
  }) {
    return _paths.ownedAccounts(uid).doc(accountId).update({
      AccountNotificationSettings.mutedGroupIdsField: muted
          ? FieldValue.arrayUnion([chatRoomId])
          : FieldValue.arrayRemove([chatRoomId]),
    });
  }

  // ---- 受信 ----

  /// アプリを開いているときに受信した通知の、開く先のトーク
  /// トークのデータが無い通知ではnullを流す
  Stream<NotificationTarget?> get foregroundNotifications =>
      _pushService.onForegroundMessage.map((message) => NotificationTarget.fromData(message.data));

  /// アプリがバックグラウンドのときに、通知のタップでアプリを開いた場合の、開く先のトーク（機能仕様書4.4.6.1）
  /// トークのデータが無い通知は流さない
  Stream<NotificationTarget> get openedNotifications => _pushService.onNotificationOpened
      .map((message) => NotificationTarget.fromData(message.data))
      .where((target) => target != null)
      .cast<NotificationTarget>();

  /// アプリが終了していたときに、通知のタップで起動した場合の、開く先のトーク
  /// それ以外・トークのデータが無い通知ならnull
  Future<NotificationTarget?> initialNotification() async {
    final message = await _pushService.initialNotification();
    return message == null ? null : NotificationTarget.fromData(message.data);
  }
}
