import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multi_id_msg/config/provider_retry.dart';
import 'package:multi_id_msg/config/service_providers.dart';
import 'package:multi_id_msg/data/repositories/account/active_account_repository.dart';
import 'package:multi_id_msg/data/repositories/auth/auth_repository.dart';
import 'package:multi_id_msg/domain/models/account.dart';
import 'package:multi_id_msg/domain/use_cases/complete_phone_verification_use_case.dart';
import 'package:multi_id_msg/domain/use_cases/withdraw_use_case.dart';
import 'package:multi_id_msg/l10n/app_localizations.dart';
import 'package:multi_id_msg/ui/account/view_models/account_providers.dart';
import 'package:multi_id_msg/ui/core/themes/app_theme.dart';
import 'package:multi_id_msg/ui/core/ui/app_slide_to_confirm.dart';
import 'package:multi_id_msg/ui/core/view_models/loading_overlay_provider.dart';
import 'package:multi_id_msg/ui/settings/widgets/withdrawal_screen.dart';

const _acknowledge = 'すべてのアカウントが削除され、元に戻せないことを理解しました';
const _failed = '退会できませんでした。通信環境を確認して、もう一度お試しください';

final _thumb = find.byIcon(Icons.chevron_right);

class _FakeWithdrawUseCase implements WithdrawUseCase {
  int callCount = 0;
  bool fails = false;

  @override
  Future<void> call(List<String> accountIds) async {
    callCount++;
    if (fails) throw Exception('failed');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeAuthRepository implements AuthRepository {
  /// 再認証の開始の結果（失敗はnull）
  VerificationStart? start = VerificationStart.verified;
  final started = <PhoneVerificationPurpose>[];

  @override
  Future<void> signOut() async {}

  @override
  AuthUser? get currentUser => const AuthUser(uid: 'uid', phoneNumber: '+819000000000');

  @override
  Future<VerificationStart> startVerification({
    required PhoneVerificationPurpose purpose,
    required String phoneNumber,
  }) async {
    started.add(purpose);
    final result = start;
    if (result == null) throw const AuthException(AuthErrorCode.network);
    return result;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeActiveAccountRepository implements ActiveAccountRepository {
  @override
  String? read() => 'alice';

  @override
  Future<void> clear() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeCompleteVerification implements CompletePhoneVerificationUseCase {
  @override
  Future<bool> call(PhoneVerificationPurpose purpose) async => false;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<_FakeWithdrawUseCase> _pump(WidgetTester tester, {_FakeAuthRepository? auth}) async {
  final withdraw = _FakeWithdrawUseCase();
  await tester.pumpWidget(
    ProviderScope(
      retry: noProviderRetry,
      overrides: [
        withdrawUseCaseProvider.overrideWithValue(withdraw),
        authRepositoryProvider.overrideWithValue(auth ?? _FakeAuthRepository()),
        completePhoneVerificationUseCaseProvider.overrideWithValue(_FakeCompleteVerification()),
        activeAccountRepositoryProvider.overrideWithValue(_FakeActiveAccountRepository()),
        accountsProvider.overrideWithValue(
          AsyncData([
            Account(id: 'alice', displayName: 'Alice'),
          ]),
        ),
      ],
      child: MaterialApp(
        locale: const Locale('ja'),
        theme: AppTheme.light,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const WithdrawalScreen())),
            child: const Text('開く'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('開く'));
  await tester.pumpAndSettle();
  return withdraw;
}

void main() {
  testWidgets('スライドは画面の幅いっぱいに広がり、つまみは左端から始まる', (tester) async {
    await _pump(tester);

    final slide = tester.getRect(find.byType(AppSlideToConfirm));
    expect(slide.width, tester.view.physicalSize.width / tester.view.devicePixelRatio - 48);
    expect(tester.getCenter(_thumb).dx, lessThan(slide.left + 56));
  });

  testWidgets('チェック前は右端まで動かしても退会できない', (tester) async {
    final withdraw = await _pump(tester);

    await tester.drag(_thumb, const Offset(800, 0));
    await tester.pumpAndSettle();

    expect(withdraw.callCount, 0);
    expect(find.byType(WithdrawalScreen), findsOneWidget);
  });

  testWidgets('チェック後でも途中で離すと退会しない', (tester) async {
    final withdraw = await _pump(tester);
    await tester.tap(find.text(_acknowledge));
    await tester.pump();
    final start = tester.getCenter(_thumb);

    await tester.drag(_thumb, const Offset(120, 0));
    await tester.pumpAndSettle();

    expect(withdraw.callCount, 0);
    expect(tester.getCenter(_thumb), start);
    expect(find.byType(WithdrawalScreen), findsOneWidget);
  });

  testWidgets('SMS再認証を始められなければ、退会しない', (tester) async {
    final auth = _FakeAuthRepository()..start = null;
    final withdraw = await _pump(tester, auth: auth);
    await tester.tap(find.text(_acknowledge));
    await tester.pump();

    await tester.drag(_thumb, const Offset(800, 0));
    await tester.pumpAndSettle();

    expect(auth.started, [PhoneVerificationPurpose.reauthentication]);
    expect(withdraw.callCount, 0);
    expect(find.text(_failed), findsOneWidget);
  });

  testWidgets('チェック後に右端まで動かすと退会し、ホームまで戻る', (tester) async {
    final withdraw = await _pump(tester);
    await tester.tap(find.text(_acknowledge));
    await tester.pump();

    await tester.drag(_thumb, const Offset(800, 0));
    await tester.pumpAndSettle();

    expect(withdraw.callCount, 1);
    expect(find.byType(WithdrawalScreen), findsNothing);
  });

  testWidgets('チェックを外すと再び退会できなくなる', (tester) async {
    final withdraw = await _pump(tester);
    await tester.tap(find.text(_acknowledge));
    await tester.pump();
    await tester.tap(find.text(_acknowledge));
    await tester.pump();

    await tester.drag(_thumb, const Offset(800, 0));
    await tester.pumpAndSettle();

    expect(withdraw.callCount, 0);
  });

  testWidgets('失敗するとエラーを表示してスライドが戻り、再試行できる', (tester) async {
    final withdraw = await _pump(tester);
    withdraw.fails = true;
    await tester.tap(find.text(_acknowledge));
    await tester.pump();
    final start = tester.getCenter(_thumb);

    await tester.drag(_thumb, const Offset(800, 0));
    await tester.pumpAndSettle();

    expect(withdraw.callCount, 1);
    expect(find.text(_failed), findsOneWidget);
    expect(find.byType(WithdrawalScreen), findsOneWidget);
    expect(tester.getCenter(_thumb).dx, start.dx);
    final container = ProviderScope.containerOf(tester.element(find.byType(WithdrawalScreen)));
    expect(container.read(loadingOverlayProvider), 0);

    withdraw.fails = false;
    await tester.drag(_thumb, const Offset(800, 0));
    await tester.pumpAndSettle();
    expect(withdraw.callCount, 2);
    expect(find.byType(WithdrawalScreen), findsNothing);
  });
}
