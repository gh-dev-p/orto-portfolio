import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/themes/app_colors.dart';
import '../../core/themes/app_text_styles.dart';
import '../../core/ui/app_avatar.dart';
import '../../core/ui/app_loading_indicator.dart';
import '../../core/ui/app_screen_app_bar.dart';
import '../../core/ui/app_snack_bar.dart';
import '../../core/ui/confirm_dialog.dart';
import '../../core/ui/empty_state_view.dart';
import '../../core/ui/error_retry_view.dart';
import '../../../l10n/app_localizations.dart';
import '../../../domain/models/account.dart';
import '../../../domain/models/blocked_account.dart';
import '../view_models/block_list_viewmodel.dart';

// ============================================================
// 画面
// ============================================================

/// 画面SET-02：ブロックリスト
/// ブロックした相手の一覧を表示し、ブロックを解除する（解除後は自動で一覧から消える）
///
/// 画面設計書：5.6.2
class BlockListScreen extends ConsumerWidget {
  const BlockListScreen({super.key});

  /// ブロックした相手の一覧を描く
  /// 読み込み中・読み込みの失敗（再試行つき）・0人のときの表示も出す
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final blockedAsync = ref.watch(blockListViewModelProvider).blocked;

    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppScreenAppBar(title: l10n.setBlockListTitle),
      body: blockedAsync.when(
        data: (blocked) {
          if (blocked.isEmpty) {
            return EmptyStateView(message: l10n.setBlockListEmpty);
          }
          return ListView.builder(
            itemCount: blocked.length,
            itemBuilder: (context, index) => _BlockedAccountTile(blocked: blocked[index]),
          );
        },
        loading: () => const AppLoadingIndicator(),
        error: (_, _) =>
            ErrorRetryView(message: l10n.setBlockListLoadError, onRetry: ref.read(blockListViewModelProvider.notifier).retry),
      ),
    );
  }
}

// ============================================================
// 部品
// ============================================================

/// ブロックした相手1人分の行
/// アバター・表示名と「ブロック解除」ボタンを並べる
class _BlockedAccountTile extends ConsumerWidget {
  const _BlockedAccountTile({required this.blocked});

  /// ブロックした相手
  final BlockedAccount blocked;

  /// 確認ダイアログの後、ブロックを解除する
  /// 失敗したらSnackBarで知らせる
  Future<void> _unblock(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;

    final confirmed = await showConfirmDialog(
      context,
      title: l10n.setBlockListUnblockConfirmTitle,
      message: l10n.setBlockListUnblockConfirmMessage,
      confirmLabel: l10n.setBlockListUnblockButton,
    );
    if (!confirmed) return;

    final ok = await ref.read(blockListViewModelProvider.notifier).unblock(blocked.blockedAccountId);
    if (!ok && context.mounted) showAppSnackBar(context, l10n.setBlockListUnblockFailed);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final account = ref.watch(blockListPeerProvider(blocked.blockedAccountId)).value;
    // 削除済み（退会済み）アカウントは「退会済みアカウント」と表示する。取得前・取得失敗時は
    // 不明なアカウントとして扱う（ブロックの解除自体はaccountIdだけで行える）。
    final name = resolveDisplayName(
      account,
      unknownAccountLabel: l10n.commonUnknownAccount,
      deletedAccountLabel: l10n.commonDeletedAccount,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          AppAvatar(displayName: name, photoURL: account?.visiblePhotoURL, size: 48),
          const SizedBox(width: 16),
          Expanded(
            child: Text(name, style: context.textStyles.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(width: 16),
          OutlinedButton(onPressed: () => _unblock(context, ref), child: Text(l10n.setBlockListUnblockButton)),
        ],
      ),
    );
  }
}
