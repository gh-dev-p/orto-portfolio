import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/service_providers.dart';
import '../../../domain/models/account.dart';
import '../../../domain/models/friend.dart';
import '../../../domain/models/friend_request.dart';
import '../../account/view_models/account_providers.dart';
import '../../friend/view_models/friend_invite_key_providers.dart';
import '../../friend/view_models/friend_providers.dart';
import '../../friend/view_models/friend_request_providers.dart';

// ============================================================
// 状態クラス
// ============================================================

/// PRO-01（友だちのプロフィール）を開くときの引数
/// 表示する相手のアカウントIDと、自分のアカウントIDの組。グループのメンバーの画面から開いたときは、
/// そのグループのチャットルームID（[groupChatRoomId]）も持ち、友だち追加の代わりに友だち申請を出す
typedef FriendProfileArgs = ({String accountId, String myAccountId, String? groupChatRoomId});

/// グループのメンバーの画面から開いたPRO-01での、友だち申請の状態（機能仕様書4.3.8）
enum FriendRequestStatus {
  /// まだ申請していない（「友だち申請」を出す）
  none,

  /// 申請を送った（「申請中」。相手が断っても変わらない）
  pending,

  /// 相手から申請が届いている（「承認する」を出す）
  received,
}

/// PRO-01（友だちのプロフィール）の状態
class FriendProfileState {
  const FriendProfileState({
    this.account,
    this.friend,
    this.requestStatus = FriendRequestStatus.none,
    this.adding = false,
    this.blocking = false,
  });

  /// 相手のアカウント
  /// 取得前・見つからなければnull
  final Account? account;

  /// 相手を友だちに追加した記録
  /// 友だちでなければnull（ニックネームもここから取る）
  final Friend? friend;

  /// 友だち申請の状態（グループのメンバーの画面から開いたときだけ使う）
  final FriendRequestStatus requestStatus;

  /// 友だち追加・友だち申請・承認を実行中か（二重タップの防止）
  final bool adding;

  /// ブロックの確認〜実行の途中か（二重タップの防止）
  final bool blocking;

  /// 相手が友だちか
  bool get isFriend => friend != null;

  /// 相手が退会済みか
  bool get isDeletedPeer => account?.isDeleted ?? false;

  /// 指定した項目だけを変えた、新しい状態を作る
  /// 指定しなかった項目は今の値を引き継ぐ（friendはnullにもできるよう、常に指定する）
  FriendProfileState copyWith({
    Account? account,
    required Friend? friend,
    FriendRequestStatus? requestStatus,
    bool? adding,
    bool? blocking,
  }) {
    return FriendProfileState(
      account: account ?? this.account,
      friend: friend,
      requestStatus: requestStatus ?? this.requestStatus,
      adding: adding ?? this.adding,
      blocking: blocking ?? this.blocking,
    );
  }
}

// ============================================================
// ViewModel
// ============================================================

/// PRO-01（友だちのプロフィール）のViewModel
/// 相手のプロフィールを表示し、友だち追加・友だち申請（グループのメンバーの画面から開いたとき）・ニックネームの設定・ブロックを扱う
///
/// FRI-04（検索結果）・QRC-01（QRの読み取り）から開いたときは、友だち追加の確認・確定の画面も兼ねる。友だちかどうかは友だちの一覧の監視で決まるため、追加した後は自動でトークのアイコンに切り替わる
///
/// 機能仕様書：4.5.2・4.3.1・4.3.8・4.3.3・4.3.4 / 画面設計書：5.7.1
class FriendProfileViewModel extends Notifier<FriendProfileState> {
  FriendProfileViewModel(this.args);

  // ---- 状態・初期化 ----

  /// 表示する相手と自分
  final FriendProfileArgs args;

  /// 表示内容を作る
  /// 相手のアカウントと、友だちの一覧を監視し、変わったら、実行中の表示を残したまま差し替える
  @override
  FriendProfileState build() {
    final account = ref.watch(accountByIdProvider(args.accountId)).value;
    final friends = ref.watch(friendsProvider).value ?? const <Friend>[];
    Friend? friend;
    for (final f in friends) {
      if (f.friendAccountId == args.accountId) {
        friend = f;
        break;
      }
    }
    final requestStatus = args.groupChatRoomId == null ? FriendRequestStatus.none : _watchRequestStatus();
    return stateOrNull?.copyWith(account: account, friend: friend, requestStatus: requestStatus) ??
        FriendProfileState(account: account, friend: friend, requestStatus: requestStatus);
  }

