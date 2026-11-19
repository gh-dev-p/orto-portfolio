// オフ会グループの期限・閉じる前の知らせ・閉じたあと（機能仕様書4.7.8.6〜4.7.8.8、データ設計書8.17）
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multi_id_msg/domain/models/chat_room.dart';
import 'package:multi_id_msg/domain/models/friend_request.dart';
import 'package:multi_id_msg/domain/models/group.dart';
import 'package:multi_id_msg/domain/models/meetup_lifecycle.dart';
import 'package:multi_id_msg/domain/models/notification_target.dart';
import 'package:multi_id_msg/l10n/app_localizations.dart';
import 'package:multi_id_msg/ui/friend/widgets/friend_request_failure_message.dart';
import 'package:multi_id_msg/ui/group/widgets/group_failure_message.dart';
import 'package:multi_id_msg/ui/group/widgets/group_info_screen.dart';
import 'package:multi_id_msg/ui/group/widgets/group_system_text.dart';
import 'package:multi_id_msg/ui/group/widgets/meetup_event_screen.dart';

// ignore: subtype_of_sealed_class
class _FakeDoc extends Fake implements DocumentSnapshot<Map<String, dynamic>> {
  _FakeDoc(this.id, this._data);

  @override
  final String id;

  final Map<String, dynamic> _data;

  @override
  Map<String, dynamic>? data() => _data;
}

