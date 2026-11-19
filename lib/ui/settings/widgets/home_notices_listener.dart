import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../config/legal_links.dart';
import '../../../config/service_providers.dart';
import '../../../l10n/app_localizations.dart';
import '../../../utils/external_link.dart';
import '../../auth/view_models/auth_providers.dart';
import '../../core/ui/app_snack_bar.dart';

// ============================================================
// Provider
// ============================================================

/// ログイン中のユーザの、引き継ぎパスワードの再設定の申請（`users/{uid}.transferResetAt`）
/// 申請が無い・未ログインならnull
final transferResetAtProvider = StreamProvider<DateTime?>((ref) async* {
  final user = ref.watch(authStateChangesProvider).value;
  if (user == null) {
    yield null;
    return;
  }
  yield* ref.watch(userRepositoryProvider).watchTransferResetAt(user.uid);
});

/// 削除の日時の表示（例：11月29日 14:05）
String formatResetAt(BuildContext context, DateTime resetAt) {
  final languageCode = Localizations.localeOf(context).languageCode;
  return DateFormat.MMMd(languageCode).add_Hm().format(resetAt.toLocal());
}

// ============================================================
// 画面
// ============================================================

/// ホームを包み、次の2つを出す
/// - 利用規約とプライバシーポリシーの改定の再同意：[LegalLinks.documentVersion]以降の版に同意して
///   いなければ、ホームを開いたときに1回出す。「同意する」まで閉じない（改定は規約第16条で適用されるため、同意の
///   記録を残すための案内）
/// - 引き継ぎパスワードの再設定の申請の警告：この電話番号のデータの削除が申請されていれば、日時ごとに
///   1回出し、取り消せるようにする（電話番号が別の人に渡った場合に、前の持ち主が気づけるように）
class HomeNoticesListener extends ConsumerStatefulWidget {
  const HomeNoticesListener({super.key, required this.child});

  /// 包む画面
  final Widget child;

  @override
  ConsumerState<HomeNoticesListener> createState() => _HomeNoticesListenerState();
}

class _HomeNoticesListenerState extends ConsumerState<HomeNoticesListener> {
  /// 警告を出した申請の日時（同じ申請で2回出さない）
  DateTime? _alertedResetAt;

  /// ダイアログを出している間は、次のダイアログを出さない
  bool _showingDialog = false;

  @override
  void initState() {
    super.initState();
    ref.listenManual(transferResetAtProvider, (_, next) {
      final resetAt = next.value;
      if (resetAt != null && resetAt != _alertedResetAt) _showResetAlert(resetAt);
    }, fireImmediately: true);
    // 画面の構築中にダイアログを出さないよう、描画の後に行う。
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkLegalConsent());
  }

  /// 今の版に同意していなければ、再同意のダイアログを出す
  /// 確認できなかった場合は出さない（次の起動で確かめ直す）
  Future<void> _checkLegalConsent() async {
    final uid = ref.read(authRepositoryProvider).currentUser?.uid;
    if (uid == null) return;
    final bool consented;
    try {
      consented = await ref.read(userRepositoryProvider).hasLegalConsentSince(uid, LegalLinks.documentVersion);
    } catch (e) {
      debugPrint('[HomeNotices] hasLegalConsentSince failed: $e');
      return;
    }
    if (consented || !mounted) return;
    await _showLegalUpdate();
  }

  /// 再同意のダイアログを、同意を記録できるまで出す
  /// 利用規約・プライバシーポリシーを開いた後も、もう一度出す
  Future<void> _showLegalUpdate() async {
    while (true) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      final languageCode = Localizations.localeOf(context).languageCode;
      _showingDialog = true;
      final choice = await showCupertinoDialog<String>(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: Text(l10n.legalUpdateTitle),
          content: Text(l10n.legalUpdateMessage),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(context).pop('terms'),
              child: Text(l10n.setTermsOfServiceTile),
            ),
            CupertinoDialogAction(
              onPressed: () => Navigator.of(context).pop('privacy'),
              child: Text(l10n.setPrivacyPolicyTile),
            ),
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () => Navigator.of(context).pop('agree'),
              child: Text(l10n.legalUpdateAgree),
            ),
          ],
        ),
      );
      _showingDialog = false;
      if (!mounted) return;
      switch (choice) {
        case 'terms':
          await openExternalLink(context, Uri.parse(LegalLinks.termsOfServiceUrl(languageCode)));
        case 'privacy':
          await openExternalLink(context, Uri.parse(LegalLinks.privacyPolicyUrl(languageCode)));
        case 'agree':
          try {
            await ref.read(userRepositoryProvider).recordLegalConsent();
            return;
          } catch (e) {
            debugPrint('[HomeNotices] recordLegalConsent failed: $e');
            if (mounted) showAppSnackBar(context, l10n.legalUpdateFailed);
          }
      }
    }
  }

  /// 再設定の申請の警告を出し、「取り消す」なら取り消す
  void _showResetAlert(DateTime resetAt) {
    _alertedResetAt = resetAt;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // 再同意のダイアログを出している間は、閉じてから出す
      while (_showingDialog && mounted) {
        await Future<void>.delayed(const Duration(milliseconds: 300));
      }
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      final cancel = await showCupertinoDialog<bool>(
        context: context,
        builder: (dialogContext) => CupertinoAlertDialog(
          title: Text(l10n.transferResetAlertTitle),
          content: Text(l10n.transferResetAlertMessage(formatResetAt(context, resetAt))),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.transferResetAlertLater),
            ),
            CupertinoDialogAction(
              isDefaultAction: true,
              isDestructiveAction: true,
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(l10n.transferResetAlertCancel),
            ),
          ],
        ),
      );
      if (cancel != true || !mounted) return;
      try {
        await ref.read(authRepositoryProvider).cancelTransferReset();
        if (mounted) showAppSnackBar(context, l10n.transferResetCanceled);
      } catch (e) {
        debugPrint('[HomeNotices] cancelTransferReset failed: $e');
        if (!mounted) return;
        showAppSnackBar(context, l10n.transferResetFailed);
        // 取り消せなかったので、もう一度出せるようにする
        _alertedResetAt = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
