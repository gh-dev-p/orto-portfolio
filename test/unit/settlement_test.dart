// オフ会グループの精算の計算・一覧の並び・送金リンクの確かめ（機能仕様書4.7.8.12、データ設計書8.20）
import 'package:flutter_test/flutter_test.dart';
import 'package:multi_id_msg/domain/models/group.dart';
import 'package:multi_id_msg/domain/models/settlement.dart';
import 'package:multi_id_msg/ui/group/widgets/settlement_edit_screen.dart';

void main() {
  group('computeSettlementAmounts（Cloud FunctionsのcomputeAmountsと同じ）', () {
    const entries = [(accountId: 'a', percent: 0), (accountId: 'b', percent: 100), (accountId: 'c', percent: 50)];

    test('合計を割合で分け、端数の単位に切り上げる。割合0の人は0円', () {
      expect(computeSettlementAmounts(10000, 100, entries), {'a': 0, 'b': 6700, 'c': 3400});
      expect(computeSettlementAmounts(10000, 1, entries), {'a': 0, 'b': 6667, 'c': 3334});
    });

    test('割り切れるときは切り上げない', () {
      expect(
        computeSettlementAmounts(9000, 10, const [(accountId: 'a', percent: 100), (accountId: 'b', percent: 100)]),
        {'a': 4500, 'b': 4500},
      );
    });

    test('全員の割合が0なら全員0円', () {
      expect(computeSettlementAmounts(5000, 100, const [(accountId: 'a', percent: 0)]), {'a': 0});
    });

    test('上限の合計と割合でも整数で計算する', () {
      final amounts = computeSettlementAmounts(settlementMaxTotal, 1, const [
        (accountId: 'a', percent: 500),
        (accountId: 'b', percent: 1),
      ]);
      expect(amounts['a']! + amounts['b']!, greaterThanOrEqualTo(settlementMaxTotal));
      expect(amounts['b'], 19961);
    });
  });

  test('SettlementSectionsは確認待ち・未払い・確定・払う額なしに分け、自分を先頭にする', () {
    const shares = [
      SettlementShare(accountId: 'a', tierId: 't', amount: 0),
      SettlementShare(accountId: 'b', tierId: 't', amount: 3000),
      SettlementShare(accountId: 'c', tierId: 't', amount: 3000, status: PaymentStatus.reported),
      SettlementShare(accountId: 'd', tierId: 't', amount: 3000, status: PaymentStatus.confirmed),
      SettlementShare(accountId: 'e', tierId: 't', amount: 3000),
    ];
    final sections = SettlementSections.of(shares, myAccountId: 'e');
    expect(sections.unpaid.map((share) => share.accountId), ['e', 'b']);
    expect(sections.reported.map((share) => share.accountId), ['c']);
    expect(sections.confirmed.map((share) => share.accountId), ['d']);
    expect(sections.free.map((share) => share.accountId), ['a']);
    expect(sections.collected, 12000);
    expect(sections.confirmedAmount, 3000);
  });

  group('normalizeSettlementLink（Cloud FunctionsのparseLinkと同じ決まり）', () {
    const paypay = SettlementLinkService.paypay;
    const other = SettlementLinkService.other;
    const url = SettlementLinkKind.url;
    const id = SettlementLinkKind.paypayId;

    test('PayPayのリンクはpaypay.ne.jpのhttpsだけ', () {
      expect(normalizeSettlementLink(paypay, url, ' https://qr.paypay.ne.jp/abc '), 'https://qr.paypay.ne.jp/abc');
      expect(normalizeSettlementLink(paypay, url, 'http://qr.paypay.ne.jp/abc'), isNull);
      expect(normalizeSettlementLink(paypay, url, 'https://qr.paypay.ne.jp.evil.com/abc'), isNull);
      expect(normalizeSettlementLink(paypay, url, 'https://evil.com/paypay.ne.jp'), isNull);
    });

    test('PayPay IDは英数字と_.-の3〜40文字', () {
      expect(normalizeSettlementLink(paypay, id, 'alice_pay'), 'alice_pay');
      expect(normalizeSettlementLink(paypay, id, 'a b'), isNull);
      expect(normalizeSettlementLink(paypay, id, 'ab'), isNull);
    });

    test('ほかのサービスはhttpsのリンク', () {
      expect(normalizeSettlementLink(other, url, 'https://example.com/pay'), 'https://example.com/pay');
      expect(normalizeSettlementLink(other, url, 'javascript:alert(1)'), isNull);
      expect(normalizeSettlementLink(other, url, 'https://user:pass@example.com'), isNull);
      expect(normalizeSettlementLink(other, id, 'alice'), isNull);
    });
  });

  test('settlementResetCountは額が変わる、未払いでない人を数える', () {
    const current = [
      SettlementShare(accountId: 'a', tierId: 't', amount: 3000, status: PaymentStatus.reported),
      SettlementShare(accountId: 'b', tierId: 't', amount: 3000, status: PaymentStatus.confirmed),
      SettlementShare(accountId: 'c', tierId: 't', amount: 3000),
      SettlementShare(accountId: 'd', tierId: 't', amount: 3000, status: PaymentStatus.confirmed),
    ];
    expect(settlementResetCount(current, {'a': 3500, 'b': 3000, 'c': 3500}), 1);
  });

  test('parseSettlementTotalは1円〜1,000万円', () {
    expect(parseSettlementTotal('0'), isNull);
    expect(parseSettlementTotal('12000'), 12000);
    expect(parseSettlementTotal('10000001'), isNull);
  });

  test('GroupRoomはオフ会グループのときだけ精算の設定を読む', () {
    final data = {
      'groupKind': 'meetup',
      'settlement': {
        'totalAmount': 6000,
        'roundingUnit': 100,
        'tiers': [
          {'tierId': 'std', 'name': '通常', 'percent': 100},
        ],
        'paymentLinks': [
          {'linkId': 'l1', 'service': 'paypay', 'kind': 'paypayId', 'value': 'alice_pay', 'addedBy': 'alice'},
          {'linkId': 'l2', 'service': 'bank', 'kind': 'url', 'value': 'x'},
        ],
      },
    };
    final room = GroupRoom.fromMap('g1', data);
    expect(room.settlement?.totalAmount, 6000);
    expect(room.settlement?.tierOf('std')?.name, '通常');
    expect(room.settlement?.paymentLinks.map((link) => link.linkId), ['l1']);
    expect(GroupRoom.fromMap('g1', {...data, 'groupKind': null}).settlement, isNull);
  });
}
