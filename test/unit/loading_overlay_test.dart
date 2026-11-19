import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multi_id_msg/ui/core/ui/loading_overlay_host.dart';
import 'package:multi_id_msg/ui/core/view_models/loading_overlay_provider.dart';
import 'package:multi_id_msg/config/provider_retry.dart';

void main() {
  group('LoadingOverlayController.run', () {
    test('実行中だけ件数が増え、終了すると0へ戻る', () async {
      final container = ProviderContainer(retry: noProviderRetry);
      addTearDown(container.dispose);
      final completer = Completer<int>();

      final future = container.read(loadingOverlayProvider.notifier).run(() => completer.future);
      expect(container.read(loadingOverlayProvider), 1);

      completer.complete(42);
      expect(await future, 42);
      expect(container.read(loadingOverlayProvider), 0);
    });

    test('例外が起きても0へ戻り、例外は呼び出し元へ伝わる', () async {
      final container = ProviderContainer(retry: noProviderRetry);
      addTearDown(container.dispose);

      await expectLater(
        container.read(loadingOverlayProvider.notifier).run<void>(() async => throw StateError('failed')),
        throwsStateError,
      );
      expect(container.read(loadingOverlayProvider), 0);
    });

    test('処理が重なった場合は、すべて終わるまで表示を維持する', () async {
      final container = ProviderContainer(retry: noProviderRetry);
      addTearDown(container.dispose);
      final first = Completer<void>();
      final second = Completer<void>();
      final notifier = container.read(loadingOverlayProvider.notifier);

      final f1 = notifier.run(() => first.future);
      final f2 = notifier.run(() => second.future);
      expect(container.read(loadingOverlayProvider), 2);

      first.complete();
      await f1;
      expect(container.read(loadingOverlayProvider), 1);

      second.complete();
      await f2;
      expect(container.read(loadingOverlayProvider), 0);
    });
  });

  group('LoadingOverlayHost', () {
    testWidgets('処理中は下の画面へのタップをブロックし、終了後は再び押せる', (tester) async {
      final container = ProviderContainer(retry: noProviderRetry);
      addTearDown(container.dispose);
      var taps = 0;

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            // app.dartと同じく、Providerの実行中をConsumerで読んでLoadingOverlayHostに渡す。
            builder: (context, child) => Consumer(
              builder: (context, ref, _) => LoadingOverlayHost(
                visible: ref.watch(loadingOverlayProvider.select((count) => count > 0)),
                child: child!,
              ),
            ),
            home: Scaffold(body: Center(child: ElevatedButton(onPressed: () => taps++, child: const Text('押す')))),
          ),
        ),
      );

      await tester.tap(find.text('押す'));
      expect(taps, 1);

      final completer = Completer<void>();
      final future = container.read(loadingOverlayProvider.notifier).run(() => completer.future);
      await tester.pump();
      expect(find.byType(CupertinoActivityIndicator), findsOneWidget);

      await tester.tap(find.text('押す'), warnIfMissed: false);
      expect(taps, 1);

      completer.complete();
      await future;
      await tester.pump();
      expect(find.byType(CupertinoActivityIndicator), findsNothing);

      await tester.tap(find.text('押す'));
      expect(taps, 2);
    });

    testWidgets('表示を始めるとフォーカスを外し、キーボードを閉じる', (tester) async {
      final container = ProviderContainer(retry: noProviderRetry);
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            builder: (context, child) => Consumer(
              builder: (context, ref, _) => LoadingOverlayHost(
                visible: ref.watch(loadingOverlayProvider.select((count) => count > 0)),
                child: child!,
              ),
            ),
            home: const Scaffold(body: TextField()),
          ),
        ),
      );

      await tester.tap(find.byType(TextField));
      await tester.pump();
      expect(tester.testTextInput.isVisible, isTrue);

      final completer = Completer<void>();
      final future = container.read(loadingOverlayProvider.notifier).run(() => completer.future);
      await tester.pump();
      expect(tester.testTextInput.isVisible, isFalse);

      completer.complete();
      await future;
      await tester.pump();
      // 処理が終わっても、フォーカスは戻さない。
      expect(tester.testTextInput.isVisible, isFalse);
    });
  });
}
