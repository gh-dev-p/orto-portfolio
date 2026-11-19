import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/service_providers.dart';
import '../../../domain/models/account_notification_settings.dart';
import '../../auth/view_models/auth_providers.dart';
import '../../notification/view_models/push_notification_init.dart';

// ============================================================
// 状態クラス
// ============================================================

/// SET-06（通知設定）の状態
class NotificationSettingsState {
  const NotificationSettingsState({required this.settings, required this.permissionDenied});

  /// 対象のアカウントの通知設定
  /// 読み込み中・読み込みの失敗も表す
  final AsyncValue<AccountNotificationSettings> settings;

  /// 端末の設定で、このアプリの通知が許可されていないか
  /// 確認できるまではnull
  final bool? permissionDenied;
}

// ============================================================
// ViewModel
// ============================================================

/// SET-06（通知設定）のViewModel
/// アカウント[accountId]の通知設定と端末の通知の許可の状態を渡し、通知・リアクションの通知のオン・オフを扱う
///
/// 機能仕様書：4.6.1 / 画面設計書：5.6.6
class NotificationSettingsViewModel extends Notifier<NotificationSettingsState> {
  NotificationSettingsViewModel(this.accountId);

  /// 対象のアカウント（SET-01を開いたときの使用中のアカウント）
  final String accountId;

  // ---- 状態・初期化 ----

  /// 表示内容を作る
  /// 通知設定と端末の通知の許可を監視し、変わるたびに作り直す（端末の設定アプリから戻ったときも更新される）
  @override
  NotificationSettingsState build() {
    return NotificationSettingsState(
      settings: ref.watch(accountNotificationSettingsProvider(accountId)),
      permissionDenied: ref.watch(notificationPermissionDeniedProvider).value,
    );
  }

  // ---- 操作 ----

  /// 通知設定を読み込み直す
  /// 読み込みに失敗したときの「再試行」から呼ぶ
  void retry() => ref.invalidate(accountNotificationSettingsProvider(accountId));

  /// このアカウント宛ての通知を受け取るかを[enabled]にする
  /// 成功したらtrue
  Future<bool> setMessagesEnabled(bool enabled) => _update(messages: enabled);

  /// リアクションの通知を受け取るかを[enabled]にする
  /// 成功したらtrue
  Future<bool> setReactionsEnabled(bool enabled) => _update(reactions: enabled);

  /// 通知設定を書き換える
  /// ログインしていなければ何もせずfalse
  Future<bool> _update({bool? messages, bool? reactions}) async {
    final uid = ref.read(authStateChangesProvider).value?.uid;
    if (uid == null) return false;
    try {
      await ref
          .read(notificationRepositoryProvider)
          .updateAccountSettings(uid: uid, accountId: accountId, messages: messages, reactions: reactions);
      return true;
    } catch (_) {
      return false;
    }
  }
}

// ============================================================
// Provider
// ============================================================

/// [NotificationSettingsViewModel]のProvider
/// 対象のアカウントIDごとに作り、誰も監視しなくなったら破棄される（autoDispose）
final notificationSettingsViewModelProvider = NotifierProvider.autoDispose
    .family<NotificationSettingsViewModel, NotificationSettingsState, String>(NotificationSettingsViewModel.new);
