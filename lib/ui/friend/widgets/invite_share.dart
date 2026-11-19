import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../config/app_flavor.dart';
import '../../../config/invite_links.dart';
import '../../account/view_models/account_providers.dart';
import '../../core/themes/app_colors.dart';
import '../../core/themes/app_text_styles.dart';
import '../../core/ui/app_avatar.dart';
import '../../core/ui/app_primary_button.dart';
import '../../core/ui/app_snack_bar.dart';
import '../../core/view_models/loading_overlay_provider.dart';
import '../../../l10n/app_localizations.dart';
import '../view_models/friend_invite_key_providers.dart';

/// FRI-03：招待文（招待リンクと自分のID）を、OSの共有シートで送る
/// AppHomeHeaderの＋メニュー「招待」から呼ぶ
///
/// 送る側は使用中のアカウントで固定する。どのアカウントで招待するかをはっきりさせるため、共有の前に
/// そのアカウント（アイコン・表示名・ID）を出すシートを挟み、「招待文を送る」でOSの共有シートを開く
///
/// 招待リンクをタップすると、アプリを入れていればアプリが開いて友だち追加に進み、入れていなければ案内ページ（ストアへのボタン）が開く
/// アプリが開かない環境（アプリ内ブラウザ等）のため、IDでの検索（4.3.1.1）も案内する。ただし「IDで検索されない」
/// （allowIdSearch=false）のアカウントは検索で見つからないため、検索の案内を付けない
Future<void> shareInvite(BuildContext context, {required String myAccountId}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: context.colors.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    builder: (sheetContext) => InviteShareSheet(
      myAccountId: myAccountId,
      onSend: () async {
        // 招待キーを入れた招待リンクを送る。取れなければ送らずに知らせる。
        final container = ProviderScope.containerOf(sheetContext, listen: false);
        // 分からないときは、見つからない検索を案内しないよう、検索されない側に倒す
        final allowIdSearch =
            container.read(accountsProvider).value?.where((own) => own.id == myAccountId).firstOrNull?.allowIdSearch ??
            false;
        String? inviteKey;
        try {
          inviteKey = await container
              .read(loadingOverlayProvider.notifier)
              .run(() => container.read(myFriendInviteKeyProvider(myAccountId).future));
        } catch (_) {
          inviteKey = null;
        }
        if (sheetContext.mounted) Navigator.of(sheetContext).pop();
        if (!context.mounted) return;
        if (inviteKey == null) {
          showAppSnackBar(context, AppLocalizations.of(context)!.friInviteShareFailed);
          return;
        }
        await _shareInviteText(context, myAccountId: myAccountId, inviteKey: inviteKey, allowIdSearch: allowIdSearch);
      },
    ),
  );
}

/// 招待文（機能仕様書4.3.5.1）。「IDで検索されない」アカウントでは、IDで検索する案内を付けない
String friendInviteMessage(
  AppLocalizations l10n, {
  required String accountId,
  required String link,
  required bool allowIdSearch,
}) {
  return allowIdSearch ? l10n.friInviteMessage(accountId, link) : l10n.friInviteMessageNoSearch(link);
}

/// 招待文をOSの共有シートで送る
Future<void> _shareInviteText(
  BuildContext context, {
  required String myAccountId,
  required String inviteKey,
  required bool allowIdSearch,
}) async {
  final l10n = AppLocalizations.of(context)!;
  final link = InviteLinks.forAccount(myAccountId, currentFlavor, inviteKey: inviteKey);
  final text = friendInviteMessage(l10n, accountId: myAccountId, link: link, allowIdSearch: allowIdSearch);
  try {
    await SharePlus.instance.share(ShareParams(text: text));
  } catch (_) {
    if (context.mounted) showAppSnackBar(context, l10n.friInviteShareFailed);
  }
}

/// 招待に使うアカウントを見せ、招待文を送るシート（FRI-03）
class InviteShareSheet extends ConsumerWidget {
  const InviteShareSheet({super.key, required this.myAccountId, required this.onSend});

  /// 招待に使うアカウント（使用中のアカウント）
  final String myAccountId;

  /// 「招待文を送る」を押した
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final account = ref.watch(
      accountsProvider.select((async) => async.value?.where((own) => own.id == myAccountId).firstOrNull),
    );
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.friInviteAsTitle, textAlign: TextAlign.center, style: context.textStyles.titleBold),
            const SizedBox(height: 16),
            if (account != null) ...[
              Center(
                child: AppAvatar(displayName: account.displayName, photoURL: account.photoURL, size: 64),
              ),
              const SizedBox(height: 8),
              Text(account.displayName, textAlign: TextAlign.center, style: context.textStyles.titleMedium),
            ],
            Text(
              l10n.inviteAccountId(myAccountId),
              textAlign: TextAlign.center,
              style: context.textStyles.captionRegular,
            ),
            const SizedBox(height: 24),
            AppPrimaryButton(label: l10n.friInviteSend, enabled: true, onTap: onSend),
            TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l10n.commonCancel)),
          ],
        ),
      ),
    );
  }
}
