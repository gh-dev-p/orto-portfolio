// CHA-02の出欠の行（機能仕様書4.7.8.9 / 画面設計書5.10.11）と、定員のダイアログ（4.7.8.10）
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multi_id_msg/domain/models/group.dart';
import 'package:multi_id_msg/l10n/app_localizations.dart';
import 'package:multi_id_msg/ui/core/themes/app_theme.dart';
import 'package:multi_id_msg/ui/group/view_models/group_providers.dart';
import 'package:multi_id_msg/ui/group/widgets/attendance_screen.dart';
import 'package:multi_id_msg/ui/group/widgets/capacity_dialog.dart';

Widget _app(Widget home, {required GroupRoom room, List<GroupAttendance> answers = const []}) => ProviderScope(
  overrides: [
    groupRoomProvider(room.chatRoomId).overrideWith((ref) => Stream.value(room)),
    groupAttendanceProvider(room.chatRoomId).overrideWith((ref) => Stream.value(answers)),
  ],
  child: MaterialApp(
    locale: const Locale('ja'),
    theme: AppTheme.light,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: home),
  ),
);

GroupRoom _room({int? capacity, DateTime? deadline, DateTime? closesAt}) => GroupRoom(
  chatRoomId: 'g1',
  kind: GroupKind.meetup,
  organizerIds: const ['alice'],
  participantIds: const ['alice', 'bob', 'carol'],
  capacity: capacity,
  attendanceDeadline: deadline,
  closesAt: closesAt,
);

bool _isFilled(WidgetTester tester, String key) => tester.widget(find.byKey(Key(key))) is FilledButton;

void main() {
  testWidgets('集計と締切を出し、自分の答えを塗りつぶす', (tester) async {
    await tester.pumpWidget(
      _app(
        AttendanceRow(chatRoomId: 'g1', myAccountId: 'bob', onOpen: () {}),
        room: _room(deadline: DateTime(2020, 1, 1, 21)),
        answers: const [
          GroupAttendance(accountId: 'bob', response: AttendanceResponse.no),
          GroupAttendance(accountId: 'alice', response: AttendanceResponse.yes),
        ],
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('参加 1・不参加 1・未回答 1'), findsOneWidget);
    expect(find.textContaining('締切 2020年1月1日'), findsOneWidget);
    expect(find.textContaining('締切済み'), findsOneWidget);
    expect(_isFilled(tester, 'attendance-no'), isTrue);
    expect(_isFilled(tester, 'attendance-yes'), isFalse);
  });

  testWidgets('締切なしなら締切を出さない。行を押すとGRP-11を開く処理を呼ぶ', (tester) async {
    var opened = false;
    await tester.pumpWidget(
      _app(
        AttendanceRow(chatRoomId: 'g1', myAccountId: 'bob', onOpen: () => opened = true),
        room: _room(),
      ),
    );
    await tester.pump();

    expect(find.text('参加 0・不参加 0・未回答 3'), findsOneWidget);
    expect(find.textContaining('締切'), findsNothing);
    await tester.tap(find.byKey(const Key('attendance-summary')));
    expect(opened, isTrue);
  });

  testWidgets('閉じたオフ会グループでは答えを塗って見せるだけで、押せない（機能仕様書4.7.8.6）', (tester) async {
    await tester.pumpWidget(
      _app(
        AttendanceRow(chatRoomId: 'g1', myAccountId: 'bob', onOpen: () {}),
        room: _room(closesAt: DateTime.now().subtract(const Duration(hours: 1))),
        answers: const [GroupAttendance(accountId: 'bob', response: AttendanceResponse.yes)],
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(_isFilled(tester, 'attendance-yes'), isTrue);
    expect(tester.widget<FilledButton>(find.byKey(const Key('attendance-yes'))).onPressed, isNull);
    expect(tester.widget<OutlinedButton>(find.byKey(const Key('attendance-no'))).onPressed, isNull);
  });

  testWidgets('GRP-11：閉じたあとは主催チームにも締切・催促の操作を出さない', (tester) async {
    await tester.pumpWidget(
      _app(
        const AttendanceScreen(chatRoomId: 'g1', myAccountId: 'alice'),
        room: _room(closesAt: DateTime.now().subtract(const Duration(hours: 1))),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const Key('attendance-screen')), findsOneWidget);
    expect(find.byKey(const Key('attendance-remind')), findsNothing);
    expect(tester.widget<ListTile>(find.byKey(const Key('attendance-deadline'))).onTap, isNull);
  });

  testWidgets('定員のダイアログ：範囲外は保存できず、メンバーより少ないと注意を出す', (tester) async {
    final room = _room(capacity: 10);
    await tester.pumpWidget(
      _app(
        CapacityTile(room: room, myAccountId: 'alice', memberCount: 3),
        room: room,
      ),
    );
    await tester.pump();
    expect(find.text('10人'), findsOneWidget);

    await tester.tap(find.byKey(const Key('group-capacity')));
    await tester.pumpAndSettle();
    TextButton save() => tester.widget<TextButton>(find.byKey(const Key('capacity-save')));
    expect(save().onPressed, isNotNull);

    await tester.enterText(find.byKey(const Key('capacity-field')), '1');
    await tester.pump();
    expect(save().onPressed, isNull);
    expect(find.text('定員は2〜100人にしてください'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('capacity-field')), '2');
    await tester.pump();
    expect(save().onPressed, isNotNull);
    expect(find.textContaining('今のメンバーは3人です'), findsOneWidget);
  });
}
