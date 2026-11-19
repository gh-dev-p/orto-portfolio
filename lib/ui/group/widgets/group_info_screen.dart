import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../album/widgets/album_list_screen.dart';
import '../../../config/service_providers.dart';
import '../../../domain/models/group.dart';
import '../../../l10n/app_localizations.dart';
import '../../../utils/image_pick.dart';
import '../../chat_list/view_models/chat_list_viewmodel.dart';
import '../../core/themes/app_colors.dart';
import '../../core/themes/app_text_styles.dart';
import '../../core/ui/app_avatar.dart';
import '../../core/ui/app_loading_indicator.dart';
import '../../core/ui/app_screen_app_bar.dart';
import '../../core/ui/app_snack_bar.dart';
import '../../core/ui/confirm_dialog.dart';
import '../../core/ui/error_retry_view.dart';
import '../../core/ui/text_edit_sheet.dart';
import '../../core/ui/unread_badge.dart';
import '../../core/view_models/loading_overlay_provider.dart';
import '../../auth/view_models/auth_providers.dart';
import '../../notification/view_models/push_notification_init.dart';
import '../../profile/widgets/friend_profile_screen.dart';
import '../../report/widgets/report_screen.dart';
import '../view_models/group_create_viewmodel.dart';
import '../view_models/group_providers.dart';
import 'group_failure_message.dart';
import 'group_invite_sheet.dart';
import 'group_message_row.dart';
import 'group_system_text.dart';
import 'capacity_dialog.dart';
import 'join_questions_screen.dart';
import 'join_requests_screen.dart';
import 'meetup_badge.dart';
import 'next_round_screen.dart';

// ============================================================
// 画面
// ============================================================

/// 画面GRP-03：グループ情報（機能仕様書4.7.4〜4.7.6・4.7.8 / 画面設計書5.10.3）
/// 普通のグループは全員が同じ権限で、情報の変更・他の参加者の退会ができる。
/// オフ会グループは、退会させる・主催チームに入れる・外すを主催チームだけができる。トークを閉じる処理はCHA-02が行う
class GroupInfoScreen extends ConsumerWidget {
  const GroupInfoScreen({super.key, required this.chatRoomId, required this.myAccountId});

  final String chatRoomId;
  final String myAccountId;

