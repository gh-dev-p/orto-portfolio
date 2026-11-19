import 'package:country_picker/country_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multi_id_msg/config/provider_retry.dart';
import 'package:multi_id_msg/l10n/app_localizations.dart';
import 'package:multi_id_msg/ui/auth/widgets/phone_input_screen.dart';

// AUT-02の同意の案内：サインインのときだけ出し、両方の文書へのリンクを置くこと。
Widget _app({required Locale locale, bool phoneNumberChange = false}) {
  return ProviderScope(
    retry: noProviderRetry,
    child: MaterialApp(
      locale: locale,
      localizationsDelegates: [...AppLocalizations.localizationsDelegates, CountryLocalizations.delegate],
      supportedLocales: AppLocalizations.supportedLocales,
      home: PhoneInputScreen(phoneNumberChange: phoneNumberChange),
    ),
  );
}

void main() {
  testWidgets('サインインでは、同意の案内と2つのリンクを出す', (tester) async {
    await tester.pumpWidget(_app(locale: const Locale('ja')));
    await tester.pumpAndSettle();
    expect(find.text('「次へ」を押すと、利用規約とプライバシーポリシーに同意したものとします。'), findsOneWidget);
    expect(find.widgetWithText(TextButton, '利用規約'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'プライバシーポリシー'), findsOneWidget);
  });

  testWidgets('英語でも案内を出す', (tester) async {
    await tester.pumpWidget(_app(locale: const Locale('en')));
    await tester.pumpAndSettle();
    expect(find.text('By tapping "Next", you agree to the Terms of Service and Privacy Policy.'), findsOneWidget);
  });

  testWidgets('電話番号の変更では、案内を出さない', (tester) async {
    await tester.pumpWidget(_app(locale: const Locale('ja'), phoneNumberChange: true));
    await tester.pumpAndSettle();
    expect(find.byType(TextButton), findsNothing);
  });

  testWidgets('小さい画面でも、はみ出さない', (tester) async {
    tester.view.physicalSize = const Size(320, 320);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_app(locale: const Locale('ja')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
