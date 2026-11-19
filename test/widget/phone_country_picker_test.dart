import 'package:country_picker/country_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multi_id_msg/ui/auth/widgets/phone_input_screen.dart';
import 'package:multi_id_msg/ui/core/ui/app_primary_button.dart';
import 'package:multi_id_msg/l10n/app_localizations.dart';
import 'package:multi_id_msg/config/provider_retry.dart';

// AUT-02の国・地域の選択：選んだ国の番号として入力を検証し直すこと。
Widget _app() {
  return ProviderScope(
    retry: noProviderRetry,
    child: MaterialApp(
      locale: const Locale('ja'),
      localizationsDelegates: [...AppLocalizations.localizationsDelegates, CountryLocalizations.delegate],
      supportedLocales: AppLocalizations.supportedLocales,
      home: const PhoneInputScreen(),
    ),
  );
}

bool _nextEnabled(WidgetTester tester) => tester.widget<AppPrimaryButton>(find.byType(AppPrimaryButton)).enabled;

void main() {
  testWidgets('初期値は日本（+81）で、日本の国内形式の番号を受け付ける', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    expect(find.text('+81'), findsOneWidget);
    expect(_nextEnabled(tester), isFalse);

    await tester.enterText(find.byType(TextField), '090-1234-5678');
    await tester.pump();
    expect(_nextEnabled(tester), isTrue);
  });

  testWidgets('国・地域を選び直すと、その国の番号として検証し直す', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '090-1234-5678');
    await tester.pump();
    expect(_nextEnabled(tester), isTrue);

    await tester.tap(find.text('+81'));
    await tester.pumpAndSettle();
    // 一覧の国名は日本語で表示される
    expect(find.text('日本'), findsWidgets);

    await tester.enterText(find.byType(TextField).last, 'アメリカ');
    await tester.pumpAndSettle();
    await tester.tap(find.text('アメリカ合衆国').first);
    await tester.pumpAndSettle();

    expect(find.text('+1'), findsOneWidget);
    // 日本の番号は、アメリカの番号としては正しくない
    expect(_nextEnabled(tester), isFalse);

    await tester.enterText(find.byType(TextField), '(415) 555-2671');
    await tester.pump();
    expect(_nextEnabled(tester), isTrue);
  });

  testWidgets('+始まりで入力すると、選んだ国・地域にかかわらず受け付ける', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '+1 415 555 2671');
    await tester.pump();
    expect(_nextEnabled(tester), isTrue);
  });
}
