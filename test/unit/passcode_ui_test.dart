import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multi_id_msg/ui/passcode/widgets/passcode_entry_screen.dart';
import 'package:multi_id_msg/ui/passcode/widgets/passcode_guard.dart';
import 'package:multi_id_msg/ui/settings/widgets/passcode_setup_screen.dart';
import 'package:multi_id_msg/l10n/app_localizations.dart';
import 'package:multi_id_msg/data/services/passcode/passcode_store.dart';
import 'package:multi_id_msg/ui/account/view_models/account_providers.dart';
import 'package:multi_id_msg/ui/account/view_models/active_account_provider.dart';
import 'package:multi_id_msg/ui/passcode/view_models/passcode_providers.dart';
import 'package:multi_id_msg/ui/settings/view_models/passcode_setup_viewmodel.dart';
import 'package:multi_id_msg/config/preferences_provider.dart';
import 'package:multi_id_msg/config/service_providers.dart';
import 'package:multi_id_msg/config/provider_retry.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MemoryStorage implements PasscodeStorage {
  final values = <String, String>{};

  /// trueの間、書き込みが失敗する（保存領域の異常を模す）。
  bool failWrites = false;

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    if (failWrites) throw Exception('write failed');
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async => values.remove(key);

  @override
  Future<void> deleteAll() async => values.clear();
}

const _wrongText = 'パスコードが違います。もう一度入力してください';
const _mismatchText = 'パスコードが一致しません。もう一度入力してください';

Finder _key(int digit) => find.byKey(Key('passcode-key-$digit'));

Future<void> _enter(WidgetTester tester, String digits) async {
  for (final digit in digits.split('')) {
    await tester.tap(_key(int.parse(digit)));
    await tester.pump();
  }
  // 検証（非同期）の完了を待つ。
  await tester.pump();
  await tester.pump();
}

int _filledDots(WidgetTester tester) {
  var filled = 0;
  for (var i = 0; i < 4; i++) {
    final dot = tester.widget<Container>(find.byKey(Key('passcode-dot-$i')));
    final decoration = dot.decoration! as BoxDecoration;
    if (decoration.color != Colors.transparent) filled++;
  }
  return filled;
}

Widget _app(ProviderContainer container, {Widget? home, TransitionBuilder? builder}) {
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      locale: const Locale('ja'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: builder,
      home: home ?? const Scaffold(body: Center(child: Text('HOME'))),
    ),
  );
}

