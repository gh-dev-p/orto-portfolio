import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../../../domain/models/account.dart';
import '../../../domain/models/album.dart';
import '../../../l10n/app_localizations.dart';
import '../../../utils/date_format_utils.dart';
import '../../chat_list/view_models/chat_list_viewmodel.dart';
import '../../core/ui/app_snack_bar.dart';
import '../../core/ui/confirm_dialog.dart';
import '../../core/view_models/loading_overlay_provider.dart';
import '../../report/widgets/report_screen.dart';
import '../view_models/album_providers.dart';
import '../view_models/album_viewmodel.dart';
import 'album_detail_screen.dart';
import 'album_thumbnail.dart';

/// 画面ALB-03：アルバムの画像と動画の全画面表示
/// 左右のスワイプで前後の項目へ移る。画像はピンチで拡大し、動画はタップで再生する。保存・削除（自分の項目）・通報（他の人の項目）ができる
///
/// 機能仕様書：4.4.9 / 画面設計書：5.3.6
class AlbumViewerScreen extends ConsumerStatefulWidget {
  const AlbumViewerScreen({
    super.key,
    required this.chatRoomId,
    required this.albumId,
    required this.myAccountId,
    required this.peerAccountId,
    required this.items,
    required this.initialIndex,
  });

  final String chatRoomId;
  final String albumId;
  final String myAccountId;
  final String? peerAccountId;
  final List<AlbumItem> items;
  final int initialIndex;

  @override
  ConsumerState<AlbumViewerScreen> createState() => _AlbumViewerScreenState();
}

class _AlbumViewerScreenState extends ConsumerState<AlbumViewerScreen> {
  late final _pageController = PageController(initialPage: widget.initialIndex);
  late final _items = [...widget.items];
  late var _index = widget.initialIndex;

  /// 画像を拡大している間は、ドラッグを移動に使うためページを送らない
  var _zoomed = false;

  AlbumKey get _key => (chatRoomId: widget.chatRoomId, albumId: widget.albumId);

  AlbumViewModel get _viewModel => ref.read(albumViewModelProvider(_key).notifier);

  AlbumItem get _current => _items[_index];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  String _uploaderName(AlbumItem item) {
    final l10n = AppLocalizations.of(context)!;
    if (item.uploaderAccountId == widget.myAccountId) return l10n.chaImageMine;
    final uploader = ref.watch(chatListPeerProvider(item.uploaderAccountId));
    return resolveDisplayName(
      uploader.account.value,
      nickname: uploader.nickname,
      unknownAccountLabel: l10n.commonUnknownAccount,
      deletedAccountLabel: l10n.commonDeletedAccount,
    );
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context)!;
    final item = _current;
    if (!await _viewModel.ensureAccess()) {
      if (mounted) showAppSnackBar(context, l10n.chaImageSaveDenied);
      return;
    }
    final result = await ref.read(loadingOverlayProvider.notifier).run(() => _viewModel.saveItems([item]));
    if (mounted) showAppSnackBar(context, albumSaveResultMessage(l10n, result));
  }

  Future<void> _delete() async {
    final l10n = AppLocalizations.of(context)!;
    final item = _current;
    final confirmed = await showConfirmDialog(
      context,
      title: l10n.albDeleteItemsTitle,
      message: l10n.albDeleteItemsMessage(1),
      confirmLabel: l10n.albDeleteConfirm,
    );
    if (!confirmed || !mounted) return;
    try {
      await ref.read(loadingOverlayProvider.notifier).run(() => _viewModel.deleteItems([item]));
    } catch (_) {
      if (mounted) showAppSnackBar(context, l10n.albUpdateFailed);
      return;
    }
    if (!mounted) return;
    if (_items.length == 1) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _items.removeAt(_index);
      if (_index >= _items.length) _index = _items.length - 1;
    });
  }

  Future<void> _report() {
    return openReport(context, (
      myAccountId: widget.myAccountId,
      targetAccountId: _current.uploaderAccountId,
      messageId: null,
      chatRoomId: widget.chatRoomId,
      albumId: widget.albumId,
      albumItemId: _current.itemId,
    ));
  }

  @override
  Widget build(BuildContext context) {
    // 保存の途中でViewModelが破棄されないよう、画面を開いている間は監視しておく。
    ref.watch(albumViewModelProvider(_key));
    final l10n = AppLocalizations.of(context)!;
    final item = _current;
    final createdAt = item.createdAt;
    final isMine = item.uploaderAccountId == widget.myAccountId;
    // 閉じたオフ会グループは読むだけ（自分の項目も消さない。他の人の項目の通報はできる。機能仕様書4.4.9.5）
    final closed = ref.watch(albumClosedRoomProvider(widget.chatRoomId)) != null;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            Row(
              children: [
                CupertinoButton(
                  padding: const EdgeInsets.all(12),
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Icon(CupertinoIcons.xmark, color: Colors.white),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_uploaderName(item), style: const TextStyle(color: Colors.white, fontSize: 14)),
                      if (createdAt != null)
                        Text(
                          '${formatDateDividerLabel(createdAt, l10n.localeName)} ${formatMessageTime(createdAt, l10n.localeName)}',
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                    ],
                  ),
                ),
                CupertinoButton(
                  key: const Key('album-viewer-save'),
                  padding: const EdgeInsets.all(12),
                  onPressed: _save,
                  child: const Icon(CupertinoIcons.arrow_down_to_line, color: Colors.white),
                ),
                if (!(isMine && closed))
                  CupertinoButton(
                    key: Key(isMine ? 'album-viewer-delete' : 'album-viewer-report'),
                    padding: const EdgeInsets.all(12),
                    onPressed: isMine ? _delete : _report,
                    child: Icon(isMine ? CupertinoIcons.trash : CupertinoIcons.flag, color: Colors.white),
                  ),
              ],
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                physics: _zoomed ? const NeverScrollableScrollPhysics() : null,
                itemCount: _items.length,
                onPageChanged: (index) => setState(() {
                  _index = index;
                  _zoomed = false;
                }),
                itemBuilder: (context, index) {
                  final page = _items[index];
                  return page.isVideo
                      ? _VideoPage(key: ValueKey(page.itemId), item: page)
                      : _ImagePage(
                          key: ValueKey(page.itemId),
                          item: page,
                          onZoomChanged: (zoomed) {
                            if (zoomed != _zoomed) setState(() => _zoomed = zoomed);
                          },
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

class _ImagePage extends ConsumerStatefulWidget {
  const _ImagePage({super.key, required this.item, required this.onZoomChanged});

  final AlbumItem item;
  final ValueChanged<bool> onZoomChanged;

  @override
  ConsumerState<_ImagePage> createState() => _ImagePageState();
}

class _ImagePageState extends ConsumerState<_ImagePage> {
  final _transformation = TransformationController();

  @override
  void dispose() {
    _transformation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final url = ref.watch(albumMediaUrlProvider(widget.item.path));
    return InteractiveViewer(
      transformationController: _transformation,
      maxScale: 4,
      onInteractionEnd: (_) => widget.onZoomChanged(_transformation.value.getMaxScaleOnAxis() > 1.01),
      child: Center(
        child: AspectRatio(
          aspectRatio: widget.item.aspectRatio,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 本体が届くまでは、サムネイルを見せる。
              AlbumThumbnail(path: widget.item.thumbnailPath),
              if (url.value case final url?) Image.network(url, fit: BoxFit.contain),
            ],
          ),
        ),
      ),
    );
  }
}

