import 'dart:io';
import 'dart:ui' as ui;

/// 画像ファイルの縦横の大きさ（px）を読む（トークの画像メッセージの`imageWidth`・`imageHeight`用）。
/// カメラ写真の回転（EXIFの向き）を反映した大きさにするため、実際にデコードして測る。
Future<({int width, int height})> readImageSize(File file) async {
  final codec = await ui.instantiateImageCodec(await file.readAsBytes());
  final frame = await codec.getNextFrame();
  final size = (width: frame.image.width, height: frame.image.height);
  frame.image.dispose();
  codec.dispose();
  return size;
}
