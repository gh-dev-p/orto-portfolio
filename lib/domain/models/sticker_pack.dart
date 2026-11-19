/// `stickerPacks/{packId}`ドキュメント。データ設計書3.9参照。
/// 画像はStorageの`stickers/{packId}/{stickerId}.webp`に置く
class StickerPack {
  const StickerPack({required this.id, required this.stickerIds});

  final String id;

  /// 選択シートに並べる順のスタンプのID
  final List<String> stickerIds;

  factory StickerPack.fromMap(Map<String, dynamic> map) => StickerPack(
    id: map['packId'] as String? ?? '',
    stickerIds: (map['stickerIds'] as List<dynamic>? ?? const []).whereType<String>().toList(),
  );

  static final _validId = RegExp(r'^[A-Za-z0-9_-]{1,50}$');

  /// スタンプの画像のStorageのパス
  /// メッセージのIDは送信者が決められるため、形式の合わないIDはパスにせずnullを返す
  static String? storagePath(String packId, String stickerId) {
    if (!_validId.hasMatch(packId) || !_validId.hasMatch(stickerId)) return null;
    return 'stickers/$packId/$stickerId.webp';
  }
}
