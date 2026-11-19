import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/themes/app_colors.dart';
import '../view_models/album_providers.dart';

/// アルバムのサムネイル
/// 端末のキャッシュから表示する。[path]がnull（項目が無いアルバム）か、読めなければアイコンを出す
class AlbumThumbnail extends ConsumerWidget {
  const AlbumThumbnail({super.key, required this.path});

  final String? path;

  /// 表示の大きさに対して十分な、デコードの幅（メモリの節約のため）
  static const _cacheWidth = 480;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final path = this.path;
    final file = path == null ? null : ref.watch(albumThumbnailFileProvider(path));
    return ColoredBox(
      color: context.colors.secondaryText.withValues(alpha: 0.15),
      child: file?.value == null
          ? (file == null || file.hasError
                ? Center(child: Icon(Icons.photo_outlined, color: context.colors.secondaryText))
                : const SizedBox.expand())
          : Image.file(
              file!.value!,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              cacheWidth: _cacheWidth,
              errorBuilder: (_, _, _) => Center(child: Icon(Icons.photo_outlined, color: context.colors.secondaryText)),
            ),
    );
  }
}
