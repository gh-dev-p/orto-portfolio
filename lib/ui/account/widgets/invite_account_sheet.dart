import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/account.dart';
import '../../../l10n/app_localizations.dart';
import '../../core/themes/app_colors.dart';
import '../../core/themes/app_text_styles.dart';
import '../../core/ui/app_avatar.dart';
import '../../passcode/view_models/passcode_providers.dart';
import '../view_models/invite_account_choice_provider.dart';

// ============================================================
// 関数
// ============================================================

/// 外部から届いた招待で、使うアカウントを選ぶシートを出す
/// 選んだアカウントのIDを返す。閉じたらnull
Future<String?> showInviteAccountSheet(BuildContext context, {required InviteAccountAsk ask, required bool forGroup}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: context.colors.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    builder: (_) => InviteAccountSheet(ask: ask, forGroup: forGroup),
  );
}

// ============================================================
// 画面
// ============================================================

/// 外部から届いた招待（招待リンク・貼り付け）で、友だち追加・グループ参加に使うアカウントを選ぶシート
/// 自分のアカウントを並べ、タップしたアカウントで進む。読み取り専用のアカウントは選べない
///
/// 一覧は自分の端末にだけ出す。相手には、選んだアカウントだけが見える
class InviteAccountSheet extends ConsumerWidget {
  const InviteAccountSheet({super.key, required this.ask, required this.forGroup});

  /// 並べるアカウントと、最初に選んだ状態にするアカウント
  final InviteAccountAsk ask;

  /// グループへの参加か（falseなら友だち追加）
  final bool forGroup;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
            child: Text(
              forGroup ? l10n.inviteAccountTitleGroup : l10n.inviteAccountTitleFriend,
              style: context.textStyles.titleBold,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(l10n.inviteAccountNote, style: context.textStyles.captionRegular),
          ),
          const SizedBox(height: 8),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              itemCount: ask.accounts.length,
              separatorBuilder: (_, _) => const SizedBox(height: 4),
              itemBuilder: (context, index) {
                final account = ask.accounts[index];
                return _AccountRow(
                  account: account,
                  isCurrent: account.id == ask.initialAccountId,
                  readOnly: ask.readOnlyIds.contains(account.id),
                );
              },
            ),
          ),
          TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l10n.commonCancel)),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ============================================================
// 画面の部品
// ============================================================

/// アカウントの行（アイコン・表示名・アカウントID）
/// 最初に選んだ状態のアカウントは背景色で強調し「使用中」を出す。パスコードを設定したアカウントには鍵マークを出す
class _AccountRow extends ConsumerWidget {
  const _AccountRow({required this.account, required this.isCurrent, required this.readOnly});

  final Account account;
  final bool isCurrent;
  final bool readOnly;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final passcodeEnabled = ref.watch(passcodeEnabledProvider(account.id)).value ?? false;
    return Opacity(
      opacity: readOnly ? 0.5 : 1,
      child: Material(
        color: isCurrent ? context.colors.accent.withValues(alpha: 0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: Key('invite-account-${account.id}'),
          onTap: readOnly ? null : () => Navigator.of(context).pop(account.id),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                AppAvatar(displayName: account.displayName, photoURL: account.photoURL, size: 44),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        account.displayName,
                        style: context.textStyles.titleMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        readOnly ? l10n.inviteAccountReadOnly : l10n.inviteAccountId(account.id),
                        style: context.textStyles.captionRegular,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (isCurrent) ...[
                  const SizedBox(width: 8),
                  Text(l10n.inviteAccountCurrent, style: context.textStyles.captionRegular),
                ],
                if (passcodeEnabled) ...[
                  const SizedBox(width: 8),
                  Icon(Icons.lock_outline, size: 18, color: context.colors.secondaryText),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