  /// 届いた申請・送った申請の監視から、友だち申請の状態を決める（期限切れは無いものとする）
  FriendRequestStatus _watchRequestStatus() {
    final now = ref.watch(friendRequestClockProvider)();
    final received = ref.watch(receivedFriendRequestsProvider(args.myAccountId)).value ?? const <FriendRequest>[];
    if (received.any((r) => r.senderAccountId == args.accountId && r.isLiveAt(now))) {
      return FriendRequestStatus.received;
    }
    final sent = ref.watch(sentFriendRequestsProvider(args.myAccountId)).value ?? const <SentFriendRequest>[];
    if (sent.any((r) => r.receiverAccountId == args.accountId && r.isLiveAt(now))) {
      return FriendRequestStatus.pending;
    }
    return FriendRequestStatus.none;
  }

  // ---- 操作 ----

  /// 相手を友だちに追加する（機能仕様書4.3.1：LINEにならい片方向で、自分の友だちにだけ加える）
  /// 成功したらtrue（友だちの一覧の変化で、自動でトークのアイコンに切り替わる）。実行中なら何もせずtrue
  Future<bool> addFriend() async {
    if (state.adding) return true;
    state = state.copyWith(friend: state.friend, adding: true);
    try {
      // マイQRコード・招待リンクで受け取った招待キーがあれば添える。
      final inviteKey = ref.read(receivedInviteKeysProvider)[args.accountId];
      await ref
          .read(friendRepositoryProvider)
          .addFriend(myAccountId: args.myAccountId, peerAccountId: args.accountId, inviteKey: inviteKey);
      return true;
    } catch (_) {
      return false;
    } finally {
      if (ref.mounted) state = state.copyWith(friend: state.friend, adding: false);
    }
  }

  /// グループのメンバーの相手に友だち申請を送る（機能仕様書4.3.8.1）
  /// 相手から申請が届いていて承認になったらtrue（送った申請・友だちの監視で、表示は自動で切り替わる）。
  /// 失敗したら[FriendRequestException]を投げる。実行中なら何もせずfalse
  Future<bool> sendFriendRequest() async {
    final chatRoomId = args.groupChatRoomId;
    if (chatRoomId == null || state.adding) return false;
    state = state.copyWith(friend: state.friend, adding: true);
    try {
      return await ref
          .read(friendRequestRepositoryProvider)
          .send(accountId: args.myAccountId, chatRoomId: chatRoomId, targetAccountId: args.accountId);
    } finally {
      if (ref.mounted) state = state.copyWith(friend: state.friend, adding: false);
    }
  }

  /// 相手から届いている友だち申請を承認する（機能仕様書4.3.8.2）
  /// 失敗したら[FriendRequestException]を投げる。実行中なら何もしない
  Future<void> acceptFriendRequest() async {
    if (state.adding) return;
    state = state.copyWith(friend: state.friend, adding: true);
    try {
      await ref
          .read(friendRequestRepositoryProvider)
          .respond(accountId: args.myAccountId, senderAccountId: args.accountId, accept: true);
    } finally {
      if (ref.mounted) state = state.copyWith(friend: state.friend, adding: false);
    }
  }

  /// 相手のニックネームを設定・解除する（機能仕様書4.3.3）
  /// 空文字なら未設定に戻す。成功したらtrue
  Future<bool> updateNickname(String nickname) async {
    try {
      await ref
          .read(friendRepositoryProvider)
          .updateFriendNickname(accountId: args.myAccountId, friendAccountId: args.accountId, nickname: nickname);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// 相手のメモを設定・解除する（機能仕様書4.3.7）
  /// 空文字なら未設定に戻す。成功したらtrue
  Future<bool> updateMemo(String memo) async {
    try {
      await ref
          .read(friendRepositoryProvider)
          .updateFriendMemo(accountId: args.myAccountId, friendAccountId: args.accountId, memo: memo);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// 相手のメモのピン留めを切り替える（機能仕様書4.3.7）。成功したらtrue
  Future<bool> updateMemoPinned(bool pinned) async {
    try {
      await ref
          .read(friendRepositoryProvider)
          .updateFriendMemoPinned(accountId: args.myAccountId, friendAccountId: args.accountId, pinned: pinned);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// 相手をブロックする（友だち・未追加のどちらの相手でも可）
  /// ブロックの記録・双方向の友だちの解除・自分側の未読のリセットを1回で行う。失敗したら例外を投げる
  Future<void> block() {
    return ref.read(blockRepositoryProvider).blockAccount(accountId: args.myAccountId, targetAccountId: args.accountId);
  }

  /// ブロックの確認〜実行の途中かを設定する
  /// ブロックの確認（block_flow）の間、Viewが呼ぶ
  void setBlocking(bool blocking) => state = state.copyWith(friend: state.friend, blocking: blocking);
}

// ============================================================
// Provider
// ============================================================

/// [FriendProfileViewModel]のProvider
/// 引数は表示する相手と自分。誰も監視しなくなったら破棄される（autoDispose）
final friendProfileViewModelProvider =
    NotifierProvider.autoDispose.family<FriendProfileViewModel, FriendProfileState, FriendProfileArgs>(
      FriendProfileViewModel.new,
    );