  /// [action]をローディング表示つきで実行する。失敗したらSnackBarで知らせ、falseを返す
  Future<bool> _run(BuildContext context, WidgetRef ref, Future<void> Function() action) async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(loadingOverlayProvider.notifier).run(action);
      return true;
    } on GroupException catch (error) {
      messenger.showSnackBar(
        buildAppSnackBar(groupFailureMessage(l10n, error.failure, fallback: l10n.grpRequestFailed)),
      );
    } catch (_) {
      messenger.showSnackBar(buildAppSnackBar(l10n.grpRequestFailed));
    }
    return false;
  }

  Future<void> _editName(BuildContext context, WidgetRef ref, String current) async {
    final l10n = AppLocalizations.of(context)!;
    final name = await showTextEditSheet(
      context,
      title: l10n.grpNameLabel,
      initialValue: current,
      minLength: 1,
      maxLength: groupNameMaxLength,
      hintText: l10n.grpNameHint,
    );
    if (name == null || name == current || !context.mounted) return;
    await _run(
      context,
      ref,
      () => ref.read(groupRepositoryProvider).updateName(accountId: myAccountId, chatRoomId: chatRoomId, name: name),
    );
  }

  Future<void> _editPhoto(BuildContext context, WidgetRef ref) async {
    final source = await showImageSourceSheet(context);
    if (source == null || !context.mounted) return;
    final picked = await pickImageForUpload(context, source, maxWidth: 1080, imageQuality: 85);
    if (picked == null || !context.mounted) return;
    await _run(
      context,
      ref,
      () => ref
          .read(groupRepositoryProvider)
          .updatePhoto(accountId: myAccountId, chatRoomId: chatRoomId, file: File(picked.path)),
    );
  }

  Future<void> _setMuted(BuildContext context, WidgetRef ref, {required bool muted}) async {
    final uid = ref.read(authStateChangesProvider).value?.uid;
    if (uid == null) return;
    await _run(
      context,
      ref,
      () => ref
          .read(notificationRepositoryProvider)
          .setGroupMuted(uid: uid, accountId: myAccountId, chatRoomId: chatRoomId, muted: muted),
    );
  }

  Future<void> _leave(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    final navigator = Navigator.of(context);
    final confirmed = await showConfirmDialog(
      context,
      title: l10n.grpLeaveConfirmTitle,
      message: l10n.grpLeaveConfirmMessage,
      confirmLabel: l10n.grpLeaveAction,
    );
    if (!confirmed || !context.mounted) return;
    final ok = await _run(
      context,
      ref,
      () => ref.read(groupRepositoryProvider).leave(accountId: myAccountId, chatRoomId: chatRoomId),
    );
    if (ok) navigator.popUntil((route) => route.isFirst);
  }

  Future<void> _removeMember(BuildContext context, WidgetRef ref, String targetAccountId, String name) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showConfirmDialog(
      context,
      title: l10n.grpRemoveMember,
      message: l10n.grpRemoveConfirmMessage(name),
      confirmLabel: l10n.grpRemoveMember,
    );
    if (!confirmed || !context.mounted) return;
    final ok = await _run(
      context,
      ref,
      () => ref
          .read(groupRepositoryProvider)
          .removeMember(accountId: myAccountId, chatRoomId: chatRoomId, targetAccountId: targetAccountId),
    );
    if (ok) ref.invalidate(groupMembersProvider(chatRoomId));
  }

  /// 主催チームに誘う（相手が承諾したら入る。機能仕様書4.7.8.2）
  Future<void> _inviteToOrganizers(BuildContext context, WidgetRef ref, String targetAccountId) async {
    final ok = await _run(
      context,
      ref,
      () => ref
          .read(groupRepositoryProvider)
          .inviteToOrganizers(accountId: myAccountId, chatRoomId: chatRoomId, targetAccountId: targetAccountId),
    );
    if (ok) ref.invalidate(groupMembersProvider(chatRoomId));
  }

  /// 主催チームから外す。[targetAccountId]が自分なら、主催チームから抜ける
  Future<void> _removeFromOrganizers(BuildContext context, WidgetRef ref, String targetAccountId, String name) async {
    final l10n = AppLocalizations.of(context)!;
    final isMe = targetAccountId == myAccountId;
    final confirmed = await showConfirmDialog(
      context,
      title: isMe ? l10n.grpLeaveOrganizers : l10n.grpRemoveFromOrganizers,
      message: isMe ? l10n.grpLeaveOrganizersConfirm : l10n.grpRemoveFromOrganizersConfirm(groupPersonName(l10n, name)),
      confirmLabel: isMe ? l10n.grpLeaveOrganizers : l10n.grpRemoveFromOrganizers,
    );
    if (!confirmed || !context.mounted) return;
    await _run(
      context,
      ref,
      () => ref
          .read(groupRepositoryProvider)
          .removeFromOrganizers(accountId: myAccountId, chatRoomId: chatRoomId, targetAccountId: targetAccountId),
    );
  }

  /// メンバーの行のメニューで選んだ操作を行う
  void _onMemberAction(BuildContext context, WidgetRef ref, GroupMemberAction action, String accountId, String name) {
    switch (action) {
      case GroupMemberAction.inviteToOrganizers:
        _inviteToOrganizers(context, ref, accountId);
      case GroupMemberAction.removeFromOrganizers:
      case GroupMemberAction.leaveOrganizers:
        _removeFromOrganizers(context, ref, accountId, name);
      case GroupMemberAction.remove:
        _removeMember(context, ref, accountId, name);
    }
  }

  /// メンバー一覧（オフ会グループは見出し「主催チーム」「メンバー」で分ける。機能仕様書4.7.8.2）
  Widget _memberList(BuildContext context, WidgetRef ref, List<GroupMember> list, GroupRoom? room) {
    final l10n = AppLocalizations.of(context)!;
    final sections = groupMemberSections(list, room: room, myAccountId: myAccountId);
    Widget tile(GroupMember member) => _MemberTile(
      chatRoomId: chatRoomId,
      accountId: member.accountId,
      myAccountId: myAccountId,
      isOrganizer: room?.isOrganizer(member.accountId) ?? false,
      isInvitedToOrganizers: member.isInvitedToOrganizers,
      // 主催チームの人は、申請の答えがあれば押したときに見られる（機能仕様書4.7.8.5）
      chatRoomIdForAnswers: room != null && room.isOrganizer(myAccountId) ? chatRoomId : null,
      actions: groupMemberActions(
        room: room,
        myAccountId: myAccountId,
        member: member,
        isClosed: room?.isClosedAt(DateTime.now()) ?? false,
      ),
      onAction: (action, name) => _onMemberAction(context, ref, action, member.accountId, name),
    );
    if (room == null || !room.isMeetup) {
      return Column(children: [for (final member in sections.others) tile(member)]);
    }
    Widget heading(String label) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(label, style: context.textStyles.sectionHeader),
      ),
    );
    return Column(
      children: [
        heading(l10n.grpOrganizerTeamHeading),
        for (final member in sections.organizers) tile(member),
        if (sections.others.isNotEmpty) ...[
          heading(l10n.grpMembersHeading),
          for (final member in sections.others) tile(member),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final entry = ref.watch(groupEntryProvider((myAccountId, chatRoomId))).value;
    final members = ref.watch(groupMembersProvider(chatRoomId));
    final room = ref.watch(groupRoomProvider(chatRoomId)).value;
    final settings = ref.watch(accountNotificationSettingsProvider(myAccountId)).value;
    final name = entry?.name ?? '';
    // 閉じたオフ会グループは、読むことと抜けることだけができる（機能仕様書4.7.8.6）
    final now = DateTime.now();
    final closed = (entry?.isClosedAt(now) ?? false) || (room?.isClosedAt(now) ?? false);

    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppScreenAppBar(title: l10n.grpInfoTitle),
      body: SafeArea(
        child: ListView(
          children: [
            const SizedBox(height: 16),
            Center(
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: closed ? null : () => _editPhoto(context, ref),
                child: AppAvatar(displayName: name, photoURL: entry?.photoURL, size: 88),
              ),
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: closed ? null : () => _editName(context, ref, name),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        // 定員があれば「{人数}/{定員}」（機能仕様書4.7.8.10）
                        switch (displayedCapacity(room)) {
                          final capacity? => l10n.capMemberCount(name, entry?.memberCount ?? 0, capacity),
                          null => l10n.grpTitleWithCount(name, entry?.memberCount ?? 0),
                        },
                        textAlign: TextAlign.center,
                        style: context.textStyles.titleMedium,
                      ),
                    ),
                    // オフ会グループは名前の横に印「オフ会」と残り日数（機能仕様書4.7.8.1）
                    if (entry != null && entry.isMeetup) ...[const SizedBox(width: 6), MeetupBadge.forEntry(entry)],
                  ],
                ),
              ),
            ),
            if (!closed)
              ListTile(
                leading: const Icon(Icons.person_add_alt_1_outlined),
                title: Text(l10n.grpInvite),
                onTap: () => showGroupInviteSheet(
                  context,
                  chatRoomId: chatRoomId,
                  myAccountId: myAccountId,
                  participantIds: [for (final member in members.value ?? const <GroupMember>[]) member.accountId],
                ),
              ),
            // 閉じたオフ会グループの主催チームの人は、記録が消えるまで次の回を作れる（機能仕様書4.7.8.13）
            if (room != null && room.canCreateNextRound(myAccountId, now))
              ListTile(
                key: const Key('group-create-next-round'),
                leading: const Icon(Icons.event_repeat_outlined),
                title: Text(l10n.nxtMenu),
                trailing: room.nextChatRoomId == null
                    ? null
                    : Text(l10n.nxtCreatedLabel, style: context.textStyles.captionRegular),
                onTap: () => openNextRound(context, chatRoomId: chatRoomId, myAccountId: myAccountId, name: name),
              ),
            if (ref.watch(albumFeatureEnabledProvider))
              ListTile(
                key: const Key('group-open-albums'),
                leading: const Icon(Icons.photo_library_outlined),
                title: Text(l10n.albListTitle),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        AlbumListScreen(chatRoomId: chatRoomId, myAccountId: myAccountId, peerAccountId: null),
                  ),
                ),
              ),
            // 主催チームの人だけ、参加の申請と参加時の質問（機能仕様書4.7.8.5）
            if (room != null && room.isOrganizer(myAccountId) && !closed) ...[
              ListTile(
                key: const Key('group-open-join-requests'),
                leading: const Icon(Icons.how_to_reg_outlined),
                title: Text(l10n.grpJoinRequestsMenu),
                trailing: _JoinRequestCount(chatRoomId: chatRoomId),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => JoinRequestsScreen(chatRoomId: chatRoomId, myAccountId: myAccountId),
                  ),
                ),
              ),
              ListTile(
                key: const Key('group-open-join-questions'),
                leading: const Icon(Icons.quiz_outlined),
                title: Text(l10n.grpJoinQuestionsMenu),
                trailing: Text(
                  room.joinQuestions.isEmpty
                      ? l10n.grpJoinQuestionsNone
                      : l10n.grpJoinQuestionsCount(room.joinQuestions.length),
                  style: context.textStyles.captionRegular,
                ),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => JoinQuestionsScreen(
                      chatRoomId: chatRoomId,
                      myAccountId: myAccountId,
                      initialQuestions: room.joinQuestions,
                    ),
                  ),
                ),
              ),
              CapacityTile(room: room, myAccountId: myAccountId, memberCount: room.participantIds.length),
            ],
            SwitchListTile.adaptive(
              activeTrackColor: context.colors.accent,
              title: Text(l10n.grpNotifications),
              value: !(settings?.mutedGroupIds.contains(chatRoomId) ?? false),
              onChanged: settings == null ? null : (enabled) => _setMuted(context, ref, muted: !enabled),
            ),
            const Divider(height: 1),
            members.when(
              data: (list) => _memberList(context, ref, list, room),
              loading: () => const Padding(padding: EdgeInsets.all(24), child: AppLoadingIndicator()),
              error: (_, _) => ErrorRetryView(
                message: l10n.grpMembersLoadError,
                onRetry: () => ref.invalidate(groupMembersProvider(chatRoomId)),
              ),
            ),
            const Divider(height: 1),
            ListTile(
              title: Text(l10n.grpReportGroup),
              onTap: () => openReport(context, (
                myAccountId: myAccountId,
                targetAccountId: null,
                messageId: null,
                chatRoomId: chatRoomId,
                albumId: null,
                albumItemId: null,
              )),
            ),
            ListTile(
              title: Text(l10n.grpLeave, style: TextStyle(color: context.colors.error)),
              onTap: () => _leave(context, ref),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// enum・関数
// ============================================================

/// GRP-03のメンバーの行のメニューの操作（機能仕様書4.7.4.2・4.7.8.2）
enum GroupMemberAction { inviteToOrganizers, removeFromOrganizers, leaveOrganizers, remove }

/// [member]の行のメニューに出す操作（画面設計書5.10.3）
/// 普通のグループ：自分以外の行に「退会させる」。オフ会グループ：自分が主催チームのときだけ、
/// ほかの人の行に「主催チームに入れる」（誘い中は出さない）か「主催チームから外す」と「退会させる」、
/// 自分の行に「主催チームから抜ける」。主催チームでない人には出さない。
/// 閉じたオフ会グループ（[isClosed]、機能仕様書4.7.8.6）では何も出さない
List<GroupMemberAction> groupMemberActions({
  required GroupRoom? room,
  required String myAccountId,
  required GroupMember member,
  bool isClosed = false,
}) {
  if (isClosed) return const [];
  final isMe = member.accountId == myAccountId;
  if (room == null || !room.isMeetup) return isMe ? const [] : const [GroupMemberAction.remove];
  if (!room.isOrganizer(myAccountId)) return const [];
  if (isMe) return const [GroupMemberAction.leaveOrganizers];
  return [
    if (room.isOrganizer(member.accountId))
      GroupMemberAction.removeFromOrganizers
    else if (!member.isInvitedToOrganizers)
      GroupMemberAction.inviteToOrganizers,
    GroupMemberAction.remove,
  ];
}

// ============================================================
// 部品
// ============================================================

/// GRP-03の「参加の申請」の右に出す、承認待ちの件数（0件なら出さない）
class _JoinRequestCount extends ConsumerWidget {
  const _JoinRequestCount({required this.chatRoomId});

  final String chatRoomId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requests = ref.watch(groupJoinRequestsProvider(chatRoomId)).value ?? const [];
    final count = requests.where((request) => request.status == JoinStatus.pending).length;
    if (count == 0) return const SizedBox.shrink();
    return UnreadCountBadge(count: count);
  }
}

