import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/themes/app_colors.dart';
import '../../../utils/image_pick.dart';
import '../../core/ui/app_snack_bar.dart';
import '../../core/ui/header_icon_button.dart';
import '../../../l10n/app_localizations.dart';
import '../view_models/qr_scan_viewmodel.dart';
import '../../../config/app_flavor.dart';
import '../../../config/invite_links.dart';
import '../../friend/view_models/friend_invite_key_providers.dart';
import '../../group/widgets/group_join_screen.dart';
import '../../profile/widgets/friend_profile_screen.dart';
import 'camera_error_view.dart';
import 'mode_segment.dart';
import 'my_qr_view.dart';
import 'scan_overlay.dart';

// ============================================================
// enum
// ============================================================

/// QRC-01の表示モード
enum QrScreenMode {
  /// 読み取り
  scan,

  /// マイQRコード
  myQr,
}

// ============================================================
// 画面
// ============================================================

/// 画面QRC-01：QRコード
/// 読み取り（カメラ・アルバム）とマイQRコードの表示を、1画面で下部の切り替えで行う（LINE準拠）。どこから開くときも[initialMode]は読み取り
///
/// 機能仕様書：4.3.1 / 画面設計書：5.5.1・5.5.2
class QrScanScreen extends ConsumerStatefulWidget {
  const QrScanScreen({super.key, required this.myAccountId, this.initialMode = QrScreenMode.scan});

  final String myAccountId;

  /// 最初に表示するモード
  /// 今はどこから開くときも読み取り（将来の拡張のため引数にしている）
  final QrScreenMode initialMode;

  @override
  ConsumerState<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends ConsumerState<QrScanScreen> {
  late QrScreenMode _mode = widget.initialMode;
  final _controller = MobileScannerController();
  bool _handled = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _resolveAndNavigate(String rawValue) async {
    if (_handled) return;
    setState(() => _handled = true);
    await _controller.stop();

    // 招待リンク（https）と以前のorto://のQRコードの両方を読む。アプリの中で読んだ招待は、
    // 外部から届いた招待とは扱わず、QRC-01を開いた使用中のアカウントで固定する（基本原則）。
    final invite = InviteLinks.qrInviteFrom(rawValue, currentFlavor);

    // グループの招待のQRコード（機能仕様書4.7.2.5）。内容の確認はGRP-05で行う。
    if (invite is GroupQrInvite) {
      if (!mounted) return;
      final token = invite.token;
      if (token == null) {
        showAppSnackBar(context, AppLocalizations.of(context)!.grpErrorInviteInvalid);
        setState(() => _handled = false);
        if (_mode == QrScreenMode.scan) await _controller.start();
        return;
      }
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => GroupJoinScreen(token: token, myAccountId: widget.myAccountId),
        ),
      );
      return;
    }

    // マイQRコードの招待キー。IDによる友だち追加を許可していない相手も、これがあれば追加できる。
    if (invite is FriendQrInvite && invite.accountId != null && invite.inviteKey != null) {
      ref.read(receivedInviteKeysProvider.notifier).remember(invite.accountId!, invite.inviteKey!);
    }

    final found = await ref
        .read(qrScanViewModelProvider.notifier)
        .resolve(accountId: invite is FriendQrInvite ? invite.accountId : null, myAccountId: widget.myAccountId);

    if (!mounted) return;
    if (found == null) {
      setState(() => _handled = false);
      if (_mode == QrScreenMode.scan) await _controller.start();
      return;
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => FriendProfileScreen(accountId: found.id, myAccountId: widget.myAccountId),
      ),
    );
  }

  Future<void> _handleDetect(BarcodeCapture capture) async {
    final rawValue = capture.barcodes.isEmpty ? null : capture.barcodes.first.rawValue;
    if (rawValue == null || rawValue.isEmpty) return;
    await _resolveAndNavigate(rawValue);
  }

  Future<void> _pickFromAlbum() async {
    if (_handled) return;
    final picked = await pickImageSafely(context, ImageSource.gallery);
    if (picked == null || !mounted || _handled) return;

    BarcodeCapture? capture;
    try {
      capture = await _controller.analyzeImage(picked.path);
    } catch (_) {
      capture = null;
    }
    if (!mounted || _handled) return;

    final rawValue = (capture == null || capture.barcodes.isEmpty) ? null : capture.barcodes.first.rawValue;
    if (rawValue == null || rawValue.isEmpty) {
      showAppSnackBar(context, AppLocalizations.of(context)!.qrcDetectFailed);
      return;
    }
    await _resolveAndNavigate(rawValue);
  }

  void _switchMode(QrScreenMode mode) {
    if (_mode == mode) return;
    setState(() {
      _mode = mode;
      if (mode == QrScreenMode.scan) _handled = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scanState = ref.watch(qrScanViewModelProvider);
    final scanErrorCode = scanState.error;
    final isScan = _mode == QrScreenMode.scan;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: isScan ? Colors.black : context.colors.background,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (isScan)
            MobileScanner(
              controller: _controller,
              onDetect: _handleDetect,
              errorBuilder: (context, error) => CameraErrorView(error: error),
            )
          else
            MyQrView(account: scanState.myAccount),
          if (isScan) const ScanOverlay(),
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: HeaderIconButton(
                  icon: Icons.close,
                  onTap: () => Navigator.of(context).pop(),
                  iconSize: 20,
                  backgroundAlpha: 0.4,
                ),
              ),
            ),
          ),
          if (isScan)
            SafeArea(
              child: Align(
                alignment: Alignment.bottomRight,
                child: Padding(
                  padding: const EdgeInsets.only(right: 16, bottom: 100),
                  child: HeaderIconButton(
                    icon: Icons.photo_library_outlined,
                    onTap: _pickFromAlbum,
                    size: 48,
                    iconSize: 22,
                    backgroundAlpha: 0.4,
                  ),
                ),
              ),
            ),
          if (isScan && scanErrorCode != null)
            Align(
              alignment: const Alignment(0, 0.6),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 32),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  switch (scanErrorCode) {
                    QrScanError.selfAdd => l10n.commonSelfAddNotAllowed,
                    QrScanError.notFound => l10n.qrcScanNotFound,
                  },
                  style: const TextStyle(color: Colors.white),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: ModeSegment(mode: _mode, onChanged: _switchMode),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
