// オフ会グループのお知らせの枠・GRP-07・メッセージの長押しの「お知らせにする」（機能仕様書4.7.8.4）
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:multi_id_msg/domain/models/announcement.dart';
import 'package:multi_id_msg/domain/models/group.dart';
import 'package:multi_id_msg/l10n/app_localizations.dart';
import 'package:multi_id_msg/ui/account/view_models/account_providers.dart';
import 'package:multi_id_msg/ui/chat/widgets/message_actions_menu.dart';
import 'package:multi_id_msg/ui/core/themes/app_theme.dart';
import 'package:multi_id_msg/ui/group/view_models/announcement_providers.dart';
import 'package:multi_id_msg/ui/group/view_models/group_providers.dart';
import 'package:multi_id_msg/ui/group/widgets/announcement_edit_screen.dart';
import 'package:multi_id_msg/ui/group/widgets/meetup_announcement_panel.dart';

Widget _app(Widget home, {List overrides = const []}) => ProviderScope(
  overrides: [...overrides],
  child: MaterialApp(
    locale: const Locale('ja'),
    theme: AppTheme.light,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: home),
  ),
);

Announcement _announcement(String id, String text, {String? place}) => Announcement(
  announcementId: id,
  text: text,
  place: place,
  createdBy: 'alice',
  updatedAt: DateTime(2026, 11, 1, 10),
);

Widget _panel({required GroupRoom room, List<Announcement> announcements = const []}) => _app(
  MeetupAnnouncementPanel(chatRoomId: 'g1', myAccountId: 'me', push: (_) async {}),
  overrides: [
    groupRoomProvider('g1').overrideWith((ref) => Stream.value(room)),
    meetupAnnouncementsProvider('g1').overrideWith((ref) => Stream.value(announcements)),
    isReadOnlyProvider('me').overrideWithValue(false),
  ],
);

