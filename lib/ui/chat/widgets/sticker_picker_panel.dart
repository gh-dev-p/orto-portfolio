import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Icons;

import '../../../domain/models/sticker_pack.dart';
import 'chat_image.dart';

/// 選んだスタンプ
typedef StickerSelection = ({String packId, String stickerId});

/// スタンプの選択パネル（機能仕様書4.4.8）
/// 入力欄の下に、キーボードの代わりに開く
class StickerPickerPanel extends StatelessWidget {
  const StickerPickerPanel({super.key, required this.packs, required this.onSelected});

  final List<StickerPack> packs;
  final ValueChanged<StickerSelection> onSelected;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: GridView.count(
        crossAxisCount: 4,
        padding: const EdgeInsets.all(12),
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        children: [
          for (final pack in packs)
            for (final stickerId in pack.stickerIds)
              CupertinoButton(
                key: Key('sticker-${pack.id}-$stickerId'),
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                onPressed: () => onSelected((packId: pack.id, stickerId: stickerId)),
                child: _StickerThumbnail(packId: pack.id, stickerId: stickerId),
              ),
        ],
      ),
    );
  }
}

class _StickerThumbnail extends StatelessWidget {
  const _StickerThumbnail({required this.packId, required this.stickerId});

  final String packId;
  final String stickerId;

  @override
  Widget build(BuildContext context) {
    final path = StickerPack.storagePath(packId, stickerId);
    if (path == null) return const Icon(Icons.broken_image_outlined);
    return ChatImage(path: path, aspectRatio: 1, fit: BoxFit.contain);
  }
}
