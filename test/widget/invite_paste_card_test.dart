// AUT-02の招待の貼り付けボタンの案内（機能仕様書4.3.5.2）：状態ごとの表示。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multi_id_msg/config/preferences_provider.dart';
import 'package:multi_id_msg/config/provider_retry.dart';
import 'package:multi_id_msg/l10n/app_localizations.dart';
import 'package:multi_id_msg/ui/core/themes/app_colors.dart';
import 'package:multi_id_msg/ui/core/themes/app_theme.dart';
import 'package:multi_id_msg/ui/friend/view_models/invite_link_provider.dart';
import 'package:multi_id_msg/ui/friend/widgets/invite_paste_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<ProviderContainer> _pump(WidgetTester tester, InvitePasteStatus status, {String? pending}) async {
  SharedPreferences.setMockInitialValues({'pendingInviteAccountId': ?pending});
  final container = ProviderContainer(
    retry: noProviderRetry,
    overrides: [sharedPreferencesProvider.overrideWithValue(await SharedPreferences.getInstance())],
  );
  addTearDown(container.dispose);
  container.read(invitePasteProvider.notifier).set(status);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.light,
        locale: const Locale('ja'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(body: InvitePasteCard()),
      ),
    ),
  );
  return container;
}

void main() {
  testWidgets('出さない状態では何も出さない', (tester) async {
    await _pump(tester, InvitePasteStatus.hidden);
    expect(find.text('招待リンクから来ましたか？'), findsNothing);
  });

  testWidgets('出している状態では案内を出し、閉じられる', (tester) async {
    final container = await _pump(tester, InvitePasteStatus.offered);
    expect(find.text('招待リンクから来ましたか？'), findsOneWidget);
    await tester.tap(find.byTooltip('閉じる'));
    await tester.pump();
    expect(container.read(invitePasteProvider), InvitePasteStatus.hidden);
    expect(find.text('招待リンクから来ましたか？'), findsNothing);
  });

  testWidgets('招待リンクでなければ、そう知らせる', (tester) async {
    await _pump(tester, InvitePasteStatus.notInvite);
    expect(find.text('招待リンクではありませんでした'), findsOneWidget);
  });

  testWidgets('受け取ったら、招待したアカウントのIDを出す', (tester) async {
    await _pump(tester, InvitePasteStatus.received, pending: 'friend');
    expect(find.text('招待を受け取りました'), findsOneWidget);
    expect(find.textContaining('friend'), findsOneWidget);
  });

  testWidgets('招待リンクで開いた後は、貼り付けの案内を出さない', (tester) async {
    await _pump(tester, InvitePasteStatus.offered, pending: 'friend');
    expect(find.text('招待リンクから来ましたか？'), findsNothing);
  });

  testWidgets('受け取ったら、印をつけ、貼り付けボタンは出さない', (tester) async {
    await _pump(tester, InvitePasteStatus.received, pending: 'friend');
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
    expect(find.byType(InvitePasteButton), findsNothing);
  });

  group('貼り付けボタンの文字が読める', () {
    /// 2色のコントラスト比（WCAG）
    double contrast(Color a, Color b) {
      final la = a.computeLuminance();
      final lb = b.computeLuminance();
      return (la > lb ? la + 0.05 : lb + 0.05) / (la > lb ? lb + 0.05 : la + 0.05);
    }

    test('ライト：アクセントの背景に白字で、4.5以上', () {
      final colors = invitePasteButtonColors(AppColors.light, Brightness.light);
      expect(colors.background, AppColors.light.accent);
      expect(colors.foreground, AppColors.light.onAccent);
      expect(contrast(colors.background, colors.foreground), greaterThanOrEqualTo(4.5));
    });

    test('ダーク：淡いアクセントの背景に暗い字で、4.5以上', () {
      final colors = invitePasteButtonColors(AppColors.dark, Brightness.dark);
      expect(colors.background, AppColors.dark.accent);
      expect(contrast(colors.background, colors.foreground), greaterThanOrEqualTo(4.5));
      // 以前の白字では読みにくかった
      expect(contrast(AppColors.dark.accent, AppColors.dark.onAccent), lessThan(4.5));
    });
  });
}
