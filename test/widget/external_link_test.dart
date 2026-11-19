import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multi_id_msg/utils/external_link.dart';
import 'package:multi_id_msg/l10n/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';

/// [openExternalLink]を呼び出すボタンを持つ最小のアプリ。
Future<void> _pumpApp(
  WidgetTester tester,
  Uri uri,
  Future<bool> Function(Uri, {required LaunchMode mode}) launch,
) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('ja'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => openExternalLink(context, uri, launch: launch),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pump();
  await tester.pump();
}

void main() {
  group('openExternalLink', () {
    testWidgets('起動に成功したらSnackBarを出さない', (tester) async {
      Uri? launched;
      await _pumpApp(tester, Uri.parse('https://example.com/legal'), (uri, {required mode}) async {
        launched = uri;
        return true;
      });

      expect(launched, Uri.parse('https://example.com/legal'));
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('mailto URIをそのまま渡す', (tester) async {
      Uri? launched;
      await _pumpApp(tester, Uri(scheme: 'mailto', path: 'a@example.com'), (uri, {required mode}) async {
        launched = uri;
        return true;
      });

      expect(launched.toString(), 'mailto:a@example.com');
    });

    testWidgets('起動アプリが無くfalseが返ったら、案内のSnackBarを出す', (tester) async {
      await _pumpApp(
        tester,
        Uri.parse('https://example.com/legal'),
        (uri, {required mode}) async => false,
      );

      expect(find.text('開けませんでした'), findsOneWidget);
    });

    testWidgets('起動が例外を投げても、案内のSnackBarを出す', (tester) async {
      await _pumpApp(
        tester,
        Uri.parse('https://example.com/legal'),
        (uri, {required mode}) async => throw Exception('no handler'),
      );

      expect(find.text('開けませんでした'), findsOneWidget);
    });
  });
}
