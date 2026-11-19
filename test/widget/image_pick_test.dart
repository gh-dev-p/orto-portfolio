import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:multi_id_msg/utils/image_pick.dart';
import 'package:multi_id_msg/l10n/app_localizations.dart';

/// [pickImageSafely]を呼び出すボタンを持つ最小のアプリ。結果は[result]に入る。
Future<void> _pumpApp(WidgetTester tester, Future<XFile?> Function() pick, List<XFile?> result) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('ja'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async => result.add(await pickImageSafely(context, ImageSource.gallery, pick: pick)),
            child: const Text('pick'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('pick'));
  await tester.pump();
  await tester.pump();
}

void main() {
  group('pickImageSafely', () {
    testWidgets('選択に成功したら、そのまま返しSnackBarは出さない', (tester) async {
      final file = XFile('a.png');
      final result = <XFile?>[];
      await _pumpApp(tester, () async => file, result);

      expect(result, [file]);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('キャンセル（null）ではSnackBarを出さない', (tester) async {
      final result = <XFile?>[];
      await _pumpApp(tester, () async => null, result);

      expect(result, [null]);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('写真の権限拒否では、写真の案内を出してnullを返す', (tester) async {
      final result = <XFile?>[];
      await _pumpApp(tester, () async => throw PlatformException(code: 'photo_access_denied'), result);

      expect(result, [null]);
      expect(find.textContaining('写真へのアクセスが許可されていません'), findsOneWidget);
    });

    testWidgets('カメラの権限拒否では、カメラの案内を出してnullを返す', (tester) async {
      final result = <XFile?>[];
      await _pumpApp(tester, () async => throw PlatformException(code: 'camera_access_denied'), result);

      expect(result, [null]);
      expect(find.textContaining('カメラの利用が許可されていません'), findsOneWidget);
    });

    testWidgets('権限拒否以外の失敗では、汎用の案内を出してnullを返す', (tester) async {
      final result = <XFile?>[];
      await _pumpApp(tester, () async => throw PlatformException(code: 'unknown'), result);

      expect(result, [null]);
      expect(find.textContaining('画像を選択できませんでした'), findsOneWidget);
    });
  });

  group('pickImageForUpload', () {
    Future<void> pump(WidgetTester tester, Future<File> Function(File) sanitize, List<XFile?> result) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('ja'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async => result.add(
                  await pickImageForUpload(
                    context,
                    ImageSource.gallery,
                    pick: () async => XFile('original.jpg'),
                    sanitize: sanitize,
                  ),
                ),
                child: const Text('pick'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('pick'));
      await tester.pump();
      await tester.pump();
    }

    testWidgets('メタデータを消したファイルを返す', (tester) async {
      final result = <XFile?>[];
      await pump(tester, (source) async => File('clean.jpg'), result);

      expect(result.single?.path, 'clean.jpg');
    });

    testWidgets('消せなければ元のファイルを返さず、SnackBarを出す', (tester) async {
      final result = <XFile?>[];
      await pump(tester, (source) async => throw StateError('failed'), result);

      expect(result, [null]);
      expect(find.byType(SnackBar), findsOneWidget);
    });
  });
}
