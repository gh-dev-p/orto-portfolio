import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/service_providers.dart';
import '../../../domain/models/chat_room.dart';
import '../../../domain/models/group.dart';
import '../../../domain/models/settlement.dart';
import '../../account/view_models/active_account_provider.dart';
import '../../chat/view_models/chat_providers.dart';

// ============================================================
// ViewModel
// ============================================================

/// CHA-01の「グループへの招待」を開いているか
/// 招待の通知のタップで開く（機能仕様書4.7.2.1）
class GroupRequestsExpandedNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void toggle() => state = !state;

  void expand() => state = true;
}

// ============================================================
// Provider
// ============================================================

/// [GroupRequestsExpandedNotifier]のProvider
final groupRequestsExpandedProvider = NotifierProvider<GroupRequestsExpandedNotifier, bool>(
  GroupRequestsExpandedNotifier.new,
);

/// アクティブアカウントに届いているグループへの招待（機能仕様書4.7.2.2）
final groupRequestsProvider = StreamProvider<List<GroupRequest>>((ref) async* {
  final activeId = ref.watch(activeAccountIdProvider);
  if (activeId == null) {
    yield const [];
    return;
  }
  yield* ref.watch(groupRepositoryProvider).watchRequests(activeId);
});

/// このグループの`chatList`の行
/// 引数は(自分のアカウントID, チャットルームID)。退会すると値がnullになる
final groupEntryProvider = StreamProvider.autoDispose.family<ChatListEntry?, (String, String)>((ref, key) {
  final (accountId, chatRoomId) = key;
  return ref.watch(groupRepositoryProvider).watchEntry(accountId: accountId, chatRoomId: chatRoomId);
});

/// グループの参加者（引数はチャットルームID）
final groupMembersProvider = FutureProvider.autoDispose.family<List<GroupMember>, String>((ref, chatRoomId) {
  return ref.watch(groupRepositoryProvider).fetchMembers(chatRoomId);
});

/// アクティブアカウントが参加中のグループ（FRI-01の「グループ」タブ）
final joinedGroupsProvider = Provider<AsyncValue<List<ChatListEntry>>>((ref) {
  return ref.watch(chatRoomsProvider).whenData((rooms) => rooms.where((room) => room.isGroup).toList());
});

/// グループの種類と主催チーム（引数はチャットルームID。機能仕様書4.7.8）
final groupRoomProvider = StreamProvider.autoDispose.family<GroupRoom?, String>((ref, chatRoomId) {
  return ref.watch(groupRepositoryProvider).watchRoom(chatRoomId);
});

/// 自分の`members`の1件（引数は(自分のアカウントID, チャットルームID)。主催チームへの誘いのカードに使う）
final myGroupMemberProvider = StreamProvider.autoDispose.family<GroupMember?, (String, String)>((ref, key) {
  final (accountId, chatRoomId) = key;
  return ref.watch(groupRepositoryProvider).watchMember(chatRoomId: chatRoomId, accountId: accountId);
});

/// CHA-01の「参加の申請」を開いているか（機能仕様書4.7.8.5）
/// 申請の結果の通知のタップで開く
class JoinApplicationsExpandedNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void toggle() => state = !state;

  void expand() => state = true;
}

/// [JoinApplicationsExpandedNotifier]のProvider
final joinApplicationsExpandedProvider = NotifierProvider<JoinApplicationsExpandedNotifier, bool>(
  JoinApplicationsExpandedNotifier.new,
);

/// アクティブアカウントが出している参加の申請（オフ会グループ、機能仕様書4.7.8.5）
final joinApplicationsProvider = StreamProvider<List<JoinApplication>>((ref) async* {
  final activeId = ref.watch(activeAccountIdProvider);
  if (activeId == null) {
    yield const [];
    return;
  }
  yield* ref.watch(groupRepositoryProvider).watchApplications(activeId);
});

/// 答えを待っている参加の申請（引数はチャットルームID。主催チームの人だけが読める）
/// 主催チームでない（読めない）ときは空
final groupJoinRequestsProvider = StreamProvider.autoDispose.family<List<GroupJoinRequest>, String>((ref, chatRoomId) {
  return ref
      .watch(groupRepositoryProvider)
      .watchJoinRequests(chatRoomId)
      .handleError((Object _) {}, test: (error) => error is FirebaseException && error.code == 'permission-denied');
});

/// メンバーの出欠（引数はチャットルームID。機能仕様書4.7.8.9）。読めないときは空
final groupAttendanceProvider = StreamProvider.autoDispose.family<List<GroupAttendance>, String>((ref, chatRoomId) {
  return ref.watch(groupRepositoryProvider).watchAttendance(chatRoomId);
});

/// 出欠の集計（引数は(自分のアカウントID, チャットルームID)）。ルームを読めていなければnull
final attendanceSummaryProvider = Provider.autoDispose.family<AttendanceSummary?, (String, String)>((ref, key) {
  final (accountId, chatRoomId) = key;
  final room = ref.watch(groupRoomProvider(chatRoomId)).value;
  if (room == null || !room.isMeetup) return null;
  final answers = ref.watch(groupAttendanceProvider(chatRoomId)).value ?? const <GroupAttendance>[];
  return AttendanceSummary.of(room.participantIds, answers, myAccountId: accountId);
});

/// 精算の全員の額と払った記録（引数はチャットルームID。主催チームだけ読める。機能仕様書4.7.8.12）。読めないときは空
final settlementSharesProvider = StreamProvider.autoDispose.family<List<SettlementShare>, String>((ref, chatRoomId) {
  return ref.watch(groupRepositoryProvider).watchSettlementShares(chatRoomId);
});

/// 自分の精算の額と払った記録（引数は(自分のアカウントID, チャットルームID)）。対象でなければnull
final mySettlementShareProvider = StreamProvider.autoDispose.family<SettlementShare?, (String, String)>((ref, key) {
  final (accountId, chatRoomId) = key;
  return ref.watch(groupRepositoryProvider).watchMySettlementShare(accountId: accountId, chatRoomId: chatRoomId);
});
