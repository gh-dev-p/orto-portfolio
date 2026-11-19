import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../l10n/app_localizations.dart';
import '../ui/core/themes/app_colors.dart';
import '../ui/core/ui/app_snack_bar.dart';
import 'image_metadata.dart';

/// 画像選択（カメラ撮影・アルバム選択）で例外が出たときにユーザーへ見せる文言を返す。
///
/// `image_picker`は、カメラ／写真へのアクセスが拒否されると`PlatformException`
/// （コードは`camera_access_denied`・`camera_access_restricted`・`photo_access_denied`等）を投げる。
/// アルバム選択は、Androidの写真選択画面・iOS 14以降のPHPickerでは権限を要さず、通常は
/// 拒否が起きないが、起きた場合に黙って何も表示されない状態を避けるために案内を出す。
String imagePickErrorMessage(Object error, AppLocalizations l10n) {
  if (error is PlatformException) {
    if (error.code.startsWith('camera_access')) return l10n.commonPickCameraDenied;
    if (error.code.startsWith('photo_access')) return l10n.commonPickPhotoDenied;
  }
  return l10n.commonPickFailed;
}

/// 画像を選択して返す。キャンセル時は`null`。
///
/// 権限拒否などで選択に失敗した場合は、原因に応じたSnackBarを表示して`null`を返す
/// （呼び出し側は`null`のとき何もしなくてよい）。[pick]はテスト用の差し替え。
Future<XFile?> pickImageSafely(
  BuildContext context,
  ImageSource source, {
  double? maxWidth,
  double? maxHeight,
  int? imageQuality,
  Future<XFile?> Function()? pick,
}) async {
  final l10n = AppLocalizations.of(context)!;
  final messenger = ScaffoldMessenger.of(context);
  try {
    return await (pick ??
        () => ImagePicker().pickImage(
          source: source,
          maxWidth: maxWidth,
          maxHeight: maxHeight,
          imageQuality: imageQuality,
          requestFullMetadata: false,
        ))();
  } catch (error) {
    debugPrint('[ImagePick] failed: $error');
    messenger.showSnackBar(buildAppSnackBar(imagePickErrorMessage(error, l10n)));
    return null;
  }
}

/// サーバーへ上げる画像を選択して返す。キャンセル時は`null`。
///
/// 位置・機種・撮影時刻などのメタデータを消したファイルを返す（データ設計書7.2）。消せなければ、
/// 元のファイルは返さず、SnackBarを表示して`null`を返す。[pick]・[sanitize]はテスト用の差し替え。
Future<XFile?> pickImageForUpload(
  BuildContext context,
  ImageSource source, {
  double? maxWidth,
  double? maxHeight,
  int? imageQuality,
  Future<XFile?> Function()? pick,
  Future<File> Function(File source) sanitize = sanitizeImageForUpload,
}) async {
  final l10n = AppLocalizations.of(context)!;
  final messenger = ScaffoldMessenger.of(context);
  final picked = await pickImageSafely(
    context,
    source,
    maxWidth: maxWidth,
    maxHeight: maxHeight,
    imageQuality: imageQuality,
    pick: pick,
  );
  if (picked == null) return null;
  try {
    return XFile((await sanitize(File(picked.path))).path);
  } catch (error) {
    debugPrint('[ImagePick] sanitize failed: $error');
    messenger.showSnackBar(buildAppSnackBar(l10n.commonPickFailed));
    return null;
  }
}

/// 「カメラで撮影」「ギャラリーから選択」を選ぶボトムシート。キャンセル時は`null`。
Future<ImageSource?> showImageSourceSheet(BuildContext context) {
  final l10n = AppLocalizations.of(context)!;
  return showModalBottomSheet<ImageSource>(
    context: context,
    backgroundColor: context.colors.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: Icon(Icons.photo_camera_outlined, color: context.colors.primaryText),
            title: Text(l10n.commonPickCamera),
            onTap: () => Navigator.of(context).pop(ImageSource.camera),
          ),
          ListTile(
            leading: Icon(Icons.photo_library_outlined, color: context.colors.primaryText),
            title: Text(l10n.commonPickGallery),
            onTap: () => Navigator.of(context).pop(ImageSource.gallery),
          ),
        ],
      ),
    ),
  );
}
