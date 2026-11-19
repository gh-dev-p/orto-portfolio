// ホームの再同意と、引き継ぎパスワードの再設定の申請の警告
// UserRepository・AuthRepositoryはFirebaseに接続するため、必要な部分だけを持つ偽物を使う。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multi_id_msg/config/legal_links.dart';
import 'package:multi_id_msg/config/provider_retry.dart';
import 'package:multi_id_msg/config/service_providers.dart';
import 'package:multi_id_msg/data/repositories/auth/auth_repository.dart';
import 'package:multi_id_msg/data/repositories/user/user_repository.dart';
import 'package:multi_id_msg/l10n/app_localizations.dart';
import 'package:multi_id_msg/ui/core/themes/app_theme.dart';
import 'package:multi_id_msg/ui/settings/widgets/home_notices_listener.dart';

class _FakeAuthRepository extends Fake implements AuthRepository {
  int cancelCalls = 0;

  @override
  AuthUser? get currentUser => const AuthUser(uid: 'uid-1', phoneNumber: '+819012345678');

  @override
  Future<void> cancelTransferReset() async => cancelCalls++;
}

class _FakeUserRepository extends Fake implements UserRepository {
  _FakeUserRepository({required this.consented});

  bool consented;
  final List<String> checkedVersions = [];
  int recordCalls = 0;

  @override
  Future<bool> hasLegalConsentSince(String uid, String version) async {
    checkedVersions.add(version);
    return consented;
  }

  @override
  Future<void> recordLegalConsent() async {
    recordCalls++;
    consented = true;
  }
}

Future<void> _pump(
  WidgetTester tester, {
  required _FakeAuthRepository auth,
  required _FakeUserRepository user,
  DateTime? resetAt,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      retry: noProviderRetry,
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        userRepositoryProvider.overrideWithValue(user),
        transferResetAtProvider.overrideWith((ref) => Stream.value(resetAt)),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        locale: const Locale('ja'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const HomeNoticesListener(child: Scaffold(body: Text('home'))),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('今の版に同意していれば、何も出さない', (tester) async {
    final user = _FakeUserRepository(consented: true);
    await _pump(tester, auth: _FakeAuthRepository(), user: user);
    expect(user.checkedVersions, [LegalLinks.documentVersion]);
    expect(find.text('利用規約とプライバシーポリシーを改定しました'), findsNothing);
  });

  testWidgets('今の版に同意していなければ再同意を求め、「同意する」で記録して閉じる', (tester) async {
    final user = _FakeUserRepository(consented: false);
    await _pump(tester, auth: _FakeAuthRepository(), user: user);
    expect(find.text('利用規約とプライバシーポリシーを改定しました'), findsOneWidget);

    await tester.tap(find.text('同意する'));
    await tester.pumpAndSettle();
    expect(user.recordCalls, 1);
    expect(find.text('利用規約とプライバシーポリシーを改定しました'), findsNothing);
  });

  testWidgets('再設定の申請があれば警告を出し、「取り消す」で取り消す', (tester) async {
    final auth = _FakeAuthRepository();
    await _pump(
      tester,
      auth: auth,
      user: _FakeUserRepository(consented: true),
      resetAt: DateTime(2026, 11, 29, 14, 5),
    );
    expect(find.text('データの削除の申請があります'), findsOneWidget);
    expect(find.textContaining('11月29日'), findsOneWidget);

    await tester.tap(find.text('取り消す'));
    await tester.pumpAndSettle();
    expect(auth.cancelCalls, 1);
    expect(find.text('申請を取り消しました'), findsOneWidget);
  });

  testWidgets('申請が無ければ警告を出さない', (tester) async {
    await _pump(tester, auth: _FakeAuthRepository(), user: _FakeUserRepository(consented: true));
    expect(find.text('データの削除の申請があります'), findsNothing);
  });
}
