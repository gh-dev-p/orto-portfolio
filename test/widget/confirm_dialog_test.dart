import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multi_id_msg/l10n/app_localizations.dart';
import 'package:multi_id_msg/ui/core/themes/app_theme.dart';
import 'package:multi_id_msg/ui/core/ui/confirm_dialog.dart';

Future<void> _open(WidgetTester tester, ValueSetter<bool> onResult) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('ja'),
      theme: AppTheme.light,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async =>
              onResult(await showConfirmDialog(context, title: '題名', message: '本文', confirmLabel: '削除')),
          child: const Text('開く'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('開く'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('iOS形式のダイアログを出し、実行ならtrueを返す', (tester) async {
    bool? result;
    await _open(tester, (value) => result = value);

    expect(find.byType(CupertinoAlertDialog), findsOneWidget);
    await tester.tap(find.text('削除'));
    await tester.pumpAndSettle();
    expect(result, isTrue);
  });

  testWidgets('キャンセルならfalseを返す', (tester) async {
    bool? result;
    await _open(tester, (value) => result = value);

    await tester.tap(find.text('キャンセル'));
    await tester.pumpAndSettle();
    expect(result, isFalse);
  });

  testWidgets('ダイアログ外のタップでもfalseを返す', (tester) async {
    bool? result;
    await _open(tester, (value) => result = value);

    await tester.tapAt(const Offset(4, 4));
    await tester.pumpAndSettle();
    expect(result, isFalse);
  });
}
