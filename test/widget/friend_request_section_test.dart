import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multi_id_msg/config/provider_retry.dart';
import 'package:multi_id_msg/config/service_providers.dart';
import 'package:multi_id_msg/data/repositories/friend/friend_request_repository.dart';
import 'package:multi_id_msg/domain/models/account.dart';
import 'package:multi_id_msg/domain/models/friend_request.dart';
import 'package:multi_id_msg/l10n/app_localizations.dart';
import 'package:multi_id_msg/ui/account/view_models/account_providers.dart';
import 'package:multi_id_msg/ui/core/themes/app_theme.dart';
import 'package:multi_id_msg/ui/core/ui/app_bottom_nav.dart';
import 'package:multi_id_msg/ui/friend/widgets/friend_request_section.dart';

// FRI-01の「友だち申請」（画面設計書5.4.1）

class _FakeFriendRequestRepository implements FriendRequestRepository {
  final responded = <(String, bool)>[];

  @override
  Future<void> respond({required String accountId, required String senderAccountId, required bool accept}) async {
    responded.add((senderAccountId, accept));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _requests = [
  FriendRequest(senderAccountId: 'taro', chatRoomId: 'g1', groupName: 'ボドゲ会'),
  FriendRequest(senderAccountId: 'hana', chatRoomId: 'g2', groupName: '飲み会'),
];

Widget _app(Widget child, _FakeFriendRequestRepository repository) => ProviderScope(
  retry: noProviderRetry,
  overrides: [
    friendRequestRepositoryProvider.overrideWithValue(repository),
    accountByIdProvider.overrideWith((ref, id) => Stream.value(Account(id: id, displayName: id.toUpperCase()))),
    isReadOnlyProvider.overrideWith((ref, id) => false),
  ],
  child: MaterialApp(
    theme: AppTheme.light,
    locale: const Locale('ja'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  ),
);

void main() {
  late _FakeFriendRequestRepository repository;

  setUp(() => repository = _FakeFriendRequestRepository());

  testWidgets('件数と「!」を出し、開くと相手の名前とどのグループから来たかを出す（IDは出さない）', (tester) async {
    await tester.pumpWidget(_app(const FriendRequestSection(requests: _requests, myAccountId: 'me'), repository));
    await tester.pump();

    expect(find.text('友だち申請 2件'), findsOneWidget);
    expect(find.text('!'), findsOneWidget);
    expect(find.text('TARO'), findsNothing);

    await tester.tap(find.byKey(const Key('friend-request-section')));
    await tester.pumpAndSettle();

    expect(find.text('TARO'), findsOneWidget);
    expect(find.text('「ボドゲ会」から'), findsOneWidget);
    expect(find.text('HANA'), findsOneWidget);
    expect(find.text('「飲み会」から'), findsOneWidget);
    expect(find.text('taro'), findsNothing);
  });

  testWidgets('承認すると、相手の名前に「さん」を付けて知らせる', (tester) async {
    await tester.pumpWidget(_app(const FriendRequestSection(requests: _requests, myAccountId: 'me'), repository));
    await tester.tap(find.byKey(const Key('friend-request-section')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('friend-request-accept')).first);
    await tester.pumpAndSettle();

    expect(repository.responded, [('taro', true)]);
    expect(find.text('TAROさんと友だちになりました'), findsOneWidget);
  });

  testWidgets('断るときは、相手に知らされないことを確かめてから断る', (tester) async {
    await tester.pumpWidget(_app(const FriendRequestSection(requests: _requests, myAccountId: 'me'), repository));
    await tester.tap(find.byKey(const Key('friend-request-section')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('friend-request-decline')).last);
    await tester.pumpAndSettle();
    expect(find.text('友だち申請を断りますか？'), findsOneWidget);
    expect(find.text('断ったことは相手に知らされません。'), findsOneWidget);

    await tester.tap(find.text('キャンセル'));
    await tester.pumpAndSettle();
    expect(repository.responded, isEmpty);

    await tester.tap(find.byKey(const Key('friend-request-decline')).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('断る').last);
    await tester.pumpAndSettle();
    expect(repository.responded, [('hana', false)]);
  });

  testWidgets('友だち申請が届いている間は、ボトムナビの「友だち」に「!」を出す', (tester) async {
    await tester.pumpWidget(
      _app(
        AppBottomNav(
          currentIndex: 0,
          chatUnreadCount: 0,
          chatHasGroupRequest: false,
          friendHasRequest: true,
          onTap: (_) {},
        ),
        repository,
      ),
    );
    expect(find.text('!'), findsOneWidget);
  });
}
