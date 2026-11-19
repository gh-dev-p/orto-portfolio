// GRP-06 グループの種類（機能仕様書4.7.8.1）とオフ会グループの印
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multi_id_msg/l10n/app_localizations.dart';
import 'package:multi_id_msg/ui/core/themes/app_theme.dart';
import 'package:multi_id_msg/ui/group/widgets/group_kind_screen.dart';
import 'package:multi_id_msg/ui/group/widgets/meetup_badge.dart';
import 'package:multi_id_msg/ui/group/widgets/meetup_closed_bar.dart';

Widget _app(Widget home) => ProviderScope(
  child: MaterialApp(
    locale: const Locale('ja'),
    theme: AppTheme.light,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: home),
  ),
);

void main() {
  testWidgets('普通のグループとオフ会グループを説明つきで並べ、変えられない旨を出す', (tester) async {
    await tester.pumpWidget(_app(const GroupKindScreen(myAccountId: 'me')));

    expect(find.text('グループの種類'), findsOneWidget);
    expect(find.text('普通のグループ'), findsOneWidget);
    expect(find.text('友だちや仲間と話すグループです。全員が同じことをできます。'), findsOneWidget);
    expect(find.text('オフ会グループ'), findsOneWidget);
    expect(find.text('オフ会やイベントのためのグループです。主催チームがメンバーの管理やお知らせをします。会が終わると閉じます。'), findsOneWidget);
    expect(find.text('種類はあとから変えられません'), findsOneWidget);
    expect(
      tester.getTopLeft(find.byKey(const Key('group-kind-standard'))).dy,
      lessThan(tester.getTopLeft(find.byKey(const Key('group-kind-meetup'))).dy),
    );
  });

  testWidgets('オフ会の印は、日時が決まるまで「日時未定」を出す', (tester) async {
    await tester.pumpWidget(_app(const Column(children: [MeetupBadge(), MeetupBadge(daysLeft: 3)])));

    expect(find.text('オフ会'), findsNWidgets(2));
    expect(find.text('日時未定'), findsOneWidget);
    expect(find.text('あと3日'), findsOneWidget);
  });

  testWidgets('閉じたオフ会グループの印は「終了」、入力欄の代わりに消える日付を出す', (tester) async {
    await tester.pumpWidget(
      _app(
        Column(
          children: [
            const MeetupBadge(isClosed: true),
            MeetupClosedBar(closesAt: DateTime(2026, 11, 25, 19)),
            const MeetupClosedBar(closesAt: null),
          ],
        ),
      ),
    );

    expect(find.text('終了'), findsOneWidget);
    expect(find.text('このグループは閉じました。2026年12月25日(金)に記録が消えます'), findsOneWidget);
    expect(find.text('このグループは閉じました'), findsOneWidget);
  });

  testWidgets('閉じたあとの案内に、次の回を作れる人だけ［次の回を作る］を出す', (tester) async {
    var tapped = 0;
    await tester.pumpWidget(
      _app(
        Column(
          children: [
            MeetupClosedBar(closesAt: DateTime(2026, 11, 25, 19), onCreateNextRound: () => tapped++),
            const MeetupClosedBar(closesAt: null),
          ],
        ),
      ),
    );

    expect(find.text('次の回を作る'), findsOneWidget);
    await tester.tap(find.byKey(const Key('meetup-closed-next-round')));
    expect(tapped, 1);
  });
}
