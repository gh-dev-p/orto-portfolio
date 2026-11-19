import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:multi_id_msg/utils/image_metadata.dart';

// 位置情報付きの写真の再エンコード（flutter_image_compress）で、メタデータが消え、向きが画素に反映されることを実機相当で確かめる。
// 実行：flutter test integration_test/image_metadata_test.dart --flavor dev -d <device>
// iOSでは、ios/Flutter/Debug-dev.xcconfigのFLUTTER_TARGETが起動ファイルを固定するため、実行の間だけその行を外す
// （外さないと通常のアプリが起動し、テストが始まらない）。
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late Directory dir;

  setUpAll(() async => dir = await Directory.systemTemp.createTemp('image_metadata_test'));
  tearDownAll(() => dir.delete(recursive: true));

  testWidgets('GPSと機種のメタデータが消え、向きが画素に反映される', (tester) async {
    final source = _withExif(base64Decode(_sampleJpeg));
    expect(_contains(source, 'SpyPhone'), isTrue);
    expect(_contains(source, 'Exif'), isTrue);
    expect(_size(source), (width: 40, height: 20));

    final input = File('${dir.path}/input.jpg');
    await input.writeAsBytes(source);
    final output = await (await sanitizeImageForUpload(input)).readAsBytes();

    expect(_contains(output, 'SpyPhone'), isFalse);
    expect(_contains(output, 'Exif'), isFalse);
    expect(_appSegments(output).where((marker) => !{0xE0, 0xE2, 0xEE}.contains(marker)), isEmpty);
    expect(_size(output), (width: 20, height: 40));
  });
}

bool _contains(List<int> bytes, String text) => latin1.decode(bytes).contains(text);

/// JPEGのセグメントを順に読み、スキャンの前までのマーカーを返す
Iterable<int> _segments(List<int> jpeg) sync* {
  var position = 2;
  while (position + 4 <= jpeg.length && jpeg[position] == 0xFF) {
    final marker = jpeg[position + 1];
    yield marker;
    if (marker == 0xDA) return;
    position += 2 + (jpeg[position + 2] << 8 | jpeg[position + 3]);
  }
}

/// APPnのマーカー
Iterable<int> _appSegments(List<int> jpeg) => _segments(jpeg).where((marker) => marker >= 0xE0 && marker <= 0xEF);

/// JPEGの画素の大きさ（SOFの値。EXIFの向きは反映しない）
({int width, int height}) _size(List<int> jpeg) {
  var position = 2;
  while (true) {
    final marker = jpeg[position + 1];
    if (marker >= 0xC0 && marker <= 0xC2) {
      return (height: jpeg[position + 5] << 8 | jpeg[position + 6], width: jpeg[position + 7] << 8 | jpeg[position + 8]);
    }
    position += 2 + (jpeg[position + 2] << 8 | jpeg[position + 3]);
  }
}

/// [jpeg]に、機種・向き（90度回転）・GPSを持つExifのAPP1を差し込む
Uint8List _withExif(Uint8List jpeg) {
  final tiff = BytesBuilder()..add(ascii.encode('MM'))..add([0, 42, 0, 0, 0, 8]);
  void u16(int value) => tiff.add([value >> 8 & 0xFF, value & 0xFF]);
  void u32(int value) => tiff.add([value >> 24 & 0xFF, value >> 16 & 0xFF, value >> 8 & 0xFF, value & 0xFF]);
  void entry(int tag, int type, int count, int value) {
    u16(tag);
    u16(type);
    u32(count);
    u32(value);
  }

  const ifd0Length = 2 + 3 * 12 + 4;
  const gpsIfdOffset = 8 + ifd0Length;
  const gpsIfdLength = 2 + 4 * 12 + 4;
  const latitudeOffset = gpsIfdOffset + gpsIfdLength;
  const longitudeOffset = latitudeOffset + 24;
  const makeOffset = longitudeOffset + 24;

  u16(3);
  entry(0x010F, 2, 9, makeOffset); // Make
  entry(0x0112, 3, 1, 6 << 16); // Orientation：右に90度
  entry(0x8825, 4, 1, gpsIfdOffset); // GPSInfo
  u32(0);

  u16(4);
  entry(0x0001, 2, 2, 0x4E000000); // 北緯
  entry(0x0002, 5, 3, latitudeOffset);
  entry(0x0003, 2, 2, 0x45000000); // 東経
  entry(0x0004, 5, 3, longitudeOffset);
  u32(0);

  for (final degrees in [35, 139]) {
    for (final value in [degrees, 41, 0]) {
      u32(value);
      u32(1);
    }
  }
  tiff.add(ascii.encode('SpyPhone\u0000'));

  final payload = [...ascii.encode('Exif\u0000\u0000'), ...tiff.takeBytes()];
  final length = payload.length + 2;
  return Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE1, length >> 8, length & 0xFF, ...payload, ...jpeg.sublist(2)]);
}

/// 40×20pxのJPEG（左が赤、右が青。メタデータなし）
const _sampleJpeg = '/9j/wAARCAAUACgDASIAAhEBAxEB/8QAHwAAAQUBAQEBAQEAAAAAAAAAAAECAwQFBgcICQoL/8QAtRAAAgEDAwIEAwUFBAQAAAF9AQIDAAQRBRIhMUEGE1FhByJxFDKBkaEII0KxwRVS0fAkM2JyggkKFhcYGRolJicoKSo0NTY3ODk6Q0RFRkdISUpTVFVWV1hZWmNkZWZnaGlqc3R1dnd4eXqDhIWGh4iJipKTlJWWl5iZmqKjpKWmp6ipqrKztLW2t7i5usLDxMXGx8jJytLT1NXW19jZ2uHi4+Tl5ufo6erx8vP09fb3+Pn6/8QAHwEAAwEBAQEBAQEBAQAAAAAAAAECAwQFBgcICQoL/8QAtREAAgECBAQDBAcFBAQAAQJ3AAECAxEEBSExBhJBUQdhcRMiMoEIFEKRobHBCSMzUvAVYnLRChYkNOEl8RcYGRomJygpKjU2Nzg5OkNERUZHSElKU1RVVldYWVpjZGVmZ2hpanN0dXZ3eHl6goOEhYaHiImKkpOUlZaXmJmaoqOkpaanqKmqsrO0tba3uLm6wsPExcbHyMnK0tPU1dbX2Nna4uPk5ebn6Onq8vP09fb3+Pn6/9sAQwACAgICAgIDAgIDBAMDAwQFBAQEBAUHBQUFBQUHCAcHBwcHBwgICAgICAgICgoKCgoKCwsLCwsNDQ0NDQ0NDQ0N/9sAQwECAgIDAwMGAwMGDQkHCQ0NDQ0NDQ0NDQ0NDQ0NDQ0NDQ0NDQ0NDQ0NDQ0NDQ0NDQ0NDQ0NDQ0NDQ0NDQ0NDQ0N/90ABAAD/9oADAMBAAIRAxEAPwD5booor+fz/Xw858f/APLh/wBtv/ZK85r0bx//AMuH/bb/ANkrzmv9ffouf8mxyz/uN/6fqn+Wv0jf+TiZh/3C/wDTNMKKKK/fz8RP/9D5booor+fz/Xw858f/APLh/wBtv/ZK85r0bx//AMuH/bb/ANkrzmv9ffouf8mxyz/uN/6fqn+Wv0jf+TiZh/3C/wDTNMKKKK/fz8RP/9k=';
