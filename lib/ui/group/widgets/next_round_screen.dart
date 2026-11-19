import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/service_providers.dart';
import '../../../domain/models/group.dart';
import '../../../l10n/app_localizations.dart';
import '../../chat/widgets/chat_screen.dart';
import '../../chat_list/view_models/chat_list_viewmodel.dart';
import '../../core/themes/app_colors.dart';
import '../../core/themes/app_text_styles.dart';
import '../../core/ui/app_avatar.dart';
import '../../core/ui/app_loading_indicator.dart';
import '../../core/ui/app_primary_button.dart';
import '../../core/ui/app_screen_app_bar.dart';
import '../../core/ui/app_snack_bar.dart';
import '../../core/ui/error_retry_view.dart';
import '../../core/view_models/loading_overlay_provider.dart';
import '../view_models/group_create_viewmodel.dart';
import '../view_models/group_providers.dart';
import 'group_failure_message.dart';
import 'group_message_row.dart';
import 'meetup_badge.dart';

// ============================================================
// 画面
// ============================================================

/// 画面GRP-14：次の回を作る（機能仕様書4.7.8.13 / 画面設計書5.10.15）
/// 閉じたオフ会グループの主催チームの人が、設定を引き継いだ次の回を作り、前の回のメンバーに招待を送る。
/// メンバーはそのまま入れず、招待を承諾した人だけが入る
class NextRoundScreen extends ConsumerStatefulWidget {
  const NextRoundScreen({super.key, required this.chatRoomId, required this.myAccountId, required this.initialName});

  /// 前の回（閉じたグループ）のチャットルームID
  final String chatRoomId;
  final String myAccountId;

  /// 前の回のグループ名（名前の入力欄の初期値）
  final String initialName;

  @override
  ConsumerState<NextRoundScreen> createState() => _NextRoundScreenState();
}

class _NextRoundScreenState extends ConsumerState<NextRoundScreen> {
  late final TextEditingController _name = TextEditingController(text: widget.initialName);

  /// 招待しない人（初期値は全員に送る）
  final Set<String> _excluded = {};

