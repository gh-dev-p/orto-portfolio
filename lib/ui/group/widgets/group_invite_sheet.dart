import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../config/app_flavor.dart';
import '../../../config/invite_links.dart';
import '../../../config/service_providers.dart';
import '../../../domain/models/group.dart';
import '../../../l10n/app_localizations.dart';
import '../../account/view_models/account_providers.dart';
import '../../core/themes/app_colors.dart';
import '../../core/themes/app_text_styles.dart';
import '../../core/ui/app_avatar.dart';
import '../../core/ui/app_loading_indicator.dart';
import '../../core/ui/app_snack_bar.dart';
import '../../core/ui/confirm_dialog.dart';
import '../../core/view_models/loading_overlay_provider.dart';
import '../../qr/widgets/app_qr_code.dart';
import '../view_models/group_invite_providers.dart';
import '../view_models/group_providers.dart';
import 'group_failure_message.dart';
import 'group_friend_picker_screen.dart';

// ============================================================
// 関数
// ============================================================

/// GRP-04（グループ招待）を開く
Future<void> showGroupInviteSheet(
  BuildContext context, {
  required String chatRoomId,
  required String myAccountId,
  required List<String> participantIds,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: context.colors.surface,
    builder: (_) => GroupInviteSheet(chatRoomId: chatRoomId, myAccountId: myAccountId, participantIds: participantIds),
  );
}

// ============================================================
// 画面
// ============================================================

/// 画面GRP-04：グループ招待（機能仕様書4.7.2 / 画面設計書5.10.4）
/// 友だち選択・招待リンク・QRコードをまとめる。リンクとQRコードは自己申告の後に表示する
class GroupInviteSheet extends ConsumerStatefulWidget {
  const GroupInviteSheet({
    super.key,
    required this.chatRoomId,
    required this.myAccountId,
    required this.participantIds,
  });

  final String chatRoomId;
  final String myAccountId;
  final List<String> participantIds;

  @override
  ConsumerState<GroupInviteSheet> createState() => _GroupInviteSheetState();
}

class _GroupInviteSheetState extends ConsumerState<GroupInviteSheet> {
  /// QRコードの画像を作るためのキー
  final _qrKey = GlobalKey();

  void _pickFriends() {
    final navigator = Navigator.of(context);
    navigator.pop();
    navigator.push(
      MaterialPageRoute(
        builder: (_) => GroupFriendPickerScreen(
          myAccountId: widget.myAccountId,
          inviteChatRoomId: widget.chatRoomId,
          participantIds: widget.participantIds,
        ),
      ),
    );
  }

  Future<void> _copy(String link) async {
    final l10n = AppLocalizations.of(context)!;
    await Clipboard.setData(ClipboardData(text: link));
    if (mounted) showAppSnackBar(context, l10n.commonCopied);
  }

  /// 共有文に入れるグループ名（機能仕様書4.7.2.3）。読み込み前は空
  String get _groupName => ref.read(groupEntryProvider((widget.myAccountId, widget.chatRoomId))).value?.name ?? '';

