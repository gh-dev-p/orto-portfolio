import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/service_providers.dart';
import '../../../domain/models/account_notification_settings.dart';
import '../../account/view_models/account_providers.dart';
import '../../auth/view_models/auth_providers.dart';
import '../../core/view_models/locale_provider.dart';
import 'notification_open_provider.dart';

// ============================================================
// Provider
// ============================================================

/// プッシュ通知の初期化（機能仕様書4.4.6）
/// AuthGate配下（ログイン済み）で`ref.listen`されることで動き出す、副作用だけのProvider
///
/// - 通知の許可を求める（アプリを開いているときはOS標準のバナーを出さず、アプリ内バナーに回す）
/// - 起動時・アカウント作成時（自分のアカウントの一覧が変わったとき）に、自分が持つ全アカウントへFCMトークンを登録する
///   （データ設計書3.2.2。使用中以外のアカウント宛ての通知も、この端末に届ける）
/// - トークンの更新時・表示言語の変更時に登録し直す（通知文言の言語をCloud Functions側で選ぶため、トークンに言語を持たせる）
/// - 通知のタップ（バックグラウンドから・終了状態からの起動）で、通知先のアカウントのトークを開く
/// - アプリを開いているときの受信を[foregroundNotificationProvider]で知らせる（アプリ内バナーはView側で出す）
final pushNotificationInitProvider = Provider<void>((ref) {
  final repository = ref.watch(notificationRepositoryProvider);

  // 削除済み（isDeleted）のアカウントはaccountsProviderの時点で除かれている。
  List<String> ownedAccountIds() => [
    for (final account in ref.read(accountsProvider).value ?? const []) account.id,
  ];

  void registerAll() {
    repository
        .registerToken(ownedAccountIds(), languageCode: ref.read(localeProvider).languageCode)
        .catchError((Object _) {}); // 次の起動・更新時に再登録されるため、失敗は無視する
  }

  // 許可を求めた結果を、SET-01の「通知」の表示に反映する。
  // iOSは許可を求めた後にAPNsトークンが届き、それまでFCMトークンを取れないため、ここでも登録し直す。
  repository.requestPermissionAndConfigure().then((_) {
    ref.invalidate(notificationPermissionDeniedProvider);
    if (ownedAccountIds().isNotEmpty) registerAll();
  });

  final tokenRefreshSub = repository.onTokenRefresh.listen((_) => registerAll());

  // いま見ているトーク宛ての新着は、画面に表示されているためバナーを出さない。
  final foregroundSub = repository.foregroundNotifications.listen((target) {
    if (shouldShowForegroundBanner(target, ref.read(openChatProvider))) {
      ref.read(foregroundNotificationProvider.notifier).received(target);
    }
  });

  // 通知のタップで、通知先のアカウントのトークを開く（機能仕様書4.4.6.1）。
  void openFromNotification(NotificationTarget target) {
    ref.read(notificationOpenerProvider).open(target).catchError((Object _) {}); // 開けなくても通常の起動のまま
  }

  final openedSub = repository.openedNotifications.listen(openFromNotification);
  repository
      .initialNotification()
      .then((target) {
        if (target != null) openFromNotification(target);
      })
      .catchError((Object _) {});

  // fireImmediately必須：本Providerが初期化される時点で既にアカウント一覧の取得が完了済みの
  // ことがあり、その場合「値の変化」は発生しないため、起動時点の登録が漏れてしまう。
  // アカウントの作成・削除で一覧のIDが変わったときにも登録し直す。
  ref.listen<List<String>>(
    accountsProvider.select((async) => [for (final account in async.value ?? const []) account.id]),
    (previous, next) {
      if (next.isNotEmpty && !listEquals(previous, next)) registerAll();
    },
    fireImmediately: true,
  );
  // 表示言語を変えたら、通知文言の言語を合わせるため登録し直す。
  ref.listen<Locale>(localeProvider, (previous, next) {
    if (previous?.languageCode != next.languageCode) registerAll();
  });

  ref.onDispose(() {
    tokenRefreshSub.cancel();
    foregroundSub.cancel();
    openedSub.cancel();
  });
});

/// 端末の設定で通知が許可されていないか（SET-01の「通知」、機能仕様書4.6.1）
/// 端末の設定アプリから戻ったときに変わっている可能性があるため、アプリが前面に戻るたびに確認し直す（確認に失敗したら、許可されている扱いにして案内を出さない）
final notificationPermissionDeniedProvider = FutureProvider<bool>((ref) async {
  final listener = AppLifecycleListener(onResume: ref.invalidateSelf);
  ref.onDispose(listener.dispose);
  try {
    return await ref.watch(notificationRepositoryProvider).isPermissionDenied();
  } catch (_) {
    return false;
  }
});

/// アカウント[accountId]の通知設定
/// SET-01の「通知」の表示と、SET-06（通知設定）で使う。ログインしていなければ初期値（オン）
final accountNotificationSettingsProvider = StreamProvider.autoDispose.family<AccountNotificationSettings, String>((
  ref,
  accountId,
) {
  final uid = ref.watch(authStateChangesProvider.select((async) => async.value?.uid));
  if (uid == null) return Stream.value(AccountNotificationSettings.defaults);
  return ref.watch(notificationRepositoryProvider).watchAccountSettings(uid: uid, accountId: accountId);
});

// ============================================================
// ViewModel
// ============================================================

/// アプリを開いているときに最後に受信した通知（機能仕様書4.4.6.2）
/// Viewがこの変化を監視して、アプリ内バナーを出す。受信するたびに[count]が増えるため、同じ通知が続いても変化として流れる
/// [target]は開く先のトーク（トークのデータが無い通知ではnull）
typedef ForegroundNotification = ({int count, NotificationTarget? target});

/// アプリを開いているときの通知の受信を知らせる（機能仕様書4.4.6.2）
class ForegroundNotificationNotifier extends Notifier<ForegroundNotification> {

  // ---- 状態・初期化 ----

  /// 最初の状態を作る
  /// 0回から始める
  @override
  ForegroundNotification build() => (count: 0, target: null);

  // ---- 操作 ----

  /// 通知を受信した
  void received(NotificationTarget? target) => state = (count: state.count + 1, target: target);
}

/// [ForegroundNotificationNotifier]のProvider
/// アプリ全体で共有するため、破棄しない
final foregroundNotificationProvider = NotifierProvider<ForegroundNotificationNotifier, ForegroundNotification>(
  ForegroundNotificationNotifier.new,
);
