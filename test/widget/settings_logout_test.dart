// SET-01のログアウトの項目（機能仕様書4.1.7）
// 管理者にだけ表示し、失敗したら知らせることを確かめる。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multi_id_msg/l10n/app_localizations.dart';
import 'package:multi_id_msg/ui/core/themes/app_theme.dart';
import 'package:multi_id_msg/ui/settings/view_models/settings_viewmodel.dart';
import 'package:multi_id_msg/ui/settings/widgets/settings_body.dart';

class _FakeSettingsViewModel extends SettingsViewModel {
  _FakeSettingsViewModel({required this.isAdmin, required this.result});

  final bool isAdmin;
  final LogoutResult result;
  int logoutCount = 0;

  @override
  SettingsState build() => SettingsState(
    phoneNumber: null,
    plan: null,
    transferPasswordRegistered: null,
    activeAccount: null,
    passcodeEnabled: false,
    locale: const Locale('ja'),
    themeMode: ThemeMode.system,
    isAdmin: isAdmin,
  );

  @override
  Future<LogoutResult> logout() async {
    logoutCount++;
    return result;
  }
}

void main() {
  Future<_FakeSettingsViewModel> pumpSettings(
    WidgetTester tester, {
    required bool isAdmin,
    LogoutResult result = LogoutResult.succeeded,
  }) async {
    final viewModel = _FakeSettingsViewModel(isAdmin: isAdmin, result: result);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [settingsViewModelProvider.overrideWith(() => viewModel)],
        child: MaterialApp(
          theme: AppTheme.light,
          locale: const Locale('ja'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: SettingsBody()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return viewModel;
  }

  Future<void> scrollToWithdrawal(WidgetTester tester) async {
    await tester.dragUntilVisible(find.text('退会'), find.byType(ListView), const Offset(0, -200));
    await tester.drag(find.byType(ListView), const Offset(0, -200));
    await tester.pumpAndSettle();
  }

  testWidgets('管理者ではないと、ログアウトの項目を出さない', (tester) async {
    await pumpSettings(tester, isAdmin: false);
    await scrollToWithdrawal(tester);

    expect(find.text('ログアウト'), findsNothing);
  });

  testWidgets('管理者には項目を出し、確認の後にログアウトする', (tester) async {
    final viewModel = await pumpSettings(tester, isAdmin: true);
    await scrollToWithdrawal(tester);

    await tester.tap(find.text('ログアウト'));
    await tester.pumpAndSettle();
    expect(viewModel.logoutCount, 0);
    expect(find.text('ログアウトしますか？'), findsOneWidget);

    await tester.tap(find.text('ログアウト').last);
    await tester.pumpAndSettle();
    expect(viewModel.logoutCount, 1);
  });

  testWidgets('確認をキャンセルすると、ログアウトしない', (tester) async {
    final viewModel = await pumpSettings(tester, isAdmin: true);
    await scrollToWithdrawal(tester);

    await tester.tap(find.text('ログアウト'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('キャンセル'));
    await tester.pumpAndSettle();

    expect(viewModel.logoutCount, 0);
  });

  testWidgets('失敗したら、SnackBarで知らせる', (tester) async {
    await pumpSettings(tester, isAdmin: true, result: LogoutResult.failed);
    await scrollToWithdrawal(tester);

    await tester.tap(find.text('ログアウト'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ログアウト').last);
    await tester.pumpAndSettle();

    expect(find.text('ログアウトできませんでした。通信環境を確認して、もう一度お試しください'), findsOneWidget);
  });

  testWidgets('サーバーに拒否されたら、通信環境の案内を出さない', (tester) async {
    await pumpSettings(tester, isAdmin: true, result: LogoutResult.denied);
    await scrollToWithdrawal(tester);

    await tester.tap(find.text('ログアウト'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ログアウト').last);
    await tester.pumpAndSettle();

    expect(find.text('サーバーに拒否されたため、ログアウトできませんでした'), findsOneWidget);
    expect(find.textContaining('通信環境'), findsNothing);
  });
}
