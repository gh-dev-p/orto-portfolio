import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multi_id_msg/config/provider_retry.dart';
import 'package:multi_id_msg/domain/models/account.dart';
import 'package:multi_id_msg/domain/models/friend.dart';
import 'package:multi_id_msg/l10n/app_localizations.dart';
import 'package:multi_id_msg/ui/core/themes/app_theme.dart';
import 'package:multi_id_msg/ui/core/ui/app_avatar.dart';
import 'package:multi_id_msg/ui/friend/view_models/friend_list_viewmodel.dart';
import 'package:multi_id_msg/ui/friend/view_models/friend_providers.dart';
import 'package:multi_id_msg/ui/group/widgets/group_friend_picker_screen.dart';

Account _account(String id) =>
    Account(id: id, displayName: id);

Future<void> _pumpPicker(WidgetTester tester) async {
  await tester.pumpWidget(
    ProviderScope(
      retry: noProviderRetry,
      overrides: [
        friendsProvider.overrideWith(
          (ref) => Stream.value([
            Friend(friendAccountId: 'alice', addedAt: DateTime(2026, 10, 1)),
            Friend(friendAccountId: 'bob', addedAt: DateTime(2026, 10, 1)),
          ]),
        ),
        friendListPeerProvider.overrideWith((ref, accountId) => AsyncData(_account(accountId))),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const GroupFriendPickerScreen(myAccountId: 'me'),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

bool _isChecked(WidgetTester tester, String name) =>
    tester.widget<CheckboxListTile>(find.widgetWithText(CheckboxListTile, name)).value!;

void main() {
  testWidgets('友だちを選んでも選択中のアイコンの一覧は出ず、行のチェックで選択と解除ができる', (tester) async {
    await _pumpPicker(tester);
    expect(find.byType(AppAvatar), findsNWidgets(2));

    await tester.tap(find.text('alice'));
    await tester.pump();
    expect(_isChecked(tester, 'alice'), isTrue);
    expect(_isChecked(tester, 'bob'), isFalse);
    expect(find.byType(AppAvatar), findsNWidgets(2));

    await tester.tap(find.text('alice'));
    await tester.pump();
    expect(_isChecked(tester, 'alice'), isFalse);
  });
}
