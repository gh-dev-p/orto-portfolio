// オフ会グループの当日の定型連絡（機能仕様書4.7.8.11）
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multi_id_msg/domain/models/chat_room.dart';
import 'package:multi_id_msg/domain/models/group.dart';
import 'package:multi_id_msg/domain/models/message.dart';
import 'package:multi_id_msg/l10n/app_localizations.dart';
import 'package:multi_id_msg/ui/chat/widgets/message_bubble.dart';
import 'package:multi_id_msg/ui/core/themes/app_theme.dart';
import 'package:multi_id_msg/ui/group/view_models/group_providers.dart';
import 'package:multi_id_msg/ui/group/widgets/meetup_status_bar.dart';

Widget _app(Widget home, {List overrides = const [], Locale locale = const Locale('ja')}) => ProviderScope(
  overrides: [...overrides],
  child: MaterialApp(
    locale: locale,
    theme: AppTheme.light,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: home),
  ),
);

GroupRoom _meetup({DateTime? eventAt, GroupKind kind = GroupKind.meetup, DateTime? closesAt, DateTime? closedAt}) =>
    GroupRoom(
      chatRoomId: 'g1',
      kind: kind,
      organizerIds: const ['alice'],
      eventAt: eventAt,
      closesAt: closesAt,
      closedAt: closedAt,
    );

Widget _bar({
  required GroupRoom room,
  required DateTime now,
  bool sending = false,
  ValueChanged<MeetupStatus>? onSend,
}) => _app(
  MeetupStatusBar(chatRoomId: 'g1', sending: sending, onSend: onSend ?? (_) {}, clock: () => now),
  overrides: [groupRoomProvider('g1').overrideWith((ref) => Stream.value(room))],
);

Widget _bubble(Message message, {bool isMine = false}) => MessageBubble(
  message: message,
  isMine: isMine,
  isReadByPeer: false,
  isSelectable: false,
  onRetry: (_) {},
  onLongPress: (_, _) {},
  onOpenImage: (_) {},
  onTapReactions: (_, _) {},
);

Message _status(MeetupStatus? status) => Message(
  id: 'm1',
  senderId: 'bob',
  text: '',
  type: MessageType.meetupStatus,
  meetupStatus: status,
  createdAt: DateTime(2026, 11, 22, 18, 50),
  readBy: const [],
);