void main() {
  final now = DateTime(2026, 11, 20, 12);

  group('閉じたか・残り日数', () {
    test('期限が無ければ閉じず、残り日数も無い（日時未定）', () {
      expect(isMeetupClosed(now: now), isFalse);
      expect(meetupDaysLeft(now: now), isNull);
    });

    test('期限を過ぎたら、閉じる処理の前でも閉じている', () {
      expect(isMeetupClosed(closesAt: now, now: now), isTrue);
      expect(isMeetupClosed(closesAt: now.add(const Duration(minutes: 1)), now: now), isFalse);
      expect(isMeetupClosed(closesAt: now.add(const Duration(days: 3)), closedAt: now, now: now), isTrue);
    });

    test('残り日数は日に切り上げる。24時間を切ったら1、閉じたらnull', () {
      expect(meetupDaysLeft(closesAt: now.add(const Duration(days: 3)), now: now), 3);
      expect(meetupDaysLeft(closesAt: now.add(const Duration(days: 2, hours: 1)), now: now), 3);
      expect(meetupDaysLeft(closesAt: now.add(const Duration(hours: 5)), now: now), 1);
      expect(meetupDaysLeft(closesAt: now.subtract(const Duration(hours: 1)), now: now), isNull);
    });

    test('記録が消えるのは期限の30日後', () {
      expect(meetupPurgeAt(now), now.add(const Duration(days: 30)));
    });
  });

  group('閉じる日の選択肢（GRP-08）', () {
    test('会の前は翌日・3日後・1週間後。延ばした値があればそれも', () {
      final eventAt = now.add(const Duration(days: 5));
      expect(meetupCloseDayOptions(eventAt: eventAt, current: 3, now: now), [1, 3, 7]);
      expect(meetupCloseDayOptions(eventAt: eventAt, current: 10, now: now), [1, 3, 7, 10]);
    });

    test('会のあとは14日後まで。閉じる日時が今から1時間以内になる日は出さない（今の値は出す）', () {
      final eventAt = now.subtract(const Duration(days: 2, minutes: 30));
      final options = meetupCloseDayOptions(eventAt: eventAt, current: 3, now: now);
      expect(options.first, 3);
      expect(options.last, meetupMaxCloseAfterDays);
      expect(options, isNot(contains(2)));
    });

    test('言い方は翌日・3日後・1週間後・会の{N}日後', () {
      final ja = lookupAppLocalizations(const Locale('ja'));
      expect(meetupCloseDayLabel(ja, 1), '翌日');
      expect(meetupCloseDayLabel(ja, 3), '3日後');
      expect(meetupCloseDayLabel(ja, 7), '1週間後');
      expect(meetupCloseDayLabel(ja, 10), '会の10日後');
    });
  });

  group('データの読み取り', () {
    test('ルームから閉じる日・期限・閉じた日時を読む。無ければ初期値の3日', () {
      final closesAt = DateTime(2026, 11, 25, 19);
      final room = GroupRoom.fromMap('g1', {
        'groupKind': 'meetup',
        'closeAfterDays': 7,
        'closesAt': Timestamp.fromDate(closesAt),
      });
      expect(room.closeAfterDays, 7);
      expect(room.closesAt, closesAt);
      expect(room.isClosedAt(closesAt.subtract(const Duration(seconds: 1))), isFalse);
      expect(room.isClosedAt(closesAt), isTrue);
      expect(GroupRoom.fromMap('g1', {'groupKind': 'meetup'}).closeAfterDays, meetupDefaultCloseAfterDays);
      expect(GroupRoom.fromMap('g1', {'groupKind': 'meetup', 'closeAfterDays': 99}).closeAfterDays, 3);
      // 普通のグループは閉じない
      expect(GroupRoom.fromMap('g1', {'closesAt': Timestamp.fromDate(closesAt)}).isClosedAt(closesAt), isFalse);
    });

    test('トーク一覧の行から閉じる日時・閉じた日時を読む', () {
      final closesAt = DateTime(2026, 11, 25, 19);
      final entry = ChatListEntry.fromFirestore(
        _FakeDoc('g1', {
          'type': 'group',
          'groupKind': 'meetup',
          'closesAt': Timestamp.fromDate(closesAt),
          'closedAt': Timestamp.fromDate(closesAt),
        }),
      );
      expect(entry.closesAt, closesAt);
      expect(entry.closedAt, closesAt);
      expect(entry.isClosedAt(now), isTrue);
    });

    test('一覧のプレビューの閉じる前の知らせの残り時間を読む', () {
      final preview = LastMessagePreview.fromMap({
        'messageId': 'm1',
        'type': 'system',
        'senderId': 'alice',
        'systemType': 'closing_soon',
        'hoursLeft': 1,
      });
      expect(preview.hoursLeft, 1);
    });

    test('閉じる前の知らせの通知から残り時間を読む', () {
      final target = NotificationTarget.fromData({
        'type': 'group_closing',
        'accountId': 'bob',
        'chatRoomId': 'g1',
        'hoursLeft': '24',
        'groupName': 'ボドゲ会',
      });
      expect(target?.closingHoursLeft, 24);
      expect(target?.groupName, 'ボドゲ会');
      expect(
        NotificationTarget.fromData({'type': 'announcement', 'accountId': 'bob', 'chatRoomId': 'g1'})?.closingHoursLeft,
        isNull,
      );
    });
  });

  group('文言', () {
    final ja = lookupAppLocalizations(const Locale('ja'));

    test('システムメッセージ', () {
      String text(String type, {int? hoursLeft}) =>
          groupSystemText(ja, systemType: type, actorName: 'アリス', targetName: 'アリス', hoursLeft: hoursLeft);
      expect(text('close_updated'), 'アリスさんがグループを閉じる日時を変更しました');
      expect(text('closing_soon', hoursLeft: 24), 'このグループは24時間以内に閉じます');
      expect(text('closing_soon', hoursLeft: 1), 'このグループは1時間以内に閉じます');
      expect(text('group_closed'), 'グループは閉じました');
    });

    test('閉じたあとの操作・閉じる日の失敗', () {
      expect(GroupFailure.fromValue('group-closed'), GroupFailure.groupClosed);
      expect(groupFailureMessage(ja, GroupFailure.groupClosed, fallback: 'x'), 'このグループは閉じています');
      expect(groupFailureMessage(ja, GroupFailure.invalidCloseDays, fallback: 'x'), '1時間より後になる日を選んでください');
      expect(FriendRequestFailure.fromValue('group-closed'), FriendRequestFailure.groupClosed);
      expect(friendRequestFailureMessage(ja, FriendRequestFailure.groupClosed, fallback: 'x'), 'このグループは閉じています');
    });
  });

  test('閉じたオフ会グループでは、メンバーの行のメニューを出さない', () {
    const room = GroupRoom(chatRoomId: 'g1', kind: GroupKind.meetup, organizerIds: ['alice']);
    const bob = GroupMember(accountId: 'bob');
    expect(groupMemberActions(room: room, myAccountId: 'alice', member: bob), isNotEmpty);
    expect(groupMemberActions(room: room, myAccountId: 'alice', member: bob, isClosed: true), isEmpty);
  });
}
