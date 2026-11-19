import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_image_compress/flutter_image_compress.dart';

/// 上げる画像を再エンコードするときのJPEGの品質（選択時の圧縮に重ねるので、高めにする）
const _jpegQuality = 90;

/// 再エンコードで縮小しないよう、どの画像より大きな値を渡す（縮小は選択時に済ませている）
const _noResizeSide = 1 << 15;

/// [input]の画素だけをJPEGとして[outputPath]へ書き直す（位置・機種・撮影時刻などのメタデータは持ち越さない）
/// 向きは画素に反映する。エンコーダが書き足す項目は、後から[stripJpegMetadata]で除く
typedef ImageReencoder = Future<void> Function(File input, String outputPath);

Future<void> _reencodeWithPlugin(File input, String outputPath) async {
  final result = await FlutterImageCompress.compressAndGetFile(
    input.path,
    outputPath,
    minWidth: _noResizeSide,
    minHeight: _noResizeSide,
    quality: _jpegQuality,
    autoCorrectionAngle: true,
    keepExif: false,
  );
  if (result == null) throw StateError('image re-encode failed');
}

/// [source]からメタデータを取り除いたファイルを作って返す。元のファイルは変えない
///
/// GIFは再エンコードすると動かなくなるので、画像以外のブロックだけを除く（[stripGifMetadata]）。
/// それ以外はJPEGに再エンコードし、iOSのエンコーダが足す汎用のExifなども除く（[stripJpegMetadata]）。
/// 取り除けなければ例外を投げる（元のファイルを上げてはならない）
Future<File> sanitizeImageForUpload(File source, {ImageReencoder reencode = _reencodeWithPlugin}) async {
  final name = 'sanitized_${DateTime.now().microsecondsSinceEpoch}';
  final bytes = await source.readAsBytes();
  if (isGif(bytes)) {
    return File('${source.parent.path}/$name.gif').writeAsBytes(stripGifMetadata(bytes), flush: true);
  }
  final output = '${source.parent.path}/$name.jpg';
  await reencode(source, output);
  return File(output).writeAsBytes(stripJpegMetadata(await File(output).readAsBytes()), flush: true);
}

const _jpegStartOfScan = 0xDA;
const _jpegComment = 0xFE;
const _jpegApp0 = 0xE0;
const _jpegApp15 = 0xEF;

/// 残すアプリケーションセグメント（APP0のJFIF、APP2の色のプロファイル、APP14のAdobeの色の指定）
const _jpegKeptApps = {_jpegApp0, 0xE2, 0xEE};

/// JPEGの[bytes]から、ExifやXMPなどのアプリケーションセグメントとコメントを除く
/// 画素の復号に必要なセグメントは変えない。JPEGでなければ[FormatException]を投げる
Uint8List stripJpegMetadata(Uint8List bytes) {
  if (bytes.length < 2 || bytes[0] != 0xFF || bytes[1] != 0xD8) throw const FormatException('not a JPEG');
  final out = BytesBuilder(copy: false)..add(Uint8List.sublistView(bytes, 0, 2));
  var position = 2;
  while (true) {
    if (position + 4 > bytes.length || bytes[position] != 0xFF) throw const FormatException('broken JPEG');
    final marker = bytes[position + 1];
    if (marker == _jpegStartOfScan) {
      out.add(Uint8List.sublistView(bytes, position));
      return out.takeBytes();
    }
    final end = position + 2 + (bytes[position + 2] << 8 | bytes[position + 3]);
    if (end > bytes.length) throw const FormatException('truncated JPEG');
    final isMetadata =
        marker == _jpegComment || (marker >= _jpegApp0 && marker <= _jpegApp15 && !_jpegKeptApps.contains(marker));
    if (!isMetadata) out.add(Uint8List.sublistView(bytes, position, end));
    position = end;
  }
}

/// 先頭の6バイトからGIFかどうかを判定する
bool isGif(List<int> header) {
  if (header.length < _gifHeaderLength) return false;
  final signature = ascii.decode(header.sublist(0, _gifHeaderLength), allowInvalid: true);
  return signature == 'GIF87a' || signature == 'GIF89a';
}

const _gifHeaderLength = 6;
const _gifScreenDescriptorLength = 7;
const _gifImageDescriptorLength = 9;
const _gifExtensionIntroducer = 0x21;
const _gifImageSeparator = 0x2C;
const _gifTrailer = 0x3B;
const _gifGraphicControlLabel = 0xF9;
const _gifApplicationLabel = 0xFF;

/// 動きに必要なアプリケーション拡張（繰り返しの回数）
const _gifLoopApplications = {'NETSCAPE2.0', 'ANIMEXTS1.0'};

/// GIFの[bytes]から、画面に出ないブロック（コメント、XMPなどのアプリケーション拡張、終端より後のデータ）を除く
/// 画像とその表示の制御、繰り返しの指定だけを残す。形式が壊れていれば[FormatException]を投げる
Uint8List stripGifMetadata(Uint8List bytes) {
  final out = BytesBuilder(copy: false);

  // [end]までの範囲を確かめて返す
  int checked(int end) {
    if (end > bytes.length) throw const FormatException('truncated GIF');
    return end;
  }

  // [start]から続くサブブロックの列の、終わりの次の位置を返す
  int skipSubBlocks(int start) {
    var position = start;
    while (true) {
      checked(position + 1);
      final size = bytes[position];
      position = checked(position + 1 + size);
      if (size == 0) return position;
    }
  }

  // カラーテーブルの大きさ（[flags]の最上位ビットがあるときだけ続く）
  int colorTableLength(int flags) => flags & 0x80 == 0 ? 0 : 3 << ((flags & 0x07) + 1);

  var position = checked(_gifHeaderLength + _gifScreenDescriptorLength);
  position = checked(position + colorTableLength(bytes[position - 3]));
  out.add(Uint8List.sublistView(bytes, 0, position));

  while (true) {
    checked(position + 1);
    final marker = bytes[position];
    switch (marker) {
      case _gifTrailer:
        out.addByte(_gifTrailer);
        return out.takeBytes();
      case _gifImageSeparator:
        final descriptorEnd = checked(position + 1 + _gifImageDescriptorLength);
        // ローカルカラーテーブルの次に、LZWの最小コードサイズの1バイトが続く
        final dataStart = checked(descriptorEnd + colorTableLength(bytes[descriptorEnd - 1]) + 1);
        final end = skipSubBlocks(dataStart);
        out.add(Uint8List.sublistView(bytes, position, end));
        position = end;
      case _gifExtensionIntroducer:
        checked(position + 2);
        final label = bytes[position + 1];
        final end = skipSubBlocks(position + 2);
        final keep = label == _gifGraphicControlLabel ||
            (label == _gifApplicationLabel && _gifLoopApplications.contains(_gifApplicationName(bytes, position + 2, end)));
        if (keep) out.add(Uint8List.sublistView(bytes, position, end));
        position = end;
      default:
        throw const FormatException('unknown GIF block');
    }
  }
}

/// [start]から始まるアプリケーション拡張の名前（11バイト）を読む
String _gifApplicationName(Uint8List bytes, int start, int end) {
  const nameLength = 11;
  if (bytes[start] != nameLength || start + 1 + nameLength > end) return '';
  return ascii.decode(bytes.sublist(start + 1, start + 1 + nameLength), allowInvalid: true);
}