void main() {
  late _MemoryStorage storage;
  late ProviderContainer container;

  Future<void> startGuardedApp(WidgetTester tester, {String? active}) async {
    SharedPreferences.setMockInitialValues({});
    storage = _MemoryStorage();
    container = ProviderContainer(
      retry: noProviderRetry,
      overrides: [
        sharedPreferencesProvider.overrideWithValue(await SharedPreferences.getInstance()),
        passcodeStoreProvider.overrideWithValue(PasscodeStore(storage)),
        accountByIdProvider.overrideWith((ref, accountId) => Stream.value(null)),
      ],
    );
    addTearDown(container.dispose);
    if (active != null) await container.read(activeAccountIdProvider.notifier).setActive(active);

    await tester.pumpWidget(_app(container, builder: (context, child) => PasscodeGuard(child: child!)));
    await tester.pump();
    await tester.pump();
  }

  PasscodeStore store() => container.read(passcodeStoreProvider);

  group('復帰時の再ロックと入力の制限', () {
    late DateTime now;

    Future<void> startUnlocked(WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      storage = _MemoryStorage();
      now = DateTime(2026, 11, 1, 12);
      await PasscodeStore(storage).save('a', '1234');
      container = ProviderContainer(
        retry: noProviderRetry,
        overrides: [
          sharedPreferencesProvider.overrideWithValue(await SharedPreferences.getInstance()),
          passcodeStoreProvider.overrideWithValue(PasscodeStore(storage, now: () => now)),
          passcodeClockProvider.overrideWithValue(() => now),
          accountByIdProvider.overrideWith((ref, accountId) => Stream.value(null)),
        ],
      );
      addTearDown(container.dispose);
      await container.read(activeAccountIdProvider.notifier).setActive('a');
      await tester.pumpWidget(_app(container, builder: (context, child) => PasscodeGuard(child: child!)));
      await tester.pump();
      await tester.pump();
    }

    Future<void> background(WidgetTester tester, Duration away) async {
      for (final state in [AppLifecycleState.inactive, AppLifecycleState.hidden, AppLifecycleState.paused]) {
        tester.binding.handleAppLifecycleStateChanged(state);
      }
      await tester.pump();
      now = now.add(away);
      for (final state in [AppLifecycleState.hidden, AppLifecycleState.inactive, AppLifecycleState.resumed]) {
        tester.binding.handleAppLifecycleStateChanged(state);
      }
      await tester.pump();
    }

    testWidgets('1分未満で戻ると解除のまま、1分以上で再びロックする', (tester) async {
      await startUnlocked(tester);
      await _enter(tester, '1234');
      expect(find.text('HOME').hitTestable(), findsOneWidget);

      await background(tester, const Duration(seconds: 59));
      expect(find.text('HOME').hitTestable(), findsOneWidget);

      await background(tester, const Duration(minutes: 1));
      await tester.pump();
      expect(find.text('パスコードを入力'), findsOneWidget);
      expect(find.text('HOME').hitTestable(), findsNothing);
    });

    testWidgets('5回誤ると待ち時間を出して入力を止め、「パスコードを忘れた場合」は残す', (tester) async {
      await startUnlocked(tester);
      for (var i = 0; i < 5; i++) {
        await _enter(tester, '0000');
      }
      expect(find.text('続けて間違えたため、あと30秒お待ちください'), findsOneWidget);
      expect(find.text('パスコードを忘れた場合'), findsOneWidget);

      await _enter(tester, '1234');
      expect(find.text('パスコードを入力'), findsOneWidget, reason: '待ち時間の間は入力を受け付けない');

      now = now.add(const Duration(seconds: 30));
      await tester.pump(const Duration(seconds: 1));
      await _enter(tester, '1234');
      expect(find.text('HOME').hitTestable(), findsOneWidget);
    });
  });

  group('PasscodeGuard（AUT-04：起動時・切替時のガード）', () {
    testWidgets('アクティブなアカウントが無い間は、ガードされない', (tester) async {
      await startGuardedApp(tester);

      expect(find.text('HOME').hitTestable(), findsOneWidget);
      expect(find.text('パスコードを入力'), findsNothing);
    });

    testWidgets('パスコードが未設定のアカウントは、素通りする', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await startGuardedApp(tester, active: 'a');

      expect(find.text('HOME').hitTestable(), findsOneWidget);
      expect(find.text('パスコードを入力'), findsNothing);
    });

    testWidgets('パスコードが設定済みのアカウントは、入力画面が下の画面を覆い、対象アカウントを表示する', (tester) async {
      SharedPreferences.setMockInitialValues({});
      storage = _MemoryStorage();
      await PasscodeStore(storage).save('a', '1234');
      container = ProviderContainer(
        retry: noProviderRetry,
        overrides: [
          sharedPreferencesProvider.overrideWithValue(await SharedPreferences.getInstance()),
          passcodeStoreProvider.overrideWithValue(PasscodeStore(storage)),
          accountByIdProvider.overrideWith((ref, accountId) => Stream.value(null)),
        ],
      );
      addTearDown(container.dispose);
      await container.read(activeAccountIdProvider.notifier).setActive('a');
      await tester.pumpWidget(_app(container, builder: (context, child) => PasscodeGuard(child: child!)));
      await tester.pump();
      await tester.pump();

      expect(find.text('パスコードを入力'), findsOneWidget);
      expect(find.text('a'), findsOneWidget, reason: 'アカウント名の取得前は、アカウントIDを表示する');
      expect(find.text('パスコードを忘れた場合'), findsOneWidget);
      expect(find.text('HOME').hitTestable(), findsNothing);
    });

    testWidgets('正しいパスコードで解除され、誤りは入力をクリアしてエラーを出す', (tester) async {
      SharedPreferences.setMockInitialValues({});
      storage = _MemoryStorage();
      await PasscodeStore(storage).save('a', '1234');
      container = ProviderContainer(
        retry: noProviderRetry,
        overrides: [
          sharedPreferencesProvider.overrideWithValue(await SharedPreferences.getInstance()),
          passcodeStoreProvider.overrideWithValue(PasscodeStore(storage)),
          accountByIdProvider.overrideWith((ref, accountId) => Stream.value(null)),
        ],
      );
      addTearDown(container.dispose);
      await container.read(activeAccountIdProvider.notifier).setActive('a');
      await tester.pumpWidget(_app(container, builder: (context, child) => PasscodeGuard(child: child!)));
      await tester.pump();
      await tester.pump();

      await _enter(tester, '1111');
      expect(find.text(_wrongText), findsOneWidget);
      expect(find.byKey(const Key('passcode-dot-0')), findsNothing, reason: '誤入力は即座にクリアし、ドットの代わりにエラーを出す');

      await tester.tap(_key(1));
      await tester.pump();
      expect(find.text(_wrongText), findsNothing, reason: '次の入力でエラーが消えてドットに戻る');
      expect(_filledDots(tester), 1);
      await tester.tap(find.byKey(const Key('passcode-key-delete')));
      await tester.pump();
      expect(find.text('HOME').hitTestable(), findsNothing);

      await _enter(tester, '1234');
      expect(find.text('パスコードを入力'), findsNothing);
      expect(find.text('HOME').hitTestable(), findsOneWidget);
    });

    testWidgets('閉じるボタンで、解除せずに使用中のアカウントを未選択に戻す（アカウント一覧へ移れる）', (tester) async {
      SharedPreferences.setMockInitialValues({});
      storage = _MemoryStorage();
      await PasscodeStore(storage).save('a', '1234');
      container = ProviderContainer(
        retry: noProviderRetry,
        overrides: [
          sharedPreferencesProvider.overrideWithValue(await SharedPreferences.getInstance()),
          passcodeStoreProvider.overrideWithValue(PasscodeStore(storage)),
          accountByIdProvider.overrideWith((ref, accountId) => Stream.value(null)),
        ],
      );
      addTearDown(container.dispose);
      await container.read(activeAccountIdProvider.notifier).setActive('a');
      await tester.pumpWidget(_app(container, builder: (context, child) => PasscodeGuard(child: child!)));
      await tester.pump();
      await tester.pump();

      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();
      await tester.pump();

      expect(container.read(activeAccountIdProvider), isNull);
      expect(find.text('パスコードを入力'), findsNothing);
      expect(await store().isEnabled('a'), isTrue, reason: 'パスコードは残る');
    });

    testWidgets('入力中の桁数がドットに反映され、削除で1桁戻る', (tester) async {
      SharedPreferences.setMockInitialValues({});
      storage = _MemoryStorage();
      await PasscodeStore(storage).save('a', '1234');
      container = ProviderContainer(
        retry: noProviderRetry,
        overrides: [
          sharedPreferencesProvider.overrideWithValue(await SharedPreferences.getInstance()),
          passcodeStoreProvider.overrideWithValue(PasscodeStore(storage)),
          accountByIdProvider.overrideWith((ref, accountId) => Stream.value(null)),
        ],
      );
      addTearDown(container.dispose);
      await container.read(activeAccountIdProvider.notifier).setActive('a');
      await tester.pumpWidget(_app(container, builder: (context, child) => PasscodeGuard(child: child!)));
      await tester.pump();
      await tester.pump();

      await _enter(tester, '12');
      expect(_filledDots(tester), 2);

      await tester.tap(find.byKey(const Key('passcode-key-delete')));
      await tester.pump();
      expect(_filledDots(tester), 1);
    });

    testWidgets('アカウントを切り替えるたびに、切替先のパスコードを求める（元のアカウントへ戻る場合も）', (tester) async {
      SharedPreferences.setMockInitialValues({});
      storage = _MemoryStorage();
      await PasscodeStore(storage).save('a', '1234');
      container = ProviderContainer(
        retry: noProviderRetry,
        overrides: [
          sharedPreferencesProvider.overrideWithValue(await SharedPreferences.getInstance()),
          passcodeStoreProvider.overrideWithValue(PasscodeStore(storage)),
          accountByIdProvider.overrideWith((ref, accountId) => Stream.value(null)),
        ],
      );
      addTearDown(container.dispose);
      final active = container.read(activeAccountIdProvider.notifier);
      await active.setActive('a');
      await tester.pumpWidget(_app(container, builder: (context, child) => PasscodeGuard(child: child!)));
      await tester.pump();
      await tester.pump();
      await _enter(tester, '1234');
      expect(find.text('HOME').hitTestable(), findsOneWidget);

      // パスコード無しのアカウントbへ切り替え：ガードされない。
      await active.setActive('b');
      await tester.pump();
      await tester.pump();
      expect(find.text('HOME').hitTestable(), findsOneWidget);

      // パスコード付きのaへ戻る：解除済みだった状態は破棄されており、再度入力を求められる。
      await active.setActive('a');
      await tester.pump();
      await tester.pump();
      expect(find.text('パスコードを入力'), findsOneWidget);
      expect(find.text('HOME').hitTestable(), findsNothing);
    });

    testWidgets('パスコードを設定・解除した直後に、ガードが挟まらない', (tester) async {
      await startGuardedApp(tester, active: 'a');
      expect(find.text('HOME').hitTestable(), findsOneWidget);

      // SET-03と同じく、2回入力して設定する。
      final subscription = container.listen(passcodeSetupViewModelProvider('a'), (_, _) {});
      final setup = container.read(passcodeSetupViewModelProvider('a').notifier);
      for (final digit in [1, 2, 3, 4, 1, 2, 3, 4]) {
        await setup.inputDigit(digit);
      }
      subscription.close();
      await tester.pump();
      await tester.pump();
      expect(find.text('パスコードを入力'), findsNothing, reason: '設定した本人は解除済みとして扱う');
      expect(find.text('HOME').hitTestable(), findsOneWidget);

      // SET-01のOFFと同じく、リポジトリから削除する。
      await container.read(passcodeRepositoryProvider).remove('a');
      await tester.pump();
      await tester.pump();
      expect(find.text('HOME').hitTestable(), findsOneWidget);
      expect(await store().isEnabled('a'), isFalse);
    });
  });

  group('PasscodeEntryScreen（確認モード：SET-01のOFF確認）', () {
    Future<void> openConfirm(WidgetTester tester, {required List<bool?> results}) async {
      SharedPreferences.setMockInitialValues({});
      storage = _MemoryStorage();
      await PasscodeStore(storage).save('a', '1234');
      container = ProviderContainer(
        retry: noProviderRetry,
        overrides: [
          sharedPreferencesProvider.overrideWithValue(await SharedPreferences.getInstance()),
          passcodeStoreProvider.overrideWithValue(PasscodeStore(storage)),
          accountByIdProvider.overrideWith((ref, accountId) => Stream.value(null)),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        _app(
          container,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  final result = await Navigator.of(context).push<bool>(
                    MaterialPageRoute(
                      builder: (_) => const PasscodeEntryScreen(accountId: 'a', mode: PasscodeEntryMode.confirm),
                    ),
                  );
                  results.add(result);
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    testWidgets('見出しは「現在のパスコード」で、「パスコードを忘れた場合」は表示しない', (tester) async {
      await openConfirm(tester, results: []);

      expect(find.text('現在のパスコードを入力'), findsOneWidget);
      expect(find.text('パスコードを忘れた場合'), findsNothing);
    });

    testWidgets('正しいパスコードならtrueで閉じ、誤りなら閉じずにクリアする', (tester) async {
      final results = <bool?>[];
      await openConfirm(tester, results: results);

      await _enter(tester, '9999');
      expect(find.text(_wrongText), findsOneWidget);
      expect(results, isEmpty);

      await _enter(tester, '1234');
      await tester.pumpAndSettle();
      expect(results, [true]);
      expect(find.text('現在のパスコードを入力'), findsNothing);
    });

    testWidgets('確認モードで解除に成功しても、パスコード設定自体はまだ消えない（OFFの確定は呼び出し元）', (tester) async {
      await openConfirm(tester, results: []);
      await _enter(tester, '1234');
      await tester.pumpAndSettle();

      expect(await store().isEnabled('a'), isTrue);
    });
  });

  group('PasscodeSetupScreen（SET-03：パスコード設定）', () {
    Future<void> openSetup(WidgetTester tester, {required List<bool?> results}) async {
      SharedPreferences.setMockInitialValues({});
      storage = _MemoryStorage();
      container = ProviderContainer(
        retry: noProviderRetry,
        overrides: [
          sharedPreferencesProvider.overrideWithValue(await SharedPreferences.getInstance()),
          passcodeStoreProvider.overrideWithValue(PasscodeStore(storage)),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        _app(
          container,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  final result = await Navigator.of(
                    context,
                  ).push<bool>(MaterialPageRoute(builder: (_) => const PasscodeSetupScreen(accountId: 'a')));
                  results.add(result);
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    testWidgets('1回目の入力後は「もう一度入力」に進み、一致すれば保存してtrueで閉じる', (tester) async {
      final results = <bool?>[];
      await openSetup(tester, results: results);
      expect(find.text('新しいパスコードを入力'), findsOneWidget);

      await _enter(tester, '4321');
      expect(find.text('もう一度入力'), findsOneWidget);
      expect(_filledDots(tester), 0);
      expect(await store().isEnabled('a'), isFalse, reason: '確認入力が終わるまで保存しない');

      await _enter(tester, '4321');
      await tester.pumpAndSettle();

      expect(results, [true]);
      expect(await store().verify('a', '4321'), isTrue);
      expect(container.read(unlockedAccountIdProvider), 'a', reason: '設定した直後に自分がロックされない');
    });

    testWidgets('2回目が一致しなければ、エラーを出して1回目からやり直し、何も保存しない', (tester) async {
      final results = <bool?>[];
      await openSetup(tester, results: results);

      await _enter(tester, '1111');
      await _enter(tester, '2222');

      expect(find.text(_mismatchText), findsOneWidget);
      expect(find.text('新しいパスコードを入力'), findsOneWidget);
      expect(results, isEmpty);
      expect(await store().isEnabled('a'), isFalse);

      // やり直しでは、前回の1回目は使われない。
      await _enter(tester, '3333');
      await _enter(tester, '3333');
      await tester.pumpAndSettle();
      expect(results, [true]);
      expect(await store().verify('a', '3333'), isTrue);
    });

    testWidgets('保存に失敗したら、エラーを表示して1回目からやり直し、閉じない（黙って戻らない）', (tester) async {
      final results = <bool?>[];
      await openSetup(tester, results: results);
      storage.failWrites = true;

      await _enter(tester, '1234');
      await _enter(tester, '1234');
      await tester.pump();

      expect(find.text('パスコードを設定できませんでした。もう一度お試しください'), findsOneWidget);
      expect(find.text('新しいパスコードを入力'), findsOneWidget);
      expect(results, isEmpty);
      expect(await store().isEnabled('a'), isFalse);

      // 保存領域が回復すれば、そのまま設定し直せる。
      storage.failWrites = false;
      await _enter(tester, '1234');
      await _enter(tester, '1234');
      await tester.pumpAndSettle();
      expect(results, [true]);
      expect(await store().verify('a', '1234'), isTrue);
    });

    testWidgets('戻る（キャンセル）ではパスコードを設定せずに閉じる', (tester) async {
      final results = <bool?>[];
      await openSetup(tester, results: results);
      await _enter(tester, '1234');

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      expect(results, [null]);
      expect(await store().isEnabled('a'), isFalse);
    });
  });
}
