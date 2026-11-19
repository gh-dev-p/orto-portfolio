import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/account.dart';
import '../../../domain/models/chat_list_sections.dart';
import '../../../domain/models/group.dart';
import '../../group/view_models/group_providers.dart';
import '../../account/view_models/account_providers.dart';
import '../../chat/view_models/chat_providers.dart';
import '../../friend/view_models/friend_providers.dart';

// ============================================================
// 状態クラス
// ============================================================

/// CHA-01（トーク一覧）の状態
class ChatListState {
  const ChatListState({
    required this.sections,
    required this.myAccountId,
    this.groupRequests = const [],
    this.joinApplications = const [],
  });

  /// 表示区分（通常のトーク／未確認のトークリクエスト）ごとのトーク
  /// 読み込み中・読み込みの失敗も表す
  final AsyncValue<ChatListSections> sections;

  /// 届いているグループへの招待（読み込み中・読み込みの失敗の間は空）
  final List<GroupRequest> groupRequests;

  /// オフ会グループに出した参加の申請（機能仕様書4.7.8.5。読み込み中・読み込みの失敗の間は空）
  final List<JoinApplication> joinApplications;

  /// 使用中のアカウントID
  /// 取得前ならnull（読み込み中として表示する）
  final String? myAccountId;
}

/// CHA-01の1行分の、トークの相手の表示内容
class ChatListPeer {
  const ChatListPeer({required this.account, required this.nickname});

  /// 相手のアカウント
  /// 読み込み中・読み込みの失敗も表す（見つからなければnull）
  final AsyncValue<Account?> account;

  /// 相手に付けたニックネーム
  /// 付けていなければnull
  final String? nickname;
}

// ============================================================
// ViewModel
// ============================================================

/// CHA-01（トーク一覧、ホームのタブ本文）のViewModel
/// 使用中のアカウントのトークを、通常のトークと未確認のトークリクエストに分けて渡す
///
/// 機能仕様書：4.4.1 / 画面設計書：5.3.1
class ChatListViewModel extends Notifier<ChatListState> {
  // ---- 状態・初期化 ----

  /// 表示内容を作る
  /// 使用中のアカウントと、トークの表示区分を監視し、変わるたびに作り直す
  @override
  ChatListState build() {
    return ChatListState(
      sections: ref.watch(chatListSectionsProvider),
      groupRequests: ref.watch(groupRequestsProvider).value ?? const [],
      joinApplications: ref.watch(joinApplicationsProvider).value ?? const [],
      myAccountId: ref.watch(activeAccountProvider)?.id,
    );
  }

  // ---- 操作 ----

  /// トーク一覧を読み込み直す
  /// 読み込みに失敗したときの「再試行」から呼ぶ
  void retry() {
    ref.invalidate(chatRoomsProvider);
    ref.invalidate(chatListSectionsProvider);
  }
}

// ============================================================
// Provider
// ============================================================

/// [ChatListViewModel]のProvider
/// 誰も監視しなくなったら破棄される（autoDispose）
final chatListViewModelProvider = NotifierProvider.autoDispose<ChatListViewModel, ChatListState>(ChatListViewModel.new);

/// CHA-01の1行分の、トークの相手（アカウントIDがキー）の表示内容
/// 行ごとに必要になったときだけ監視する（画面に出ていない行・閉じているリクエストの行の相手は読みに行かない）
final chatListPeerProvider = Provider.autoDispose.family<ChatListPeer, String>((ref, peerAccountId) {
  return ChatListPeer(
    account: ref.watch(accountByIdProvider(peerAccountId)),
    nickname: ref.watch(friendNicknamesProvider)[peerAccountId],
  );
});
