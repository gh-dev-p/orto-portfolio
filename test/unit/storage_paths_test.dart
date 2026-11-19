import 'package:flutter_test/flutter_test.dart';
import 'package:multi_id_msg/domain/models/chat_room.dart';
import 'package:multi_id_msg/data/services/common/storage_paths.dart';

void main() {
  group('Storageのパス（データ設計書7章・storage.rulesと同じ形）', () {
    test('プロフィール画像・背景画像はアカウントごとの固定名', () {
      expect(StoragePaths.profileImage('alice'), 'accounts/alice/profile.jpg');
      expect(StoragePaths.backgroundImage('alice'), 'accounts/alice/background.jpg');
    });

    test('トークの画像はルームID（2つのaccountIdを~で連結）の下に、メッセージごとのファイル名で置く', () {
      final chatRoomId = buildChatRoomId('bob', 'alice');
      expect(StoragePaths.chatImage(chatRoomId, 'm1'), 'chatRooms/alice~bob/images/m1.jpg');
    });
  });
}