/// メンバー1人分の行
/// タップでPRO-01、長押し・「…」で[actions]のメニュー（無ければ出さない）。
/// 主催チームの人は名前の横に印「主催」、誘い中の人は「主催に誘い中」（機能仕様書4.7.8.2）
class _MemberTile extends ConsumerWidget {
  const _MemberTile({
    required this.chatRoomId,
    required this.accountId,
    required this.myAccountId,
    required this.isOrganizer,
    required this.isInvitedToOrganizers,
    required this.actions,
    required this.onAction,
    this.chatRoomIdForAnswers,
  });

  /// このグループのチャットルームID（PRO-01で友だち申請に使う）
  final String chatRoomId;
  final String accountId;
  final String myAccountId;
  final bool isOrganizer;
  final bool isInvitedToOrganizers;

  /// 押したときに申請の答えを探すグループ（自分が主催チームのオフ会グループだけ。それ以外はnull）
  final String? chatRoomIdForAnswers;
  final List<GroupMemberAction> actions;
  final void Function(GroupMemberAction action, String name) onAction;

  String _label(AppLocalizations l10n, GroupMemberAction action) => switch (action) {
    GroupMemberAction.inviteToOrganizers => l10n.grpInviteToOrganizers,
    GroupMemberAction.removeFromOrganizers => l10n.grpRemoveFromOrganizers,
    GroupMemberAction.leaveOrganizers => l10n.grpLeaveOrganizers,
    GroupMemberAction.remove => l10n.grpRemoveMember,
  };

