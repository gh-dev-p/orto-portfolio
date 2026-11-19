// CHA-02の精算の行とGRP-12（機能仕様書4.7.8.12 / 画面設計書5.10.13）
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multi_id_msg/domain/models/group.dart';
import 'package:multi_id_msg/domain/models/settlement.dart';
import 'package:multi_id_msg/l10n/app_localizations.dart';
import 'package:multi_id_msg/ui/core/themes/app_theme.dart';
import 'package:multi_id_msg/ui/group/view_models/group_providers.dart';
import 'package:multi_id_msg/ui/group/widgets/settlement_screen.dart';

const _settlement = Settlement(
  totalAmount: 10000,
  roundingUnit: 100,
  tiers: [SettlementTier(tierId: 'std', name: '通常', percent: 100)],
  paymentLinks: [
    SettlementLink(
      linkId: 'l1',
      service: SettlementLinkService.paypay,
      kind: SettlementLinkKind.paypayId,
      value: 'alice_pay',
      addedBy: 'alice',
    ),
  ],
);

GroupRoom _room({Settlement? settlement, DateTime? closesAt}) => GroupRoom(
  chatRoomId: 'g1',
  kind: GroupKind.meetup,
  organizerIds: const ['alice'],
  participantIds: const ['alice', 'bob'],
  settlement: settlement,
  closesAt: closesAt,
);

Widget _app(Widget home, {required GroupRoom room, String myAccountId = 'bob', SettlementShare? myShare}) =>
    ProviderScope(
      // 同じテストの中で設定を替えて作り直すため、毎回別のものにする
      key: UniqueKey(),
      overrides: [
        groupRoomProvider(room.chatRoomId).overrideWith((ref) => Stream.value(room)),
        mySettlementShareProvider((myAccountId, room.chatRoomId)).overrideWith((ref) => Stream.value(myShare)),
        settlementSharesProvider(room.chatRoomId).overrideWith((ref) => Stream.value(const [])),
      ],
      child: MaterialApp(
        locale: const Locale('ja'),
        theme: AppTheme.light,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: home),
      ),
    );

void main() {
  testWidgets('精算が始まっていれば、自分の額と状態を出す', (tester) async {
    await tester.pumpWidget(
      _app(
        SettlementRow(chatRoomId: 'g1', myAccountId: 'bob', onOpen: () {}),
        room: _room(settlement: _settlement),
        myShare: const SettlementShare(accountId: 'bob', tierId: 'std', amount: 5000),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text('精算：5,000円・未払い'), findsOneWidget);
  });

  testWidgets('精算が無ければ、主催チームにだけ「精算を始める」を出す。閉じたあとは出さない', (tester) async {
    await tester.pumpWidget(
      _app(
        SettlementRow(chatRoomId: 'g1', myAccountId: 'bob', onOpen: () {}),
        room: _room(),
      ),
    );
    await tester.pump();
    expect(find.byKey(const Key('settlement-row')), findsNothing);

    await tester.pumpWidget(
      _app(
        SettlementRow(chatRoomId: 'g1', myAccountId: 'alice', onOpen: () {}),
        room: _room(),
        myAccountId: 'alice',
      ),
    );
    await tester.pump();
    expect(find.text('精算を始める'), findsOneWidget);

    await tester.pumpWidget(
      _app(
        SettlementRow(chatRoomId: 'g1', myAccountId: 'alice', onOpen: () {}),
        room: _room(closesAt: DateTime.now().subtract(const Duration(hours: 1))),
        myAccountId: 'alice',
      ),
    );
    await tester.pump();
    expect(find.byKey(const Key('settlement-row')), findsNothing);
  });

  testWidgets('GRP-12：未払いなら「払った」と送金先を出し、閉じたあとはボタンを出さない', (tester) async {
    const share = SettlementShare(accountId: 'bob', tierId: 'std', amount: 5000);
    await tester.pumpWidget(
      _app(
        const SettlementScreen(chatRoomId: 'g1', myAccountId: 'bob'),
        room: _room(settlement: _settlement),
        myShare: share,
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const Key('settlement-report')), findsOneWidget);
    expect(find.text('PayPay ID：alice_pay'), findsOneWidget);
    expect(find.textContaining('表示名が相手に見えます'), findsOneWidget);
    // 主催チームでない人には、全員の一覧と催促を出さない
    expect(find.byKey(const Key('settlement-remind')), findsNothing);

    await tester.pumpWidget(
      _app(
        const SettlementScreen(chatRoomId: 'g1', myAccountId: 'bob'),
        room: _room(settlement: _settlement, closesAt: DateTime.now().subtract(const Duration(hours: 1))),
        myShare: share,
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const Key('settlement-report')), findsNothing);
  });

  testWidgets('GRP-12：確認待ちなら「払った」を取り消せる', (tester) async {
    await tester.pumpWidget(
      _app(
        const SettlementScreen(chatRoomId: 'g1', myAccountId: 'bob'),
        room: _room(settlement: _settlement),
        myShare: const SettlementShare(
          accountId: 'bob',
          tierId: 'std',
          amount: 5000,
          status: PaymentStatus.reported,
          method: PaymentMethod.cash,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text('確認待ち'), findsOneWidget);
    expect(find.byKey(const Key('settlement-report-cancel')), findsOneWidget);
  });
}
