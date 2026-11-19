import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multi_id_msg/ui/auth/widgets/splash_screen.dart';
import 'package:multi_id_msg/l10n/app_localizations.dart';

Widget _app(Widget home) => MaterialApp(
      locale: const Locale('ja'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    );

void main() {
  testWidgets('読み込み中は不定進捗のバーを表示し、丸スピナーは出さない', (tester) async {
    await tester.pumpWidget(_app(const SplashScreen()));

    final bar = tester.widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator));
    expect(bar.value, isNull);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('読み込み中…'), findsNothing);

    // ロゴ（タイトル）の下に置かれる。
    final title = tester.getBottomLeft(find.text('Orto')).dy;
    expect(tester.getTopLeft(find.byType(LinearProgressIndicator)).dy, greaterThan(title));
    // 幅は最大200dpに抑える。
    expect(tester.getSize(find.byKey(const Key('splash-progress-bar'))).width, lessThanOrEqualTo(200));

    // 1.5秒経つまでは、テキストを出さない。
    await tester.pump(const Duration(milliseconds: 1400));
    expect(find.text('読み込み中…'), findsNothing);

    // 1.5秒以上続くと、バーの下に「読み込み中…」を追加表示する。
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('読み込み中…'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('読み込み中…')).dy,
      greaterThan(tester.getBottomLeft(find.byType(LinearProgressIndicator)).dy),
    );
  });

  testWidgets('エラー時はバーを出さず、再試行ボタンを表示する', (tester) async {
    var retried = false;
    await tester.pumpWidget(_app(SplashScreen(error: '失敗しました', onRetry: () => retried = true)));

    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.text('失敗しました'), findsOneWidget);
    await tester.tap(find.byType(OutlinedButton));
    expect(retried, isTrue);
  });
}
