import 'package:flutter_test/flutter_test.dart';
import 'package:multi_id_msg/domain/models/account.dart';

Account _account({required bool isDeleted}) => Account(
  id: 'peer',
  displayName: 'Peer',
  photoURL: 'https://example.com/photo.jpg',
  backgroundURL: 'https://example.com/background.jpg',
  bio: 'hello',
  isDeleted: isDeleted,
);

void main() {
  group('他の人の画面に出すプロフィール（データ設計書3.2）', () {
    test('有効なアカウントは、画像・ひとことをそのまま出す', () {
      final account = _account(isDeleted: false);
      expect(account.visiblePhotoURL, account.photoURL);
      expect(account.visibleBackgroundURL, account.backgroundURL);
      expect(account.visibleBio, account.bio);
    });

    test('退会済みのアカウントは、ドキュメントに値が残っていても画像・ひとことを出さない', () {
      final account = _account(isDeleted: true);
      expect(account.visiblePhotoURL, isNull);
      expect(account.visibleBackgroundURL, isNull);
      expect(account.visibleBio, isNull);
    });
  });
}
