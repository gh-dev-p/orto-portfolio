import 'dart:io';
import 'dart:math';

import 'package:firebase_storage/firebase_storage.dart';

import '../../../utils/image_metadata.dart';
import '../common/storage_paths.dart';

// ============================================================
// サービス
// ============================================================

/// プロフィール画像・背景画像（データ設計書7章）のCloud Storageを包むサービス
/// アップロードして、表示用のダウンロードURLを返す（`AccountRepository`から使う）
class ProfileStorageService {
  ProfileStorageService(this._storage);

  // ---- 状態・初期化 ----

  /// Cloud Storage
  final FirebaseStorage _storage;

  /// アップロードできる大きさの上限
  /// storage.rulesの5MB未満と同じ
  static const _maxSizeBytes = 5 * 1024 * 1024;

  // ---- アップロード ----

  /// アカウント[accountId]のプロフィール画像をアップロードし、ダウンロードURLを返す
  Future<String> uploadProfileImage(String accountId, File file) => _upload(StoragePaths.profileImage(accountId), file);

  /// アカウント[accountId]の背景画像をアップロードし、ダウンロードURLを返す
  Future<String> uploadBackgroundImage(String accountId, File file) =>
      _upload(StoragePaths.backgroundImage(accountId), file);

  /// グループ[chatRoomId]の画像を[fileName]でアップロードする
  /// URLはCloud Functionsが作るため返さない（データ設計書8.5）
  Future<void> uploadGroupPhoto(String chatRoomId, String fileName, File file) =>
      _upload(StoragePaths.groupPhoto(chatRoomId, fileName), file);

  /// [path]に画像をアップロードし、ダウンロードURLを返す
  /// 5MB以上・アップロードの失敗は[ProfileUploadException]を投げる
  Future<String> _upload(String path, File file) async {
    final size = await file.length();
    // storage.rulesは5MB未満のみ受け付けるため、ちょうど5MBも送らずに失敗とする。
    if (size >= _maxSizeBytes) {
      throw const ProfileUploadException('file size exceeds 5MB');
    }

    try {
      final ref = _storage.ref(path);
      final header = await file.openRead(0, _gifSignatureLength).expand((bytes) => bytes).toList();
      await ref.putFile(file, SettableMetadata(contentType: imageContentType(header)));
      final url = await ref.getDownloadURL();
      // データ設計書7.1：固定パスへの上書き保存はダウンロードURLがキャッシュされ
      // 画像変更が端末に反映されない問題があるため、乱数をクエリパラメータとして
      // 付与し、Image.networkがURL文字列の変化で再取得するようにする。
      // URLは誰でも読めるので、端末の時計が分かる時刻は入れない。
      final separator = url.contains('?') ? '&' : '?';
      return '$url${separator}v=${newCacheBuster()}';
    } catch (_) {
      throw const ProfileUploadException('upload failed');
    }
  }
}

/// GIFのファイルの先頭の長さ
const _gifSignatureLength = 6;

/// ファイルの先頭の[header]から、画像の種類（contentType）を決める
/// iOSの画像の選択はGIFを動くまま返す（それ以外はJPEGに再エンコードされたものが来る）
String imageContentType(List<int> header) => isGif(header) ? 'image/gif' : 'image/jpeg';

final _random = Random.secure();

/// URLの再取得用の乱数（16進数で16文字）。時刻を含まない
String newCacheBuster() => List.generate(16, (_) => _random.nextInt(16).toRadixString(16)).join();

// ============================================================
// 例外
// ============================================================

/// プロフィール画像・背景画像のアップロードの失敗
/// [message]は開発者向けの識別用の文字列で、画面には出さない（Viewは共通の文言で表示する）
class ProfileUploadException implements Exception {
  const ProfileUploadException(this.message);

  final String message;

  @override
  String toString() => message;
}
