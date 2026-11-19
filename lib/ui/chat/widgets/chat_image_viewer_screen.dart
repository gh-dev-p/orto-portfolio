import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../utils/date_format_utils.dart';
import '../../core/ui/app_snack_bar.dart';
import '../../../l10n/app_localizations.dart';
import '../../core/view_models/loading_overlay_provider.dart';
import '../../../domain/models/image_save_result.dart';
import '../view_models/chat_image_viewer_viewmodel.dart';
import 'chat_image.dart';

/// 画面CHA-03：トークの画像の全画面表示
/// ピンチ・ダブルタップで拡大し、拡大していないときは下へのスワイプで閉じる。保存ボタンで端末のアルバムに保存する（自分・相手どちらの画像も保存できる）
///
/// 画面設計書：5.3.3
class ChatImageViewerScreen extends ConsumerStatefulWidget {
  const ChatImageViewerScreen({
    super.key,
    required this.path,
    required this.aspectRatio,
    required this.senderName,
    required this.createdAt,
  });

  final String path;
  final double aspectRatio;
  final String senderName;
  final DateTime? createdAt;

  @override
  ConsumerState<ChatImageViewerScreen> createState() => _ChatImageViewerScreenState();
}

class _ChatImageViewerScreenState extends ConsumerState<ChatImageViewerScreen> {
  static const _doubleTapScale = 2.5;

  final _transformation = TransformationController();
  TapDownDetails? _doubleTapDetails;
  double _dragOffset = 0;

  bool get _zoomed => _transformation.value.getMaxScaleOnAxis() > 1.01;

  @override
  void dispose() {
    _transformation.dispose();
    super.dispose();
  }

  void _toggleZoom() {
    if (_zoomed) {
      _transformation.value = Matrix4.identity();
      return;
    }
    final position = _doubleTapDetails?.localPosition ?? Offset.zero;
    _transformation.value = Matrix4.identity()
      ..translateByDouble(-position.dx * (_doubleTapScale - 1), -position.dy * (_doubleTapScale - 1), 0, 1)
      ..scaleByDouble(_doubleTapScale, _doubleTapScale, 1, 1);
  }

  /// 画像を端末のアルバムに保存する
  /// 「保存」のタップ時に呼ぶ（許可を確かめてから、ローディングを表示しながら保存し、結果をSnackBarで知らせる）
  Future<void> _save() async {
    final l10n = AppLocalizations.of(context)!;
    final viewModel = ref.read(chatImageViewerViewModelProvider(widget.path).notifier);
    if (!await viewModel.ensureAccess()) {
      if (mounted) showAppSnackBar(context, l10n.chaImageSaveDenied);
      return;
    }
    final result = await ref.read(loadingOverlayProvider.notifier).run(viewModel.save);
    if (!mounted) return;
    showAppSnackBar(context, switch (result) {
      ImageSaveResult.saved => l10n.chaImageSaved,
      ImageSaveResult.denied => l10n.chaImageSaveDenied,
      ImageSaveResult.failed => l10n.chaImageSaveFailed,
    });
  }

  @override
  Widget build(BuildContext context) {
    // 保存の途中でViewModelが破棄されないよう、画面を開いている間は監視しておく。
    ref.watch(chatImageViewerViewModelProvider(widget.path));
    final l10n = AppLocalizations.of(context)!;
    final createdAt = widget.createdAt;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  tooltip: l10n.commonClose,
                  onPressed: () => Navigator.of(context).pop(),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.senderName, style: const TextStyle(color: Colors.white, fontSize: 14)),
                      if (createdAt != null)
                        Text(
                          '${formatDateDividerLabel(createdAt, l10n.localeName)} ${formatMessageTime(createdAt, l10n.localeName)}',
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.download_outlined, color: Colors.white),
                  tooltip: l10n.chaImageSaveTooltip,
                  onPressed: _save,
                ),
              ],
            ),
            Expanded(
              child: GestureDetector(
                onDoubleTapDown: (details) => _doubleTapDetails = details,
                onDoubleTap: _toggleZoom,
                // 拡大していないときだけ、下へのスワイプで閉じる（拡大中のドラッグは移動に使う）。
                onVerticalDragUpdate: (details) {
                  if (_zoomed) return;
                  setState(() => _dragOffset = (_dragOffset + details.delta.dy).clamp(0, double.infinity));
                },
                onVerticalDragEnd: (details) {
                  if (_zoomed) return;
                  if (_dragOffset > 120 || (details.primaryVelocity ?? 0) > 800) {
                    Navigator.of(context).pop();
                  } else {
                    setState(() => _dragOffset = 0);
                  }
                },
                child: Transform.translate(
                  offset: Offset(0, _dragOffset),
                  child: InteractiveViewer(
                    transformationController: _transformation,
                    maxScale: 4,
                    child: Center(
                      child: ChatImage(path: widget.path, aspectRatio: widget.aspectRatio, fit: BoxFit.contain),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