  /// 長押しのメニュー。操作が1つならそのまま行う（普通のグループの「退会させる」は今のまま）
  Future<void> _onLongPress(BuildContext context, AppLocalizations l10n, String name) async {
    if (actions.length == 1) return onAction(actions.single, name);
    final action = await showModalBottomSheet<GroupMemberAction>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final action in actions)
              ListTile(title: Text(_label(l10n, action)), onTap: () => Navigator.of(sheetContext).pop(action)),
          ],
        ),
      ),
    );
    if (action != null) onAction(action, name);
  }

  void _openProfile(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        // グループのメンバーからは、友だち追加ではなく友だち申請
        builder: (_) =>
            FriendProfileScreen(accountId: accountId, myAccountId: myAccountId, groupChatRoomId: chatRoomId),
      ),
    );
  }

  /// 主催チームなら申請の答えを探し、あればシートで見せる。無ければ今のままPRO-01（機能仕様書4.7.8.5）
  Future<void> _onTap(BuildContext context, WidgetRef ref, String name, {required bool canOpenProfile}) async {
    final chatRoomId = chatRoomIdForAnswers;
    final answers = chatRoomId == null
        ? const <JoinAnswer>[]
        : await ref
              .read(loadingOverlayProvider.notifier)
              .run(
                () => ref
                    .read(groupRepositoryProvider)
                    .fetchMemberJoinAnswers(chatRoomId: chatRoomId, accountId: accountId),
              );
    if (!context.mounted) return;
    if (answers.isEmpty) {
      if (canOpenProfile) _openProfile(context);
      return;
    }
    await showMemberJoinAnswersSheet(
      context,
      name: name,
      answers: answers,
      onOpenProfile: canOpenProfile ? () => _openProfile(context) : null,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final isMe = accountId == myAccountId;
    final account = ref.watch(chatListPeerProvider(accountId)).account.value;
    final name = groupMemberName(ref, l10n, accountId);
    return ListTile(
      leading: AppAvatar(displayName: name, photoURL: account?.visiblePhotoURL, size: 40),
      title: Row(
        children: [
          Flexible(
            child: Text(
              isMe ? l10n.grpMemberMe(name) : name,
              style: context.textStyles.listItemLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (isOrganizer) ...[const SizedBox(width: 6), GroupLabelChip(label: l10n.grpOrganizerBadge)],
        ],
      ),
      subtitle: !isOrganizer && isInvitedToOrganizers
          ? Text(l10n.grpOrganizerInvitedLabel, style: context.textStyles.captionRegular)
          : null,
      onTap: isMe || account == null
          ? null
          : account.isDeleted
          ? (chatRoomIdForAnswers == null ? null : () => _onTap(context, ref, name, canOpenProfile: false))
          : () => _onTap(context, ref, name, canOpenProfile: true),
      onLongPress: actions.isEmpty ? null : () => _onLongPress(context, l10n, name),
      trailing: actions.isEmpty
          ? null
          : PopupMenuButton<GroupMemberAction>(
              icon: const Icon(Icons.more_horiz),
              onSelected: (action) => onAction(action, name),
              itemBuilder: (_) => [
                for (final action in actions) PopupMenuItem(value: action, child: Text(_label(l10n, action))),
              ],
            ),
    );
  }
}
