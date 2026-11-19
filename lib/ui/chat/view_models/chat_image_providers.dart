import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/service_providers.dart';

// ============================================================
// Provider
// ============================================================

/// トークの画像のダウンロードURL
/// 引数はStorageのパス。URLはFirestoreに保存せず、表示のたびにルールで許可された参加者がSDK経由で取得する（データ設計書3.3.1）
final chatImageUrlProvider = FutureProvider.family<String, String>((ref, path) {
  return ref.watch(chatRepositoryProvider).imageDownloadUrl(path);
});
