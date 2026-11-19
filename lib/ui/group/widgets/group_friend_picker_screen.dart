import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/service_providers.dart';
import '../../../domain/models/account.dart';
import '../../../domain/models/group.dart';
import '../../../l10n/app_localizations.dart';
import '../../core/themes/app_text_styles.dart';
import '../../core/ui/app_avatar.dart';
import '../../core/ui/app_loading_indicator.dart';
import '../../core/ui/app_screen_app_bar.dart';
import '../../core/ui/app_snack_bar.dart';
import '../../core/view_models/loading_overlay_provider.dart';
import '../../friend/view_models/friend_list_viewmodel.dart';
import '../../friend/view_models/friend_providers.dart';
import 'group_create_screen.dart';
import 'group_failure_message.dart';
import 'group_kind_screen.dart';

// ============================================================
// 関数
// ============================================================

/// グループの作成を始める（GRP-06で種類を選んでからGRP-01へ進む。機能仕様書4.7.1.1）
void openGroupCreation(BuildContext context, {required String myAccountId}) {
  Navigator.of(context).push(MaterialPageRoute(builder: (_) => GroupKindScreen(myAccountId: myAccountId)));
}

// ============================================================
// 状態クラス
// ============================================================

/// 選択の候補の友だち
typedef GroupCandidate = ({String accountId, String name, String? photoURL});

// ============================================================
// 画面
// ============================================================

/// 画面GRP-01：友だち選択（機能仕様書4.7.1.1 / 画面設計書5.10.1）
/// 作成時は0人でも次へ進める（リンク・QRコードだけで招待する場合のため）。[inviteChatRoomId]があれば、参加済みのグループへの招待として開く
class GroupFriendPickerScreen extends ConsumerStatefulWidget {
  const GroupFriendPickerScreen({
    super.key,
    required this.myAccountId,
    this.inviteChatRoomId,
    this.participantIds = const [],
    this.kind = GroupKind.standard,
  });

  final String myAccountId;

  /// 作成するグループの種類（GRP-06で選んだもの。招待時は使わない）
  final GroupKind kind;

  /// 招待先のグループ（作成時はnull）
  final String? inviteChatRoomId;

  /// 招待先のグループの参加者（選択できないよう「参加中」と表示する）
  final List<String> participantIds;

  @override
  ConsumerState<GroupFriendPickerScreen> createState() => _GroupFriendPickerScreenState();
}

class _GroupFriendPickerScreenState extends ConsumerState<GroupFriendPickerScreen> {
  /// 選択中の友だち（選んだ順）
  final _selected = <String, GroupCandidate>{};

  /// 絞り込みの文字列
  String _query = '';

  /// 招待時に選べる人数を超えないか
  bool get _canSelectMore => widget.participantIds.length + _selected.length < groupMaxMembers;

  void _toggle(GroupCandidate candidate) {
    if (!_selected.containsKey(candidate.accountId) && !_canSelectMore) {
      showAppSnackBar(context, AppLocalizations.of(context)!.grpMaxMembers);
      return;
    }
    setState(() {
      if (_selected.remove(candidate.accountId) == null) _selected[candidate.accountId] = candidate;
    });
  }

  /// 選んだ友だちを招待する
  /// 招待した側には結果を分けない（機能仕様書4.7.2.1）。失敗したら選択を残す
  Future<void> _invite(String chatRoomId) async {
    final l10n = AppLocalizations.of(context)!;
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(loadingOverlayProvider.notifier)
          .run(
            () => ref
                .read(groupRepositoryProvider)
                .invite(
                  accountId: widget.myAccountId,
                  chatRoomId: chatRoomId,
                  targetAccountIds: _selected.keys.toList(),
                ),
          );
      messenger.showSnackBar(buildAppSnackBar(l10n.grpInvited));
      navigator.pop();
    } on GroupException catch (error) {
      messenger.showSnackBar(
        buildAppSnackBar(groupFailureMessage(l10n, error.failure, fallback: l10n.grpRequestFailed)),
      );
    }
  }

  /// 友だちのうち、退会済みを除いた候補を作る
  List<GroupCandidate> _candidates(AppLocalizations l10n) {
    final candidates = <GroupCandidate>[];
    for (final friend in ref.watch(friendsProvider).value ?? const []) {
      final peer = ref.watch(friendListPeerProvider(friend.friendAccountId)).value;
      if (peer == null || peer.isDeleted) continue;
      final name = resolveDisplayName(
        peer,
        nickname: friend.nickname,
        unknownAccountLabel: l10n.commonUnknownAccount,
        deletedAccountLabel: l10n.commonDeletedAccount,
      );
      candidates.add((accountId: friend.friendAccountId, name: name, photoURL: peer.visiblePhotoURL));
    }
    return candidates;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final friendsLoaded = ref.watch(friendsProvider).hasValue;
    final query = _query.trim().toLowerCase();
    final candidates = _candidates(l10n).where((candidate) => candidate.name.toLowerCase().contains(query)).toList();

    return Scaffold(
      appBar: AppScreenAppBar(
        title: l10n.grpSelectFriendsTitle,
        actions: [
          if (widget.inviteChatRoomId case final chatRoomId?)
            TextButton(
              onPressed: _selected.isEmpty ? null : () => _invite(chatRoomId),
              child: Text(l10n.grpInviteAction),
            )
          else
            TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => GroupCreateScreen(
                    myAccountId: widget.myAccountId,
                    selected: _selected.values.toList(),
                    kind: widget.kind,
                  ),
                ),
              ),
              child: Text(l10n.grpNext),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: TextField(
                decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: l10n.grpSearchHint),
                onChanged: (value) => setState(() => _query = value),
              ),
            ),
            Expanded(
              child: !friendsLoaded
                  ? const AppLoadingIndicator()
                  : ListView.builder(
                      itemCount: candidates.length,
                      itemBuilder: (context, index) {
                        final candidate = candidates[index];
                        final isParticipant = widget.participantIds.contains(candidate.accountId);
                        return CheckboxListTile(
                          value: isParticipant || _selected.containsKey(candidate.accountId),
                          onChanged: isParticipant ? null : (_) => _toggle(candidate),
                          subtitle: isParticipant ? Text(l10n.grpJoinedLabel) : null,
                          secondary: AppAvatar(displayName: candidate.name, photoURL: candidate.photoURL, size: 40),
                          title: Text(candidate.name, style: context.textStyles.titleMedium),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
