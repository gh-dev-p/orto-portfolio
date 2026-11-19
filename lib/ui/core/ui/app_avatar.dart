import 'package:flutter/material.dart';

import '../../../utils/storage_image_url.dart';
import '../themes/app_colors.dart';

/// 頭文字を組むときの文字サイズ。
/// iOSの絵文字は小さい文字サイズで組むと左下へずれるため、大きく組んでから縮小する
const _initialLayoutFontSize = 100.0;

/// プロフィール画像（`photoURL`）があれば表示し、なければ表示名の頭文字をカラー円で表示するアバター。
/// ネットワーク接続なしでも常に表示できる。
/// このアプリのStorageの画像でないURLは読み込まない（読み込むと端末のIPが相手に分かるため）。
class AppAvatar extends StatelessWidget {
  const AppAvatar({
    super.key,
    required this.displayName,
    this.photoURL,
    this.size = 48,
  });

  final String displayName;
  final String? photoURL;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: (photoURL != null && isStorageImageUrl(photoURL!))
            ? Image.network(
                photoURL!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _initialAvatar(context),
              )
            : _initialAvatar(context),
      ),
    );
  }

  // 初期アバター（アバター画像未設定/取得エラーのときに使用）
  Widget _initialAvatar(BuildContext context) {
    // 異体字セレクタや結合文字（✌️、👨‍👩‍👧、国旗など）を分けないよう、見た目の1文字で切り出す
    final initial = displayName.isEmpty ? '?' : displayName.characters.first.toUpperCase();
    return ColoredBox(
      color: context.colors.accent,
      child: Center(
        child: OverflowBox(
          maxWidth: double.infinity,
          maxHeight: double.infinity,
          child: Transform.scale(
            scale: size * 0.4 / _initialLayoutFontSize,
            child: Text(
              initial,
              style: TextStyle(
                color: context.colors.onAccent,
                fontSize: _initialLayoutFontSize,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
