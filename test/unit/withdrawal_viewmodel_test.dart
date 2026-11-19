import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multi_id_msg/config/provider_retry.dart';
import 'package:multi_id_msg/config/service_providers.dart';
import 'package:multi_id_msg/data/repositories/account/active_account_repository.dart';
import 'package:multi_id_msg/data/repositories/auth/auth_repository.dart';
import 'package:multi_id_msg/domain/models/account.dart';
import 'package:multi_id_msg/domain/use_cases/withdraw_use_case.dart';
import 'package:multi_id_msg/ui/account/view_models/account_providers.dart';
import 'package:multi_id_msg/ui/account/view_models/active_account_provider.dart';
import 'package:multi_id_msg/ui/settings/view_models/withdrawal_viewmodel.dart';

class _FakeWithdrawUseCase implements WithdrawUseCase {
  final completer = Completer<void>();
  List<String>? calledWith;

  @override
  Future<void> call(List<String> accountIds) {
    calledWith = accountIds;
    return completer.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeAuthRepository implements AuthRepository {
  int signOutCount = 0;

  @override
  Future<void> signOut() async => signOutCount++;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeActiveAccountRepository implements ActiveAccountRepository {
  String? saved = 'alice';

  @override
  String? read() => saved;

  @override
  Future<void> clear() async => saved = null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _FakeWithdrawUseCase withdraw;
  late _FakeAuthRepository auth;
  late _FakeActiveAccountRepository activeAccounts;
  late ProviderContainer container;

  setUp(() {
    withdraw = _FakeWithdrawUseCase();
    auth = _FakeAuthRepository();
    activeAccounts = _FakeActiveAccountRepository();
    container = ProviderContainer(
      retry: noProviderRetry,
      overrides: [
        withdrawUseCaseProvider.overrideWithValue(withdraw),
        authRepositoryProvider.overrideWithValue(auth),
        activeAccountRepositoryProvider.overrideWithValue(activeAccounts),
        accountsProvider.overrideWithValue(
          AsyncData([
            Account(id: 'alice', displayName: 'Alice'),
          ]),
        ),
      ],
    );
  });

  tearDown(() => container.dispose());

  group('退会（SET-04）', () {
    test('退会の途中で画面が閉じられてViewModelが破棄されても、サインアウトまで行う', () async {
      final subscription = container.listen(withdrawalViewModelProvider, (_, _) {});
      final result = container.read(withdrawalViewModelProvider.notifier).withdraw();

      // サーバー側でアカウントが0件になり、AuthGateが退会画面を閉じた状態
      subscription.close();
      await container.pump();

      withdraw.completer.complete();
      expect(await result, isTrue);
      expect(withdraw.calledWith, ['alice']);
      expect(activeAccounts.saved, isNull);
      expect(container.read(activeAccountIdProvider), isNull);
      expect(auth.signOutCount, 1);
    });
  });
}
