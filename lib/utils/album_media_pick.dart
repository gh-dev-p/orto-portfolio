import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../config/album_limits.dart';
import '../l10n/app_localizations.dart';
import '../ui/core/ui/app_snack_bar.dart';
import 'image_pick.dart';

/// アルバムに追加する画像と動画を複数選ぶ（機能仕様書4.4.9）。キャンセル時は空。
///
/// 権限拒否などで選択に失敗した場合は、原因に応じたSnackBarを表示して空を返す。[pick]はテスト用の差し替え。
Future<List<File>> pickAlbumMediaSafely(BuildContext context, {Future<List<XFile>> Function()? pick}) async {
  final l10n = AppLocalizations.of(context)!;
  final messenger = ScaffoldMessenger.of(context);
  try {
    // 位置などのメタデータは使わないので、写真ライブラリの権限を求めない形で選ぶ
    final picked =
        await (pick ?? () => ImagePicker().pickMultipleMedia(limit: AlbumLimits.itemsPerAdd, requestFullMetadata: false))();
    return [for (final file in picked.take(AlbumLimits.itemsPerAdd)) File(file.path)];
  } catch (error) {
    debugPrint('[AlbumMediaPick] failed: $error');
    messenger.showSnackBar(buildAppSnackBar(imagePickErrorMessage(error, l10n)));
    return const [];
  }
}
