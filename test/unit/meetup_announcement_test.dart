// オフ会グループのお知らせと会の日時（機能仕様書4.7.8.4、データ設計書8.15）
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:multi_id_msg/domain/models/announcement.dart';
import 'package:multi_id_msg/domain/models/group.dart';
import 'package:multi_id_msg/domain/models/notification_target.dart';
import 'package:multi_id_msg/l10n/app_localizations.dart';
import 'package:multi_id_msg/ui/group/widgets/group_failure_message.dart';
import 'package:multi_id_msg/ui/group/widgets/group_system_text.dart';
import 'package:multi_id_msg/ui/group/widgets/meetup_event_screen.dart';
import 'package:multi_id_msg/utils/date_format_utils.dart';

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
  setUpAll(() async {
    await initializeDateFormatting('ja');
    await initializeDateFormatting('en');
  });

  test('ルームから会の日時と場所を読み取る。普通のグループは持たない', () {
    final eventAt = DateTime(2026, 11, 22, 19);
    final meetup = GroupRoom.fromMap('g1', {
      'groupKind': 'meetup',
      'organizerIds': ['alice'],
      'eventAt': Timestamp.fromDate(eventAt),
      'eventPlace': '渋谷 ○○店',
    });
    expect(meetup.eventAt, eventAt);
    expect(meetup.eventPlace, '渋谷 ○○店');
    final undecided = GroupRoom.fromMap('g1', {
      'groupKind': 'meetup',
      'organizerIds': ['alice'],
    });
    expect(undecided.eventAt, isNull);
    expect(undecided.eventPlace, isNull);
    final standard = GroupRoom.fromMap('g1', {'eventAt': Timestamp.fromDate(eventAt), 'eventPlace': 'x'});
    expect(standard.eventAt, isNull);
    expect(standard.eventPlace, isNull);
  });

  test('お知らせを読み取る。空の場所は無いものとする', () {
    final at = DateTime(2026, 11, 16, 12);
    final announcement = Announcement.fromFirestore(
      _FakeDoc('a1', {
        'announcementId': 'a1',
        'text': '集合は改札前',
        'place': '渋谷駅',
        'createdBy': 'alice',
        'createdAt': Timestamp.fromDate(at),
        'updatedAt': Timestamp.fromDate(at),
      }),
    );
    expect(announcement.announcementId, 'a1');
    expect(announcement.text, '集合は改札前');
    expect(announcement.place, '渋谷駅');
    expect(announcement.createdBy, 'alice');
    expect(announcement.createdAt, at);
    expect(Announcement.fromFirestore(_FakeDoc('a2', {'text': 'x', 'place': ''})).place, isNull);
  });

  test('地図アプリの検索のURLは、場所の文字をそのまま検索語にする', () {
    expect(
      MapSearchLinks.apple('渋谷 ○○店').toString(),
      'https://maps.apple.com/?q=%E6%B8%8B%E8%B0%B7+%E2%97%8B%E2%97%8B%E5%BA%97',
    );
    expect(MapSearchLinks.apple('A&B').queryParameters['q'], 'A&B');
    final google = MapSearchLinks.google('東京都渋谷区1-2-3');
    expect(google.host, 'www.google.com');
    expect(google.path, '/maps/search/');
    expect(google.queryParameters, {'api': '1', 'query': '東京都渋谷区1-2-3'});
    expect(MapSearchLinks.geo('A&B').toString(), 'geo:0,0?q=A%26B');
  });

  test('会の日時の表示。今年でなければ年を付ける', () {
    final now = DateTime(2026, 11, 16);
    expect(formatEventDateTime(DateTime(2026, 11, 22, 19, 5), 'ja', now: now), '11月22日(日) 19:05');
    expect(formatEventDateTime(DateTime(2027, 1, 5, 9), 'ja', now: now), '2027年1月5日(火) 09:00');
    expect(formatEventDateTime(DateTime(2026, 11, 22, 19), 'en', now: now), 'Sun, Nov 22, 7:00\u202fPM');
    expect(formatEventDateTime(DateTime(2027, 1, 5, 9), 'en', now: now), 'Tue, Jan 5, 2027, 9:00\u202fAM');
  });

  test('会の日時に選べる範囲は、今より後の5分刻みから1年後まで', () {
    final range = MeetupEventScreen.selectableRange(DateTime(2026, 11, 16, 12, 3, 30));
    expect(range.min, DateTime(2026, 11, 16, 12, 5));
    expect(range.max, DateTime(2027, 11, 16, 12, 5));
    expect(MeetupEventScreen.selectableRange(DateTime(2026, 11, 16, 12, 5)).min, DateTime(2026, 11, 16, 12, 10));
  });

  test('システムメッセージの文。名前に「さん」を付ける', () {
    final l10n = lookupAppLocalizations(const Locale('ja'));
    expect(groupSystemText(l10n, systemType: 'announcement_posted', actorName: 'A', targetName: ''), 'Aさんがお知らせを追加しました');
    expect(groupSystemText(l10n, systemType: 'event_updated', actorName: 'A', targetName: ''), 'Aさんが会の日時・場所を更新しました');
    expect(
      groupSystemText(l10n, systemType: 'event_updated', actorName: l10n.commonDeletedAccount, targetName: ''),
      '退会済みアカウントが会の日時・場所を更新しました',
    );
    final en = lookupAppLocalizations(const Locale('en'));
    expect(
      groupSystemText(en, systemType: 'announcement_posted', actorName: 'A', targetName: ''),
      'A added an announcement',
    );
  });

  test('お知らせの失敗の理由を読み取り、文言を出し分ける', () {
    final l10n = lookupAppLocalizations(const Locale('ja'));
    expect(GroupFailure.fromValue('announcement-limit'), GroupFailure.announcementLimit);
    expect(GroupFailure.fromValue('announcement-not-found'), GroupFailure.announcementNotFound);
    expect(GroupFailure.fromValue('invalid-event-at'), GroupFailure.invalidEventAt);
    expect(
      groupFailureMessage(l10n, GroupFailure.announcementLimit, fallback: 'x'),
      'お知らせは20件までです。古いお知らせを削除してから追加してください。',
    );
    expect(groupFailureMessage(l10n, GroupFailure.announcementNotFound, fallback: 'x'), 'このお知らせは削除されています');
    expect(groupFailureMessage(l10n, GroupFailure.invalidEventAt, fallback: 'x'), '今より後の日時を選んでください');
  });

  test('お知らせの通知はグループのトークを開き、バナーの文言を変える', () {
    final target = NotificationTarget.fromData({'type': 'announcement', 'accountId': 'bob', 'chatRoomId': 'g1'})!;
    expect(target.isAnnouncement, isTrue);
    expect(target.isGroupInvite, isFalse);
    expect(target.peerAccountId, isNull);
    expect(lookupAppLocalizations(const Locale('ja')).pushAnnouncementBanner, 'お知らせがあります');
  });
}
