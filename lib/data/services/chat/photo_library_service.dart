import 'dart:typed_data';

import 'package:gal/gal.dart';

// ============================================================
// サービス
// ============================================================

/// 端末のアルバム（写真ライブラリ）を包むサービス
/// 状態を持たず、結果・エラー（[GalException]）をそのまま返す
class PhotoLibraryService {
  const PhotoLibraryService();

  // ---- 保存 ----

  /// アルバムへの保存が許可されているか
  /// まだ許可を求めていなければ、ここで求める（許可されなければfalse）
  Future<bool> ensureAccess() async => await Gal.hasAccess() || await Gal.requestAccess();

  /// 画像のデータ[bytes]を、[name]という名前でアルバムに保存する
  Future<void> saveImage(Uint8List bytes, {required String name}) => Gal.putImageBytes(bytes, name: name);

  /// [path]の画像をアルバムに保存する
  Future<void> saveImageFile(String path) => Gal.putImage(path);

  /// [path]の動画をアルバムに保存する
  Future<void> saveVideo(String path) => Gal.putVideo(path);
}
