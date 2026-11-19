import 'dart:io';
import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';

import '../../../domain/models/chat_image_too_large_exception.dart';

// ============================================================
// サービス
// ============================================================

/// トークの画像（データ設計書7章）のCloud Storageを包むサービス
/// アップロード・ダウンロードURLの取得・データの取得を行う
///
/// ダウンロードURLはFirestoreに保存しない（URLを知っていれば、Storageのルールに関係なく誰でも読めるため）。表示のたびに、ルールで許可された参加者がSDK経由で取得する
class ChatImageStorageService {
  ChatImageStorageService(this._storage);

  // ---- 状態・初期化 ----

  /// Cloud Storage
  final FirebaseStorage _storage;

  /// アップロードできる大きさの上限
  /// storage.rulesの10MB未満と同じ
  static const maxSizeBytes = 10 * 1024 * 1024;

  /// 取得したダウンロードURL（キーはStorageのパス）
  /// 同じ画像を何度も表示するため、端末内（メモリ）にだけ覚えておく
  final _urlCache = <String, String>{};

  // ---- 画像 ----

  /// [path]に画像をアップロードする
  /// 新規作成のみ（上書きはルールで拒否される）。[onProgress]には、送信済みの割合（0〜1）を渡す
  Future<void> upload(String path, File file, {void Function(double progress)? onProgress}) async {
    if (await file.length() >= maxSizeBytes) throw const ChatImageTooLargeException();
    await uploadFile(path, file, contentType: 'image/jpeg', onProgress: onProgress);
  }

  /// [path]に[contentType]のファイルをアップロードする（アルバムの画像・動画・サムネイル）
  /// 新規作成のみ（上書きはルールで拒否される）。大きさの上限は呼び出し側が確かめる
  Future<void> uploadFile(
    String path,
    File file, {
    required String contentType,
    void Function(double progress)? onProgress,
  }) async {
    final task = _storage.ref(path).putFile(file, SettableMetadata(contentType: contentType));
    final subscription = onProgress == null
        ? null
        : task.snapshotEvents.listen((snapshot) {
            if (snapshot.totalBytes > 0) onProgress(snapshot.bytesTransferred / snapshot.totalBytes);
          }, onError: (Object _) {}); // 失敗はtask自体のawaitで受け取る
    try {
      await task;
    } finally {
      await subscription?.cancel();
    }
  }

  /// 表示用のダウンロードURL
  /// 一度取得したURLは[_urlCache]から返す
  Future<String> downloadUrl(String path) async {
    final cached = _urlCache[path];
    if (cached != null) return cached;
    final url = await _storage.ref(path).getDownloadURL();
    _urlCache[path] = url;
    return url;
  }

  /// [path]のファイルを、端末の[file]へダウンロードする
  /// アルバムの動画を端末のアルバムに保存するときに使う（大きいのでメモリに載せない）
  Future<void> downloadToFile(String path, File file) async {
    await _storage.ref(path).writeToFile(file);
  }

  /// 画像のデータを取得する
  /// 端末のアルバムへの保存（CHA-03）に使う
  Future<Uint8List> download(String path) async {
    final data = await _storage.ref(path).getData(maxSizeBytes);
    if (data == null) throw StateError('image not found');
    return data;
  }
}
