import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multi_id_msg/ui/core/themes/app_theme.dart';
import 'package:multi_id_msg/ui/chat/widgets/message_bubble.dart';
import 'package:multi_id_msg/l10n/app_localizations.dart';
import 'package:multi_id_msg/domain/models/message.dart';

Widget _app(Widget home) => MaterialApp(
  locale: const Locale('ja'),
  theme: AppTheme.light,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: home),
);

void main() {
  testWidgets('グループの自分のメッセージには既読の人数を表示し、0人なら表示しない（機能仕様書4.7.3.3）', (tester) async {
    Widget bubble(int count) => _app(
      MessageBubble(
        message: Message(id: 'm1', senderId: 'me', text: 'やあ', createdAt: DateTime(2026, 10, 1, 12), readBy: const []),
        isMine: true,
        isReadByPeer: false,
        groupReadCount: count,
        isSelectable: false,
        onRetry: (_) {},
        onLongPress: (_, _) {},
        onOpenImage: (_) {},
        onTapReactions: (_, _) {},
      ),
    );

    await tester.pumpWidget(bubble(3));
    expect(find.text('既読 3'), findsOneWidget);
    await tester.pumpWidget(bubble(0));
    expect(find.textContaining('既読'), findsNothing);
  });

  testWidgets('知らない種類のメッセージは、更新の案内を表示する（機能仕様書4.4.3）', (tester) async {
    final message = Message(
      id: 'm1',
      senderId: 'peer',
      text: '',
      type: MessageType.unknown,
      createdAt: DateTime(2026, 10, 1, 12),
      readBy: const [],
    );

    await tester.pumpWidget(
      _app(
        MessageBubble(
          message: message,
          isMine: false,
          isReadByPeer: false,
          isSelectable: false,
          onRetry: (_) {},
          onLongPress: (_, _) {},
          onOpenImage: (_) {},
          onTapReactions: (_, _) {},
        ),
      ),
    );

    expect(find.text('アプリを更新すると表示できます'), findsOneWidget);
  });

  testWidgets('送信に失敗した画像は端末上のファイルで表示し、画像・再送アイコンのタップで再送する（機能仕様書4.4.4.2）', (tester) async {
    final failed = Message(
      id: 'local-failed-0',
      senderId: 'me',
      text: '',
      type: MessageType.image,
      imageWidth: 400,
      imageHeight: 300,
      createdAt: DateTime(2026, 10, 1, 12),
      readBy: const [],
      isFailed: true,
      localImagePath: '/tmp/failed.jpg',
    );
    final retried = <Message>[];
    var opened = 0;

    await tester.pumpWidget(
      _app(
        MessageBubble(
          message: failed,
          isMine: true,
          isReadByPeer: false,
          isSelectable: false,
          onRetry: retried.add,
          onLongPress: (_, _) {},
          onOpenImage: (_) => opened++,
          onTapReactions: (_, _) {},
        ),
      ),
    );

    final image = tester.widget<Image>(find.byType(Image));
    expect((image.image as FileImage).file.path, '/tmp/failed.jpg');
    expect(find.byIcon(Icons.error_outline), findsOneWidget);

    await tester.tap(find.byType(Image));
    await tester.tap(find.byIcon(Icons.error_outline));
    expect(retried, [failed, failed]);
    // 送信できていない画像は全画面表示（CHA-03）を開かない。
    expect(opened, 0);
  });

  testWidgets('アップロード中の画像は端末上のファイルに進み具合を重ねて表示し、タップしても何も開かない（画面設計書5.3.2）', (tester) async {
    final uploading = Message(
      id: 'msg-1',
      senderId: 'me',
      text: '',
      type: MessageType.image,
      imageWidth: 400,
      imageHeight: 300,
      createdAt: DateTime(2026, 10, 2, 12),
      readBy: const [],
      isPending: true,
      localImagePath: '/tmp/uploading.jpg',
      uploadProgress: 0.4,
    );
    final retried = <Message>[];
    var opened = 0;
    var longPressed = 0;

    await tester.pumpWidget(
      _app(
        MessageBubble(
          message: uploading,
          isMine: true,
          isReadByPeer: false,
          isSelectable: false,
          onRetry: retried.add,
          onLongPress: (_, _) => longPressed++,
          onOpenImage: (_) => opened++,
          onTapReactions: (_, _) {},
        ),
      ),
    );

    final image = tester.widget<Image>(find.byType(Image));
    expect((image.image as FileImage).file.path, '/tmp/uploading.jpg');
    final progress = tester.widget<CircularProgressIndicator>(find.byKey(const Key('image-upload-progress')));
    expect(progress.value, 0.4);
    // 送信中は時計アイコン（再送アイコンではない）。
    expect(find.byIcon(Icons.access_time), findsOneWidget);
    expect(find.byIcon(Icons.error_outline), findsNothing);

    await tester.tap(find.byType(Image));
    await tester.longPress(find.byType(Image));
    expect(retried, isEmpty);
    expect(opened, 0);
    expect(longPressed, 0);
  });

  for (final isMine in [false, true]) {
    testWidgets('吹き出しの下のリアクションは、相手のメッセージならタップで選択を開ける（isMine: $isMine）', (tester) async {
      final reacted = Message(
        id: 'msg-1',
        senderId: isMine ? 'me' : 'peer',
        text: 'こんにちは',
        createdAt: DateTime(2026, 10, 8, 12),
        readBy: const [],
        reactions: {isMine ? 'peer' : 'me': '👍'},
      );
      final tapped = <Message>[];

      await tester.pumpWidget(
        _app(
          MessageBubble(
            message: reacted,
            isMine: isMine,
            isReadByPeer: false,
            isSelectable: false,
            onRetry: (_) {},
            onLongPress: (_, _) {},
            onOpenImage: (_) {},
            onTapReactions: (message, _) => tapped.add(message),
          ),
        ),
      );

      await tester.tap(find.text('👍'));
      expect(tapped, isMine ? isEmpty : [reacted]);
    });
  }
}