  Future<void> _shareLink(String link) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      await SharePlus.instance.share(ShareParams(text: l10n.grpInviteShareMessage(_groupName, link)));
    } catch (_) {
      if (mounted) showAppSnackBar(context, l10n.friInviteShareFailed);
    }
  }

  Future<void> _shareQr() async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final boundary = _qrKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) throw StateError('boundary not ready');
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw StateError('failed to encode image');
      await SharePlus.instance.share(
        ShareParams(
          text: l10n.grpInviteQrShareMessage(_groupName),
          files: [XFile.fromData(byteData.buffer.asUint8List(), mimeType: 'image/png', name: 'group_qr_code.png')],
        ),
      );
    } catch (_) {
      if (mounted) showAppSnackBar(context, l10n.qrcShareFailed);
    }
  }

  Future<void> _reissue() async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showConfirmDialog(
      context,
      title: l10n.grpInviteReissue,
      message: l10n.grpInviteReissueMessage,
      confirmLabel: l10n.grpInviteReissueAction,
    );
    if (!confirmed || !mounted) return;
    try {
      await ref
          .read(loadingOverlayProvider.notifier)
          .run(
            () => ref
                .read(groupRepositoryProvider)
                .reissueInviteToken(accountId: widget.myAccountId, chatRoomId: widget.chatRoomId),
          );
      ref.invalidate(groupInviteTokenProvider((widget.myAccountId, widget.chatRoomId)));
    } on GroupException catch (error) {
      messenger.showSnackBar(
        buildAppSnackBar(groupFailureMessage(l10n, error.failure, fallback: l10n.grpRequestFailed)),
      );
    }
  }

  Widget _linkSection(String token) {
    final l10n = AppLocalizations.of(context)!;
    final link = InviteLinks.forGroup(token, currentFlavor);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Center(
          child: RepaintBoundary(
            key: _qrKey,
            child: ColoredBox(
              color: Colors.white,
              child: AppQrCode(data: InviteLinks.groupQrData(token, currentFlavor), size: 200),
            ),
          ),
        ),
        TextButton(onPressed: _shareQr, child: Text(l10n.grpInviteQrShare)),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton(onPressed: () => _copy(link), child: Text(l10n.grpInviteLinkCopy)),
            TextButton(onPressed: () => _shareLink(link), child: Text(l10n.grpInviteLinkShare)),
          ],
        ),
        TextButton(
          onPressed: _reissue,
          child: Text(l10n.grpInviteReissue, style: TextStyle(color: context.colors.error)),
        ),
        // オフ会グループはリンクから来た人を主催チームが承認する（機能仕様書4.7.8.5）
        Text(
          (ref.watch(groupRoomProvider(widget.chatRoomId)).value?.isMeetup ?? false)
              ? l10n.grpInviteMeetupNote
              : l10n.grpInviteNote,
          textAlign: TextAlign.center,
          style: context.textStyles.captionRegular,
        ),
      ],
    );
  }

  Widget _linkArea() {
    final l10n = AppLocalizations.of(context)!;
    return ref
        .watch(groupInviteTokenProvider((widget.myAccountId, widget.chatRoomId)))
        .when(
          data: _linkSection,
          loading: () => const Padding(padding: EdgeInsets.all(24), child: AppLoadingIndicator()),
          error: (_, _) => Text(l10n.grpRequestFailed, textAlign: TextAlign.center),
        );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // オフ会グループで友だちを選んで招待できるのは主催チームだけ（機能仕様書4.7.8.5）。
    // 読み込み中は出さない（主催チームでない人に一瞬でも出さないため）
    final room = ref.watch(groupRoomProvider(widget.chatRoomId)).value;
    // 共有文のグループ名を、共有の時点で読めるよう監視しておく
    ref.watch(groupEntryProvider((widget.myAccountId, widget.chatRoomId)));
    final canPickFriends = canInviteFriends(room, widget.myAccountId);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _InvitingAccount(myAccountId: widget.myAccountId),
          const SizedBox(height: 8),
          if (canPickFriends) ...[
            ListTile(
              key: const Key('group-invite-friends'),
              leading: const Icon(Icons.group_add_outlined),
              title: Text(l10n.grpInviteFromFriends),
              onTap: _pickFriends,
            ),
            const Divider(height: 1),
          ],
          const SizedBox(height: 16),
          _linkArea(),
        ],
      ),
    );
  }
}

// ============================================================
// 画面の部品
// ============================================================

/// 招待する側のアカウント（どのアカウントとして招待するかをはっきり出す）
class _InvitingAccount extends ConsumerWidget {
  const _InvitingAccount({required this.myAccountId});

  final String myAccountId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(
      accountsProvider.select((async) => async.value?.where((own) => own.id == myAccountId).firstOrNull),
    );
    if (account == null) return const SizedBox.shrink();
    return Row(
      key: const Key('group-invite-as'),
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AppAvatar(displayName: account.displayName, photoURL: account.photoURL, size: 24),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            AppLocalizations.of(context)!.grpInviteAs(account.displayName),
            style: context.textStyles.bodyRegular,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
