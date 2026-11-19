import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/account.dart';
import '../../../domain/models/friend.dart';
import '../../account/view_models/account_providers.dart';
import 'friend_providers.dart';

// ============================================================
// 状態クラス
// ============================================================

/// FRI-01（友だち一覧）の状態
class FriendListState {
  const FriendListState({required this.friends, required this.myAccountId});

  /// 追加済みの友だち（新しい順）
  /// 読み込み中・読み込みの失敗も表す
  final AsyncValue<List<Friend>> friends;

  /// 使用中のアカウントID
  /// 取得前ならnull（読み込み中として表示する）
  final String? myAccountId;
}

// ============================================================
// ViewModel
// ============================================================

/// FRI-01（友だち一覧、ホームのタブ本文）のViewModel
/// 使用中のアカウントが追加した友だちを渡す
///
/// 機能仕様書：4.3.2 / 画面設計書：5.4.1
class FriendListViewModel extends Notifier<FriendListState> {

  // ---- 状態・初期化 ----

  /// 表示内容を作る
  /// 使用中のアカウントと、友だちの一覧を監視し、変わるたびに作り直す
  @override
  FriendListState build() {
    return FriendListState(
      friends: ref.watch(friendsProvider),
      myAccountId: ref.watch(activeAccountProvider)?.id,
    );
  }

  // ---- 操作 ----

  /// 友だちの一覧を読み込み直す
  /// 読み込みに失敗したときの「再試行」から呼ぶ
  void retry() => ref.invalidate(friendsProvider);
}

// ============================================================
// Provider
// ============================================================

/// [FriendListViewModel]のProvider
/// 誰も監視しなくなったら破棄される（autoDispose）
final friendListViewModelProvider = NotifierProvider.autoDispose<FriendListViewModel, FriendListState>(
  FriendListViewModel.new,
);

/// FRI-01の1行分の、友だち（アカウントIDがキー）のアカウント
/// 行ごとに必要になったときだけ監視する（画面に出ていない行の友だちは読みに行かない）。読み込み中・読み込みの失敗も表す（見つからなければnull）
final friendListPeerProvider = Provider.autoDispose.family<AsyncValue<Account?>, String>((ref, friendAccountId) {
  return ref.watch(accountByIdProvider(friendAccountId));
});
