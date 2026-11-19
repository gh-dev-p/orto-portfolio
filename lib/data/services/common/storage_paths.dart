/// データ設計書7章「Storage設計」に対応する、Storageのパス。アプリ内でStorageのパスを組み立てるのはここだけにする
/// （storage.rules・Cloud Functions（onMessageUnsent・withdrawUser）と同じパスを使うこと）。
abstract final class StoragePaths {
  /// プロフィール画像（固定名で上書き）。
  static String profileImage(String accountId) => 'accounts/$accountId/profile.jpg';

  /// 背景画像（固定名で上書き）。GIFも同じ名前で保存する（種類はcontentTypeで区別する）。
  static String backgroundImage(String accountId) => 'accounts/$accountId/background.jpg';

  /// グループの画像。変更のたびに別のファイルにし、古いファイルはCloud Functionsが消す。
  static String groupPhoto(String chatRoomId, String fileName) => 'chatRooms/$chatRoomId/photo/$fileName';

  /// トークの画像。メッセージごとに別のファイルで、上書きしない。メッセージの`imagePath`にも
  /// このパスを入れる（firestore.rulesが、このパスと一致することを検証する）。
  static String chatImage(String chatRoomId, String messageId) => 'chatRooms/$chatRoomId/images/$messageId.jpg';

  /// アルバムの画像（データ設計書3.13・7章）。項目の`path`にもこのパスを入れる（firestore.rulesが、このパスと
  /// 一致することを検証する）。項目ごとに別のファイルで、上書きしない。
  static String albumImage(String chatRoomId, String albumId, String itemId) =>
      'chatRooms/$chatRoomId/albums/$albumId/$itemId.jpg';

  /// アルバムの動画。
  static String albumVideo(String chatRoomId, String albumId, String itemId) =>
      'chatRooms/$chatRoomId/albums/$albumId/$itemId.mp4';

  /// アルバムの項目のサムネイル。
  static String albumThumbnail(String chatRoomId, String albumId, String itemId) =>
      'chatRooms/$chatRoomId/albums/$albumId/${itemId}_thumb.jpg';
}
