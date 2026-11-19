import 'package:flutter_test/flutter_test.dart';
import 'package:multi_id_msg/utils/storage_image_url.dart';

const _host = 'https://firebasestorage.googleapis.com/v0/b';
const _prod = '$_host/example-orto-prod.firebasestorage.app/o';
const _dev = '$_host/example-orto-dev.firebasestorage.app/o';

void main() {
  group('isOwnImageUrl', () {
    test('本番とdevの自分の画像を受け付ける。ビルド16以前のupdatedAtが付いたURLも同じ', () {
      expect(isOwnImageUrl('$_prod/accounts%2Falice%2Fprofile.jpg?alt=media&token=t&v=ab12', 'alice'), isTrue);
      expect(isOwnImageUrl('$_dev/accounts%2Falice%2Fbackground.jpg?alt=media&token=t', 'alice'), isTrue);
      expect(isOwnImageUrl('$_prod/accounts%2Falice%2Fprofile.jpg?alt=media&token=t&updatedAt=1790000000000', 'alice'), isTrue);
    });

    test('記号を含むアカウントIDを受け付ける', () {
      expect(isOwnImageUrl('$_prod/accounts%2Fa.b-c_d%2Fprofile.jpg?alt=media', 'a.b-c_d'), isTrue);
    });

    test('他のアカウントの画像は受け付けない', () {
      expect(isOwnImageUrl('$_prod/accounts%2Fbob%2Fprofile.jpg?alt=media', 'alice'), isFalse);
    });

    test('他のサーバー、他のバケット、見かけだけ似たURLは受け付けない', () {
      for (final url in [
        'https://attacker.example/t/1.jpg',
        'http://firebasestorage.googleapis.com/v0/b/example-orto-prod.firebasestorage.app/o/accounts%2Falice%2Fp.jpg',
        '$_host/attacker.firebasestorage.app/o/accounts%2Falice%2Fp.jpg',
        '$_host/example-orto-prod.firebasestorage.app.evil.example/o/accounts%2Falice%2Fp.jpg',
        'https://firebasestorage.googleapis.com@attacker.example/v0/b/example-orto-prod.firebasestorage.app/o/accounts%2Falice%2Fp.jpg',
        'https://firebasestorage.googleapis.com.attacker.example/v0/b/example-orto-prod.firebasestorage.app/o/accounts%2Falice%2Fp.jpg',
        '$_prod/accounts%2Falice%2F..%2Fbob%2Fp.jpg',
        ' $_prod/accounts%2Falice%2Fp.jpg',
      ]) {
        expect(isOwnImageUrl(url, 'alice'), isFalse, reason: url);
      }
    });
  });

  group('isStorageImageUrl', () {
    test('アカウントの画像とグループの画像を受け付ける', () {
      expect(isStorageImageUrl('$_prod/accounts%2Fbob%2Fprofile.jpg?alt=media&token=t'), isTrue);
      expect(isStorageImageUrl('$_prod/chatRooms%2FAbC123%2Fphoto%2F1790000000000.jpg?alt=media&token=t'), isTrue);
    });

    test('トークの画像や空文字、他のサーバーは受け付けない', () {
      expect(isStorageImageUrl('$_prod/chatRooms%2Falice~bob%2Fimages%2Fm1.jpg?alt=media'), isFalse);
      expect(isStorageImageUrl(''), isFalse);
      expect(isStorageImageUrl('https://attacker.example/t/1.jpg'), isFalse);
    });
  });
}