  @override
  void initState() {
    super.initState();
    _name.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit(List<String> candidateIds) async {
    final l10n = AppLocalizations.of(context)!;
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final name = _name.text.trim();
    try {
      final chatRoomId = await ref
          .read(loadingOverlayProvider.notifier)
          .run(
            () => ref
                .read(groupRepositoryProvider)
                .createNextRound(
                  accountId: widget.myAccountId,
                  chatRoomId: widget.chatRoomId,
                  name: name,
                  inviteAccountIds: [
                    for (final id in candidateIds)
                      if (!_excluded.contains(id)) id,
                  ],
                ),
          );
      messenger.showSnackBar(buildAppSnackBar(l10n.nxtCreated));
      navigator.popUntil((route) => route.isFirst);
      navigator.push(
        MaterialPageRoute(
          builder: (_) => ChatScreen(chatRoomId: chatRoomId, myAccountId: widget.myAccountId, peerAccountId: null),
        ),
      );
    } on GroupException catch (error) {
      messenger.showSnackBar(buildAppSnackBar(nextRoundFailureMessage(l10n, error.failure)));
    } catch (_) {
      messenger.showSnackBar(buildAppSnackBar(l10n.grpRequestFailed));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final members = ref.watch(groupMembersProvider(widget.chatRoomId));
    final room = ref.watch(groupRoomProvider(widget.chatRoomId)).value;
    final name = _name.text.trim();
    final nameValid = name.isNotEmpty && name.characters.length <= groupNameMaxLength;

    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppScreenAppBar(title: l10n.nxtTitle),
      body: SafeArea(
        child: members.when(
          loading: () => const AppLoadingIndicator(),
          error: (_, _) => ErrorRetryView(
            message: l10n.grpMembersLoadError,
            onRetry: () => ref.invalidate(groupMembersProvider(widget.chatRoomId)),
          ),
          data: (list) {
            final candidates = nextRoundCandidates(list, room: room, myAccountId: widget.myAccountId);
            final selectedCount = candidates.where((id) => !_excluded.contains(id)).length;
            return Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: TextField(
                          key: const Key('next-round-name'),
                          controller: _name,
                          maxLength: groupNameMaxLength,
                          decoration: InputDecoration(labelText: l10n.nxtNameLabel, hintText: l10n.grpNameHint),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                        child: Text(
                          [l10n.nxtDescription, l10n.nxtCarriedNote, l10n.nxtOrganizerNote].join('\n'),
                          style: context.textStyles.captionRegular.copyWith(color: context.colors.secondaryText),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 24, 16, 4),
                        child: Text(l10n.nxtInviteHeading(selectedCount), style: context.textStyles.sectionHeader),
                      ),
                      if (candidates.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(l10n.nxtNoMembers, style: context.textStyles.captionRegular),
                        ),
                      for (final accountId in candidates)
                        _CandidateTile(
                          accountId: accountId,
                          isOrganizer: room?.isOrganizer(accountId) ?? false,
                          selected: !_excluded.contains(accountId),
                          onChanged: (selected) =>
                              setState(() => selected ? _excluded.remove(accountId) : _excluded.add(accountId)),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: AppPrimaryButton(
                    key: const Key('next-round-submit'),
                    label: l10n.nxtSubmit,
                    enabled: nameValid,
                    onTap: () => _submit(candidates),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ============================================================
// 関数
// ============================================================

/// GRP-14を開く（GRP-03の「次の回を作る」、CHA-02の閉じたあとの案内から）
void openNextRound(
  BuildContext context, {
  required String chatRoomId,
  required String myAccountId,
  required String name,
}) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => NextRoundScreen(chatRoomId: chatRoomId, myAccountId: myAccountId, initialName: name),
    ),
  );
}

/// GRP-14で招待の候補にする前の回のメンバー（自分を除く）。主催チームの人を先に並べる
List<String> nextRoundCandidates(List<GroupMember> members, {required GroupRoom? room, required String myAccountId}) {
  final sections = groupMemberSections(members, room: room, myAccountId: myAccountId);
  return [
    for (final member in [...sections.organizers, ...sections.others])
      if (member.accountId != myAccountId) member.accountId,
  ];
}

/// 次の回を作るときの失敗の文言（機能仕様書4.7.8.13の異常系）
String nextRoundFailureMessage(AppLocalizations l10n, GroupFailure failure) => switch (failure) {
  GroupFailure.groupDeleted => l10n.nxtErrorExpired,
  _ => groupFailureMessage(l10n, failure, fallback: l10n.grpRequestFailed),
};

// ============================================================
// 部品
// ============================================================

/// 招待の候補1人分の行（アイコン・表示名・主催チームなら印「主催」・チェック）
class _CandidateTile extends ConsumerWidget {
  const _CandidateTile({
    required this.accountId,
    required this.isOrganizer,
    required this.selected,
    required this.onChanged,
  });

  final String accountId;
  final bool isOrganizer;
  final bool selected;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final account = ref.watch(chatListPeerProvider(accountId)).account.value;
    final name = groupMemberName(ref, l10n, accountId);
    return CheckboxListTile(
      key: Key('next-round-candidate-$accountId'),
      value: selected,
      onChanged: (value) => onChanged(value ?? false),
      activeColor: context.colors.accent,
      secondary: AppAvatar(displayName: name, photoURL: account?.visiblePhotoURL, size: 40),
      title: Row(
        children: [
          Flexible(
            child: Text(name, style: context.textStyles.listItemLabel, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          if (isOrganizer) ...[const SizedBox(width: 6), GroupLabelChip(label: l10n.grpOrganizerBadge)],
        ],
      ),
    );
  }
}