/// 動画の1ページ
/// 開いただけでは通信しない。再生ボタンを押したら読み込んで再生する（通信量を抑えるため）
class _VideoPage extends ConsumerStatefulWidget {
  const _VideoPage({super.key, required this.item});

  final AlbumItem item;

  @override
  ConsumerState<_VideoPage> createState() => _VideoPageState();
}

class _VideoPageState extends ConsumerState<_VideoPage> {
  VideoPlayerController? _controller;
  var _loading = false;
  var _failed = false;

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    VideoPlayerController? controller;
    try {
      final url = await ref.read(albumMediaUrlProvider(widget.item.path).future);
      controller = VideoPlayerController.networkUrl(Uri.parse(url));
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      await controller.play();
      setState(() {
        _controller = controller;
        _loading = false;
      });
    } catch (_) {
      await controller?.dispose();
      if (mounted) {
        setState(() {
          _loading = false;
          _failed = true;
        });
      }
    }
  }

  void _togglePlay(VideoPlayerController controller) {
    setState(() => controller.value.isPlaying ? controller.pause() : controller.play());
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller != null) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _togglePlay(controller),
        child: Stack(
          alignment: Alignment.center,
          children: [
            AspectRatio(aspectRatio: controller.value.aspectRatio, child: VideoPlayer(controller)),
            ValueListenableBuilder(
              valueListenable: controller,
              builder: (context, value, _) => value.isPlaying ? const SizedBox.shrink() : const _PlayIcon(),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 12,
              child: VideoProgressIndicator(
                controller,
                allowScrubbing: true,
                colors: const VideoProgressColors(
                  playedColor: Colors.white,
                  bufferedColor: Colors.white38,
                  backgroundColor: Colors.white12,
                ),
              ),
            ),
          ],
        ),
      );
    }
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _loading ? null : _start,
      child: Center(
        child: AspectRatio(
          aspectRatio: widget.item.aspectRatio,
          child: Stack(
            fit: StackFit.expand,
            children: [
              AlbumThumbnail(path: widget.item.thumbnailPath),
              Center(
                child: _loading
                    ? const CupertinoActivityIndicator(color: Colors.white, radius: 16)
                    : _failed
                    ? Text(
                        AppLocalizations.of(context)!.albVideoLoadFailed,
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                      )
                    : const _PlayIcon(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlayIcon extends StatelessWidget {
  const _PlayIcon();

  @override
  Widget build(BuildContext context) {
    return const Icon(CupertinoIcons.play_circle_fill, size: 64, color: Colors.white70);
  }
}
