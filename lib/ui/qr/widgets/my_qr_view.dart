import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/themes/app_colors.dart';
import '../../core/themes/app_text_styles.dart';
import '../../core/ui/app_avatar.dart';
import '../../core/ui/app_loading_indicator.dart';
import '../../core/ui/app_snack_bar.dart';
import '../../../l10n/app_localizations.dart';
import '../../../domain/models/account.dart';
import '../../../config/app_flavor.dart';
import '../../../config/invite_links.dart';
import '../../friend/view_models/friend_invite_key_providers.dart';
import 'action_button.dart';
import 'app_qr_code.dart';

// ============================================================
// 部品
// ============================================================

/// QRC-01のマイQRコードの表示
/// 使用中のアカウントのIDだけをQRコードにする（電話番号等は含めない）
class MyQrView extends ConsumerStatefulWidget {
  const MyQrView({super.key, required this.account});

  /// 使用中のアカウント
  /// QRC-01のViewModelから受け取る（取得前はnullで、読み込み中を出す）
  final Account? account;

  @override
  ConsumerState<MyQrView> createState() => _MyQrViewState();
}

class _MyQrViewState extends ConsumerState<MyQrView> {
  final _repaintKey = GlobalKey();
  bool _sharing = false;
  int _retryCount = 0;

  Future<void> _copyId(String id) async {
    final l10n = AppLocalizations.of(context)!;
    await Clipboard.setData(ClipboardData(text: id));
    if (!mounted) return;
    showAppSnackBar(context, l10n.commonIdCopied);
  }

  Future<void> _share() async {
    if (_sharing) return;
    setState(() => _sharing = true);
    try {
      final boundary = _repaintKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) throw StateError('boundary not ready');
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw StateError('failed to encode image');

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile.fromData(byteData.buffer.asUint8List(), mimeType: 'image/png', name: 'qr_code.png')],
        ),
      );
    } catch (_) {
      if (mounted) {
        showAppSnackBar(context, AppLocalizations.of(context)!.qrcShareFailed);
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  /// QRコードの内容：友だちの招待リンク（標準のカメラで読んでも、アプリか案内ページが開く）
  /// 招待キーを入れる（IDによる友だち追加を許可していなくても、このQRコードからは追加できる）
  String _qrData(String accountId, String inviteKey) =>
      InviteLinks.friendQrData(accountId, currentFlavor, inviteKey: inviteKey);

  /// 作り直す（QRコードの生成・招待キーの取得に失敗したとき）
  void _retry(String accountId) {
    ref.invalidate(myFriendInviteKeyProvider(accountId));
    setState(() => _retryCount++);
  }

  /// QRコードを作れなかったときの表示（再試行のボタン付き）
  Widget _errorState(BuildContext context, String accountId) {
    final l10n = AppLocalizations.of(context)!;
    return SizedBox(
      width: 220,
      height: 220,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.qrcGenerateFailed,
              style: context.textStyles.captionRegular.copyWith(color: context.colors.error),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            TextButton(onPressed: () => _retry(accountId), child: Text(l10n.commonRetry)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final account = widget.account;
    final l10n = AppLocalizations.of(context)!;

    return SafeArea(
      child: account == null
          ? const AppLoadingIndicator()
          : Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // アバター
                  AppAvatar(displayName: account.displayName, photoURL: account.photoURL, size: 64),
                  const SizedBox(height: 12),

                  // アカウント名
                  Text(account.displayName, style: context.textStyles.h1),
                  const SizedBox(height: 4),

                  // どのアカウントのQRコードか（送る側は使用中のアカウントで固定し、そのことをはっきり出す）
                  Text(
                    l10n.qrcMyQrAccountNote,
                    key: const Key('my-qr-account-note'),
                    style: context.textStyles.captionRegular,
                    textAlign: TextAlign.center,
                  ),
                  Text(
                    l10n.inviteAccountId(account.id),
                    style: context.textStyles.captionRegular,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 28),

                  // QRコード
                  RepaintBoundary(
                    key: _repaintKey,
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: context.colors.surface,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [BoxShadow(color: context.colors.shadow, blurRadius: 16, offset: Offset(0, 4))],
                      ),
                      // 中央にアプリアイコンを重ねる（AppQrCode。GRP-04と共通）。招待キーを取るまでは読み込み中を出す
                      child: ref
                          .watch(myFriendInviteKeyProvider(account.id))
                          .when(
                            data: (inviteKey) => AppQrCode(
                              key: ValueKey(_retryCount),
                              data: _qrData(account.id, inviteKey),
                              size: 220,
                              errorStateBuilder: (context, error) => _errorState(context, account.id),
                            ),
                            loading: () => const SizedBox(width: 220, height: 220, child: AppLoadingIndicator()),
                            error: (_, _) => _errorState(context, account.id),
                          ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ActionButton(icon: Icons.ios_share, label: l10n.qrcShareButton, onTap: _sharing ? null : _share),
                      const SizedBox(width: 32),
                      ActionButton(
                        icon: Icons.copy_outlined,
                        label: l10n.qrcCopyIdButton,
                        onTap: () => _copyId(account.id),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }
}
