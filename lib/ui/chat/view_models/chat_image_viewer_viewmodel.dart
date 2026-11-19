import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/service_providers.dart';
import '../../../data/repositories/chat/chat_repository.dart';

// ============================================================
// ViewModel
// ============================================================

/// CHA-03（トークの画像の全画面表示）のViewModel
/// 画像の端末のアルバムへの保存を扱う
///
/// 画面設計書：5.3.3
class ChatImageViewerViewModel extends Notifier<void> {
  ChatImageViewerViewModel(this.path);

  // ---- 状態・初期化 ----

  /// 表示している画像のStorageのパス
  final String path;

  /// 最初の状態を作る
  /// 状態は持たない（保存の結果はメソッドの戻り値で返す）
  @override
  void build() {}

  // ---- 操作 ----

  /// 端末のアルバムへの保存が許可されているか
  /// まだ許可を求めていなければ、ここで求める（許可されなければfalse）
  Future<bool> ensureAccess() => ref.read(chatRepositoryProvider).ensurePhotoLibraryAccess();

  /// 画像を端末のアルバムに保存する
  /// 結果を返す（先に[ensureAccess]で許可を確かめておく）
  Future<ImageSaveResult> save() => ref.read(chatRepositoryProvider).saveImageToPhotoLibrary(path);
}

// ============================================================
// Provider
// ============================================================

/// [ChatImageViewerViewModel]のProvider
/// 引数は画像のStorageのパス。誰も監視しなくなったら破棄される（autoDispose）
final chatImageViewerViewModelProvider = NotifierProvider.autoDispose.family<ChatImageViewerViewModel, void, String>(
  ChatImageViewerViewModel.new,
);
