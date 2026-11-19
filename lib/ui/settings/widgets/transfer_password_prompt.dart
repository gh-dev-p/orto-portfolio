import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../core/ui/app_snack_bar.dart';
import '../view_models/transfer_password_prompt_provider.dart';
import 'transfer_password_setup_screen.dart';

/// 引き継ぎパスワードの案内を、出す予定ができたら出す（機能仕様書4.1.4.1）
/// ホームを包んで使う。ホームが作られた時点の値でも判定する
class TransferPasswordPromptListener extends ConsumerStatefulWidget {
  const TransferPasswordPromptListener({super.key, required this.child});

  /// 包む画面
  final Widget child;

  @override
  ConsumerState<TransferPasswordPromptListener> createState() => _TransferPasswordPromptListenerState();
}

class _TransferPasswordPromptListenerState extends ConsumerState<TransferPasswordPromptListener> {
  @override
  void initState() {
    super.initState();
    ref.listenManual(transferPasswordPromptProvider, (_, pending) {
      if (pending) _show();
    }, fireImmediately: true);
    // 招待から来て先送りした案内は、次の起動でホームが作られたときに出す。
    // 画面の構築中にProviderを変更しないよう、描画の後に行う。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(transferPasswordPromptProvider.notifier).offerIfDeferred();
    });
  }

  /// 案内を出し、「設定する」が選ばれたらSET-05を開く
  /// 保存できたら、完了をSnackBarで知らせる
  void _show() {
    // 画面の構築中にProviderを変更・画面遷移しないよう、描画の後に行う。
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await ref.read(transferPasswordPromptProvider.notifier).markShown();
      if (!mounted) return;
      final navigator = Navigator.of(context);
      final l10n = AppLocalizations.of(context)!;
      final setUp = await showCupertinoDialog<bool>(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: Text(l10n.transferPasswordPromptTitle),
          content: Text(l10n.transferPasswordPromptMessage),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l10n.transferPasswordPromptLater),
            ),
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(l10n.transferPasswordPromptSetUp),
            ),
          ],
        ),
      );
      if (setUp != true) return;
      final saved = await navigator.push<bool>(
        MaterialPageRoute(builder: (_) => const TransferPasswordSetupScreen()),
      );
      if (saved == true && mounted) showAppSnackBar(context, l10n.transferPasswordSaved);
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
