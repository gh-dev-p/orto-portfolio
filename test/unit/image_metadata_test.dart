import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:multi_id_msg/data/services/profile/profile_storage_service.dart';
import 'package:multi_id_msg/utils/image_metadata.dart';

List<int> _text(String value) => ascii.encode(value);

/// 2フレームのGIFの各ブロック（2色のグローバルカラーテーブル）
final _header = [..._text('GIF89a'), 1, 0, 1, 0, 0x80, 0, 0, 0, 0, 0, 255, 255, 255];
final _loop = [0x21, 0xFF, 11, ..._text('NETSCAPE2.0'), 3, 1, 0, 0, 0];
const _control = [0x21, 0xF9, 4, 0x04, 10, 0, 0, 0];
const _frame = [0x2C, 0, 0, 0, 0, 1, 0, 1, 0, 0, 2, 2, 0x44, 0x01, 0];
const _trailer = [0x3B];

List<int> _comment(String value) => [0x21, 0xFE, value.length, ..._text(value), 0];

/// XMPの形のアプリケーション拡張
List<int> _xmp(String value) => [0x21, 0xFF, 11, ..._text('XMP DataXMP'), value.length, ..._text(value), 0];

Uint8List _bytes(List<List<int>> blocks) => Uint8List.fromList(blocks.expand((block) => block).toList());

/// JPEGのセグメント
List<int> _segment(int marker, List<int> data) => [0xFF, marker, (data.length + 2) >> 8, (data.length + 2) & 0xFF, ...data];

const _soi = [0xFF, 0xD8];
final _jfif = _segment(0xE0, _text('JFIF'));
final _adobe = _segment(0xEE, _text('Adobe'));
final _quantization = _segment(0xDB, [0, 1, 2]);
final _exif = _segment(0xE1, _text('Exif  GPS 35.68,139.76 SpyPhone'));
final _xmpSegment = _segment(0xE1, _text('http://ns.adobe.com/xap/1.0/ GPS'));
final _iptc = _segment(0xED, _text('Photoshop 3.0 GPS'));
final _jpegComment = _segment(0xFE, _text('GPS'));
const _scan = [0xFF, 0xDA, 0, 2, 0x12, 0x34, 0xFF, 0xD9];

void main() {
  group('stripGifMetadata', () {
    test('コメントとXMPと終端より後のデータを除き、動きに必要なブロックは残す', () {
      final input = _bytes([
        _header,
        _comment('GPS 35.68,139.76'),
        _loop,
        _xmp('<rdf:Description exif:GPSLatitude="35"/>'),
        _control,
        _frame,
        _comment('iPhone'),
        _control,
        _frame,
        _trailer,
        _text('trailing GPS'),
      ]);

      final output = stripGifMetadata(input);

      expect(output, _bytes([_header, _loop, _control, _frame, _control, _frame, _trailer]));
      expect(latin1.decode(output).contains('GPS'), isFalse);
    });

    test('メタデータが無ければ同じバイト列を返す', () {
      final input = _bytes([_header, _loop, _control, _frame, _control, _frame, _trailer]);
      expect(stripGifMetadata(input), input);
    });

    test('ローカルカラーテーブルのある画像を残す', () {
      final frame = [0x2C, 0, 0, 0, 0, 1, 0, 1, 0, 0x80, 0, 0, 0, 1, 1, 1, 2, 2, 0x44, 0x01, 0];
      final input = _bytes([_header, frame, _trailer]);
      expect(stripGifMetadata(input), input);
    });

    test('壊れたGIFは例外を投げる', () {
      expect(() => stripGifMetadata(_bytes([_header, _frame.sublist(0, 12)])), throwsFormatException);
      expect(() => stripGifMetadata(_bytes([_header, [0x99]])), throwsFormatException);
      expect(() => stripGifMetadata(Uint8List.fromList(_text('GIF89a'))), throwsFormatException);
    });
  });

  group('stripJpegMetadata', () {
    test('Exif、XMP、IPTC、コメントを除き、画素に必要なセグメントは残す', () {
      final input = _bytes([_soi, _jfif, _exif, _xmpSegment, _iptc, _jpegComment, _adobe, _quantization, _scan]);

      final output = stripJpegMetadata(input);

      expect(output, _bytes([_soi, _jfif, _adobe, _quantization, _scan]));
      expect(latin1.decode(output).contains('GPS'), isFalse);
    });

    test('メタデータが無ければ同じバイト列を返す', () {
      final input = _bytes([_soi, _jfif, _quantization, _scan]);
      expect(stripJpegMetadata(input), input);
    });

    test('JPEGでない・壊れたデータは例外を投げる', () {
      expect(() => stripJpegMetadata(Uint8List.fromList(_text('PNG'))), throwsFormatException);
      expect(() => stripJpegMetadata(_bytes([_soi, [0x00, 0x00, 0x00, 0x00]])), throwsFormatException);
      expect(() => stripJpegMetadata(_bytes([_soi, [0xFF, 0xE1, 0xFF, 0xFF]])), throwsFormatException);
    });
  });

  group('sanitizeImageForUpload', () {
    late Directory dir;

    setUp(() async => dir = await Directory.systemTemp.createTemp('image_metadata_test'));
    tearDown(() => dir.delete(recursive: true));

    test('GIFは再エンコードせず、メタデータを除いて別のファイルにする', () async {
      final input = _bytes([_header, _comment('GPS'), _frame, _trailer]);
      final source = await File('${dir.path}/a.gif').writeAsBytes(input);

      final output = await sanitizeImageForUpload(
        source,
        reencode: (_, _) async => fail('GIFは再エンコードしない'),
      );

      expect(await output.readAsBytes(), _bytes([_header, _frame, _trailer]));
      expect(await source.readAsBytes(), input);
    });

    test('GIF以外は再エンコードし、エンコーダが足したメタデータも除いた別のファイルを返す', () async {
      final source = await File('${dir.path}/a.jpg').writeAsBytes([0xFF, 0xD8, 1, 2, 3, 4, 5]);

      final output = await sanitizeImageForUpload(
        source,
        reencode: (input, path) async {
          expect(input.path, source.path);
          await File(path).writeAsBytes(_bytes([_soi, _exif, _quantization, _scan]));
        },
      );

      expect(output.path, isNot(source.path));
      expect(await output.readAsBytes(), _bytes([_soi, _quantization, _scan]));
    });

    test('再エンコードの結果がJPEGでなければ例外を投げる', () async {
      final source = await File('${dir.path}/a.jpg').writeAsBytes([0xFF, 0xD8, 1, 2, 3, 4, 5]);
      expect(
        sanitizeImageForUpload(source, reencode: (_, path) => File(path).writeAsBytes([9])),
        throwsFormatException,
      );
    });

    test('再エンコードに失敗したら例外を投げる', () async {
      final source = await File('${dir.path}/a.jpg').writeAsBytes([0xFF, 0xD8, 1, 2, 3, 4, 5]);
      expect(
        sanitizeImageForUpload(source, reencode: (_, _) async => throw StateError('failed')),
        throwsStateError,
      );
    });
  });

  group('newCacheBuster', () {
    test('時刻ではない16文字の乱数を返す', () {
      final values = {for (var i = 0; i < 20; i++) newCacheBuster()};
      expect(values, hasLength(20));
      expect(values.every(RegExp(r'^[0-9a-f]{16}$').hasMatch), isTrue);
    });
  });
}