void main() {
  setUpAll(() async => initializeDateFormatting('ja'));

  testWidgets('会の日時と場所が未定なら「日時未定」「場所未定」。主催チームでない人には編集・追加を出さない', (tester) async {
    await tester.pumpWidget(
      _panel(
        room: const GroupRoom(chatRoomId: 'g1', kind: GroupKind.meetup, organizerIds: ['alice']),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('日時未定'), findsOneWidget);
    expect(find.text('場所未定'), findsOneWidget);
    expect(find.byKey(const Key('meetup-event-edit')), findsNothing);
    expect(find.byKey(const Key('meetup-announcement-add')), findsNothing);
    expect(find.byKey(const Key('meetup-announcement-toggle')), findsNothing);
  });

  testWidgets('主催チームには編集のボタンと、0件なら「お知らせを追加」を出す', (tester) async {
    final eventAt = DateTime(DateTime.now().year, 12, 24, 19);
    await tester.pumpWidget(
      _panel(
        room: GroupRoom(
          chatRoomId: 'g1',
          kind: GroupKind.meetup,
          organizerIds: const ['me'],
          eventAt: eventAt,
          eventPlace: '渋谷 ○○店',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('meetup-event-date-text')), findsOneWidget);
    expect(find.textContaining('12月24日'), findsOneWidget);
    expect(find.text('渋谷 ○○店'), findsOneWidget);
    expect(find.byKey(const Key('meetup-event-edit')), findsOneWidget);
    expect(find.text('お知らせを追加'), findsOneWidget);
  });

  testWidgets('ほかのお知らせはたたんで件数を出し、押すと新しい順に広がる', (tester) async {
    await tester.pumpWidget(
      _panel(
        room: const GroupRoom(chatRoomId: 'g1', kind: GroupKind.meetup, organizerIds: ['alice']),
        announcements: [
          _announcement('a2', '持ち物：ボドゲ1つ'),
          _announcement('a1', '集合は改札前', place: '渋谷駅'),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('お知らせ 2件'), findsOneWidget);
    expect(find.text('集合は改札前'), findsNothing);

    await tester.tap(find.byKey(const Key('meetup-announcement-toggle')));
    await tester.pump();

    expect(find.text('持ち物：ボドゲ1つ'), findsOneWidget);
    expect(find.text('集合は改札前'), findsOneWidget);
    expect(find.text('渋谷駅'), findsOneWidget);
    expect(tester.getTopLeft(find.text('持ち物：ボドゲ1つ')).dy, lessThan(tester.getTopLeft(find.text('集合は改札前')).dy));
    // 主催チームでない人には「…」と「お知らせを追加」を出さない
    expect(find.byKey(const Key('announcement-menu-a1')), findsNothing);
    expect(find.byKey(const Key('meetup-announcement-add')), findsNothing);

    await tester.tap(find.byKey(const Key('meetup-announcement-toggle')));
    await tester.pump();
    expect(find.text('集合は改札前'), findsNothing);
  });

  testWidgets('主催チームには、広げた中に各お知らせの「…」と「お知らせを追加」を出す', (tester) async {
    await tester.pumpWidget(
      _panel(
        room: const GroupRoom(chatRoomId: 'g1', kind: GroupKind.meetup, organizerIds: ['me']),
        announcements: [_announcement('a1', '集合は改札前')],
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('meetup-announcement-toggle')));
    await tester.pump();

    expect(find.byKey(const Key('announcement-menu-a1')), findsOneWidget);
    expect(find.byKey(const Key('meetup-announcement-add')), findsOneWidget);
    await tester.tap(find.byKey(const Key('announcement-menu-a1')));
    await tester.pumpAndSettle();
    expect(find.text('編集'), findsOneWidget);
    expect(find.text('削除'), findsOneWidget);
  });

  testWidgets('普通のグループには枠を出さない', (tester) async {
    await tester.pumpWidget(_panel(room: const GroupRoom(chatRoomId: 'g1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('meetup-announcement-panel')), findsNothing);
  });

  testWidgets('GRP-07：新しく出すときは通知が既定でオン、本文が空なら投稿できない', (tester) async {
    await tester.pumpWidget(_app(const AnnouncementEditScreen(chatRoomId: 'g1', myAccountId: 'me')));
    await tester.pump();

    expect(find.text('お知らせを追加'), findsOneWidget);
    expect(tester.widget<SwitchListTile>(find.byKey(const Key('notify-members'))).value, isTrue);
    expect(tester.widget<TextButton>(find.byKey(const Key('announcement-save'))).onPressed, isNull);
    await tester.enterText(find.byKey(const Key('announcement-text')), '  集合は改札前 ');
    await tester.pump();
    expect(tester.widget<TextButton>(find.byKey(const Key('announcement-save'))).onPressed, isNotNull);
  });

  testWidgets('GRP-07：直すときは通知が既定でオフで、本文と場所が入っている', (tester) async {
    await tester.pumpWidget(
      _app(
        AnnouncementEditScreen(
          chatRoomId: 'g1',
          myAccountId: 'me',
          announcement: _announcement('a1', '集合は改札前', place: '渋谷駅'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('お知らせを編集'), findsOneWidget);
    expect(find.text('保存'), findsOneWidget);
    expect(find.text('集合は改札前'), findsOneWidget);
    expect(find.text('渋谷駅'), findsOneWidget);
    expect(tester.widget<SwitchListTile>(find.byKey(const Key('notify-members'))).value, isFalse);
  });

  testWidgets('GRP-07：メッセージからは本文を入れて開き、上限の1000文字に収める', (tester) async {
    await tester.pumpWidget(_app(AnnouncementEditScreen(chatRoomId: 'g1', myAccountId: 'me', initialText: 'あ' * 1200)));
    await tester.pumpAndSettle();
    final field = tester.widget<TextField>(find.byKey(const Key('announcement-text')));
    expect(field.controller!.text.length, 1000);
  });

  testWidgets('長押しメニュー：「お知らせにする」は指定したときだけ先頭に出す', (tester) async {
    final l10n = lookupAppLocalizations(const Locale('ja'));
    await tester.pumpWidget(
      _app(MessageActionsMenu(isMine: false, isImage: false, canAnnounce: true, l10n: l10n, onSelect: (_) {})),
    );
    expect(find.text('お知らせにする'), findsOneWidget);
    expect(tester.getTopLeft(find.text('お知らせにする')).dx, lessThan(tester.getTopLeft(find.text('コピー')).dx));
    await tester.pumpWidget(_app(MessageActionsMenu(isMine: false, isImage: false, l10n: l10n, onSelect: (_) {})));
    expect(find.text('お知らせにする'), findsNothing);
  });
}
