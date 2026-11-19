import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/service_providers.dart';
import '../../../domain/models/sticker_pack.dart';

// ============================================================
// Provider
// ============================================================

/// スタンプのパックの一覧（機能仕様書4.4.8）
/// 読み取れないあいだは値が無く、パックが無いときと同じくスタンプボタンを出さない
final stickerPacksProvider = StreamProvider.autoDispose<List<StickerPack>>((ref) {
  return ref.watch(chatRepositoryProvider).watchStickerPacks();
});