void main() {
  group('会の日の範囲（meetupDayOf）', () {
    test('会の日付の0時から、その日の24時まで', () {
      final day = meetupDayOf(DateTime(2026, 11, 22, 13))!;
      expect(day.start, DateTime(2026, 11, 22));
      expect(day.end, DateTime(2026, 11, 23));
    });

    test('夜遅くに始まる会は、会の時刻の6時間後まで（日付をまたぐ）', () {
      final day = meetupDayOf(DateTime(2026, 11, 22, 21))!;
      expect(day.start, DateTime(2026, 11, 22));
      expect(day.end, DateTime(2026, 11, 23, 3));
    });

    test('会の日時が未定ならnull。普通のグループもnull', () {
      expect(meetupDayOf(null), isNull);
      expect(_meetup().meetupDay, isNull);
      expect(_meetup(eventAt: DateTime(2026, 11, 22, 19), kind: GroupKind.standard).meetupDay, isNull);
    });

    test('サーバーの受け付ける前後24時間の内側に入る', () {
      for (final eventAt in [
        DateTime(2026, 11, 22, 0, 1),
        DateTime(2026, 11, 22, 12),
        DateTime(2026, 11, 22, 23, 59),
      ]) {
        final day = meetupDayOf(eventAt)!;
        expect(eventAt.difference(day.start), lessThan(const Duration(hours: 24)));
        expect(day.end.difference(eventAt), lessThan(const Duration(hours: 24)));
      }
    });
  });

  test('当日の定型連絡の種類と中身を読み取る（データ設計書3.3.1・3.2.4）', () {
    expect(MessageType.fromValue('meetupStatus'), MessageType.meetupStatus);
    expect(MeetupStatus.fromValue('late'), MeetupStatus.late);
    expect(MeetupStatus.fromValue('arrived'), MeetupStatus.arrived);
    expect(MeetupStatus.fromValue('notFound'), MeetupStatus.notFound);
    expect(MeetupStatus.fromValue('other'), isNull);
    final preview = LastMessagePreview.fromMap({
      'messageId': 'm1',
      'type': 'meetupStatus',
      'meetupStatus': 'arrived',
      'senderId': 'bob',
    });
    expect(preview.type, MessageType.meetupStatus);
    expect(preview.meetupStatus, MeetupStatus.arrived);
    expect(_status(null).isMeetupStatus, isFalse);
    expect(_status(MeetupStatus.late).isMeetupStatus, isTrue);
  });

  group('ボタンの行（CHA-02）', () {
    final eventAt = DateTime(2026, 11, 22, 19);

    testWidgets('会の日は3つのボタンを出し、押すとその中身を送る', (tester) async {
      final sent = <MeetupStatus>[];
      await tester.pumpWidget(
        _bar(
          room: _meetup(eventAt: eventAt),
          now: DateTime(2026, 11, 22, 8),
          onSend: sent.add,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('遅れます'), findsOneWidget);
      expect(find.text('着きました'), findsOneWidget);
      expect(find.text('見つかりません'), findsOneWidget);
      await tester.tap(find.text('遅れます'));
      await tester.tap(find.text('見つかりません'));
      expect(sent, [MeetupStatus.late, MeetupStatus.notFound]);
    });

    testWidgets('会の日でない・日時が未定・普通のグループには出さない', (tester) async {
      for (final (room, now) in [
        (_meetup(eventAt: eventAt), DateTime(2026, 11, 21, 23, 59)),
        (_meetup(eventAt: eventAt), DateTime(2026, 11, 23, 1)),
        (_meetup(), DateTime(2026, 11, 22, 12)),
        (_meetup(eventAt: eventAt, kind: GroupKind.standard), DateTime(2026, 11, 22, 12)),
      ]) {
        // 前の回のProviderScopeを捨ててから描く
        await tester.pumpWidget(const SizedBox());
        await tester.pumpWidget(_bar(room: room, now: now));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('meetup-status-bar')), findsNothing, reason: '$now');
      }
    });

    testWidgets('閉じたあとは会の日でも出さない（機能仕様書4.7.8.6）', (tester) async {
      final now = DateTime(2026, 11, 22, 20);
      for (final room in [
        _meetup(eventAt: eventAt, closesAt: DateTime(2026, 11, 22, 19, 30)),
        _meetup(eventAt: eventAt, closesAt: DateTime(2026, 11, 25, 19), closedAt: DateTime(2026, 11, 22, 19, 30)),
      ]) {
        await tester.pumpWidget(const SizedBox());
        await tester.pumpWidget(_bar(room: room, now: now));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('meetup-status-bar')), findsNothing);
      }
      // 閉じる前なら出す
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        _bar(
          room: _meetup(eventAt: eventAt, closesAt: DateTime(2026, 11, 25, 19)),
          now: now,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('meetup-status-bar')), findsOneWidget);
    });

    testWidgets('送信中は押せない', (tester) async {
      final sent = <MeetupStatus>[];
      await tester.pumpWidget(
        _bar(
          room: _meetup(eventAt: eventAt),
          now: DateTime(2026, 11, 22, 18),
          sending: true,
          onSend: sent.add,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('着きました'));
      expect(sent, isEmpty);
    });

    testWidgets('英語の文言', (tester) async {
      await tester.pumpWidget(
        _app(
          MeetupStatusBar(chatRoomId: 'g1', sending: false, onSend: (_) {}, clock: () => DateTime(2026, 11, 22, 18)),
          overrides: [groupRoomProvider('g1').overrideWith((ref) => Stream.value(_meetup(eventAt: eventAt)))],
          locale: const Locale('en'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Running late'), findsOneWidget);
      expect(find.text("I'm here"), findsOneWidget);
      expect(find.text("Can't find you"), findsOneWidget);
    });
  });

  group('吹き出し', () {
    testWidgets('アイコンと太字の文言を受け取った側の言語で出す', (tester) async {
      await tester.pumpWidget(_app(_bubble(_status(MeetupStatus.arrived))));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('meetup-status-bubble')), findsOneWidget);
      expect(find.text('着きました'), findsOneWidget);
      expect(find.byIcon(Icons.place_outlined), findsOneWidget);
    });

    testWidgets('中身の読めないものは、更新の案内', (tester) async {
      await tester.pumpWidget(_app(_bubble(_status(null))));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('meetup-status-bubble')), findsNothing);
      expect(find.text('アプリを更新すると表示できます'), findsOneWidget);
    });
  });
}
