import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:multi_id_msg/data/services/profile/profile_storage_service.dart';

void main() {
  group('imageContentType', () {
    test('GIFの先頭ならimage/gif', () {
      expect(imageContentType(ascii.encode('GIF89a')), 'image/gif');
      expect(imageContentType(ascii.encode('GIF87a')), 'image/gif');
    });

    test('それ以外はimage/jpeg', () {
      expect(imageContentType(const [0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10]), 'image/jpeg');
    });

    test('先頭が短いファイルはimage/jpeg', () {
      expect(imageContentType(ascii.encode('GIF')), 'image/jpeg');
    });
  });
}
