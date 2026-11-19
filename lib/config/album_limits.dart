/// トークのアルバムの上限（機能仕様書4.4.9）
/// アプリ側の上限は画面表示と事前の確認用で、拒否はサーバーの実装で保証する（サーバーの実装にも同じ値を持たせること）
abstract final class AlbumLimits {
  /// アルバムの名前の最大文字数
  static const nameMaxLength = 50;

  /// 1回に追加できる件数
  static const itemsPerAdd = 50;

  /// 1アルバムの件数
  static const itemsPerAlbum = 1000;

  /// 1トークのアルバム数
  static const albumsPerRoom = 100;

  /// 1トークの合計の容量
  static const bytesPerRoom = 10 * 1024 * 1024 * 1024;

  /// 画像の大きさの上限
  static const imageMaxBytes = 10 * 1024 * 1024;

  /// 画像の長辺
  static const imageMaxSide = 1920;

  /// 画像のJPEG品質
  static const imageQuality = 85;

  /// 動画の長さの上限
  static const videoMaxDuration = Duration(minutes: 5);

  /// 圧縮後の動画の大きさの上限
  static const videoMaxBytes = 100 * 1024 * 1024;

  /// 動画の短辺
  static const videoMaxShortSide = 720;

  /// 動画のビットレート
  static const videoBitrate = 2000000;

  /// 音声のビットレート
  static const audioBitrate = 128000;

  /// 動画のフレームレートの上限
  static const videoMaxFrameRate = 30;

  /// サムネイルの長辺
  static const thumbnailMaxSide = 480;

  /// サムネイルのJPEG品質
  static const thumbnailQuality = 70;
}
