// 管理者の判定とログアウト（機能仕様書4.1.7）
// ログアウトと再ログインで、パスコードのロックを回避できないことも確かめる。

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multi_id_msg/config/preferences_provider.dart';
import 'package:multi_id_msg/config/provider_retry.dart';
import 'package:multi_id_msg/config/service_providers.dart';
import 'package:multi_id_msg/data/repositories/account/active_account_repository.dart';
import 'package:multi_id_msg/data/repositories/auth/auth_repository.dart';
import 'package:multi_id_msg/data/repositories/notification/notification_repository.dart';
import 'package:multi_id_msg/data/repositories/passcode/passcode_repository.dart';
import 'package:multi_id_msg/data/services/auth/firebase_auth_service.dart';
import 'package:multi_id_msg/data/services/common/cloud_functions_service.dart';
import 'package:multi_id_msg/domain/models/account.dart';
import 'package:multi_id_msg/domain/use_cases/logout_use_case.dart';
import 'package:multi_id_msg/ui/account/view_models/account_providers.dart';
import 'package:multi_id_msg/ui/account/view_models/active_account_provider.dart';
import 'package:multi_id_msg/ui/auth/view_models/auth_providers.dart';
import 'package:multi_id_msg/ui/passcode/view_models/passcode_providers.dart';
import 'package:multi_id_msg/ui/settings/view_models/settings_viewmodel.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeAuthService extends Fake implements FirebaseAuthService {
  _FakeAuthService(this.claims);

  final Map<String, dynamic>? claims;
  bool? forcedRefresh;

  @override
  Future<Map<String, dynamic>?> idTokenClaims({bool forceRefresh = false}) async {
    forcedRefresh = forceRefresh;
    return claims;
  }
}

class _FakeFunctionsService extends Fake implements CloudFunctionsService {}

class _FakeAuthRepository extends Fake implements AuthRepository {
  _FakeAuthRepository({this.admin = false, this.adminFails = false});

  bool admin;
  bool adminFails;
  final authStates = StreamController<AuthUser?>.broadcast();

  static const user = AuthUser(uid: 'uid-1', phoneNumber: '+819012345678');

  @override
  Stream<AuthUser?> get authStateChanges async* {
    yield user;
    yield* authStates.stream;
  }

  @override
  Stream<AuthUser?> get userChanges => authStateChanges;

  @override
  Future<bool> isAdmin() async {
    if (adminFails) throw Exception('network');
    return admin;
  }

  @override
  Future<TransferPasswordStatus> transferPasswordStatus({bool forceRefresh = false}) async =>
      const TransferPasswordStatus(registered: false, sessionVerified: true);
}

class _FakeActiveAccountRepository extends Fake implements ActiveAccountRepository {
  String? saved = 'alice';

  @override
  String? read() => saved;

  @override
  Future<void> save(String accountId) async => saved = accountId;

  @override
  Future<void> clear() async => saved = null;
}

class _FakePasscodeRepository extends Fake implements PasscodeRepository {
  int removeCount = 0;

  @override
  Stream<bool> watchEnabled(String accountId) => Stream.value(true);

  @override
  Future<void> remove(String accountId) async => removeCount++;
}

class _FakeLogoutUseCase extends Fake implements LogoutUseCase {
  _FakeLogoutUseCase({this.fails = false, this.failure});

  final bool fails;
  final Object? failure;
  List<String>? calledWith;

  @override
  Future<void> call(List<String> accountIds) async {
    calledWith = accountIds;
    if (failure case final failure?) throw failure;
    if (fails) throw Exception('offline');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AuthRepository.isAdmin', () {
    Future<bool> isAdmin(Map<String, dynamic>? claims) =>
        AuthRepository(_FakeAuthService(claims), _FakeFunctionsService()).isAdmin();

    test('adminクレームがtrueのときだけ管理者', () async {
      expect(await isAdmin({'admin': true}), isTrue);
      expect(await isAdmin({'admin': false}), isFalse);
      expect(await isAdmin({'admin': 'true'}), isFalse);
      expect(await isAdmin({'tp': true}), isFalse);
      expect(await isAdmin({}), isFalse);
      expect(await isAdmin(null), isFalse);
    });

    test('トークンを強制更新しない', () async {
      final service = _FakeAuthService({'admin': true});
      await AuthRepository(service, _FakeFunctionsService()).isAdmin();
      expect(service.forcedRefresh, isFalse);
    });
  });

  group('SettingsViewModel', () {
    late _FakeActiveAccountRepository activeAccounts;
    late _FakePasscodeRepository passcodes;
    late _FakeLogoutUseCase logout;

    Future<ProviderContainer> makeContainer({
      _FakeAuthRepository? auth,
      _FakeLogoutUseCase? useCase,
      AsyncValue<List<Account>>? accounts,
    }) async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      logout = useCase ?? _FakeLogoutUseCase();
      final container = ProviderContainer(
        retry: noProviderRetry,
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          authRepositoryProvider.overrideWithValue(auth ?? _FakeAuthRepository()),
          activeAccountRepositoryProvider.overrideWithValue(activeAccounts),
          passcodeRepositoryProvider.overrideWithValue(passcodes),
          logoutUseCaseProvider.overrideWithValue(logout),
          userPlanProvider.overrideWithValue(const AsyncData(null)),
          accountsProvider.overrideWithValue(
            accounts ??
                AsyncData([
                  Account(id: 'alice', displayName: 'Alice'),
                  Account(id: 'bob', displayName: 'Bob'),
                ]),
          ),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    setUp(() {
      activeAccounts = _FakeActiveAccountRepository();
      passcodes = _FakePasscodeRepository();
    });

    /// [SettingsState.isAdmin]が確定するまで待って返す
    Future<bool> readIsAdmin(ProviderContainer container) async {
      final subscription = container.listen(settingsViewModelProvider, (_, _) {});
      addTearDown(subscription.close);
      await container.read(authStateChangesProvider.future);
      await container.read(isAdminProvider.future).catchError((Object _) => false);
      await pumpEventQueue();
      return subscription.read().isAdmin;
    }

    test('管理者のときだけisAdminがtrueになる', () async {
      expect(await readIsAdmin(await makeContainer(auth: _FakeAuthRepository(admin: true))), isTrue);
      expect(await readIsAdmin(await makeContainer(auth: _FakeAuthRepository())), isFalse);
    });

    test('管理者かどうかを読めなければfalse', () async {
      expect(await readIsAdmin(await makeContainer(auth: _FakeAuthRepository(adminFails: true))), isFalse);
    });

    /// アプリが背景から前面に戻る
    Future<void> resumeApp() async {
      final binding = TestWidgetsFlutterBinding.instance;
      binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await pumpEventQueue();
    }

    test('前面に戻ると読み直し、クレームの設定が反映される', () async {
      final auth = _FakeAuthRepository();
      final container = await makeContainer(auth: auth);
      expect(await readIsAdmin(container), isFalse);

      auth.admin = true;
      expect(container.read(settingsViewModelProvider).isAdmin, isFalse);
      await resumeApp();

      expect(container.read(settingsViewModelProvider).isAdmin, isTrue);
    });

    test('読み取りに失敗しても、前面に戻ると読み直す', () async {
      final auth = _FakeAuthRepository(admin: true, adminFails: true);
      final container = await makeContainer(auth: auth);
      expect(await readIsAdmin(container), isFalse);

      auth.adminFails = false;
      await resumeApp();

      expect(container.read(settingsViewModelProvider).isAdmin, isTrue);
    });

    test('ログアウトすると、全アカウントを渡し、アクティブアカウントの記録を消す', () async {
      final container = await makeContainer();
      final subscription = container.listen(settingsViewModelProvider, (_, _) {});
      addTearDown(subscription.close);

      expect(await container.read(settingsViewModelProvider.notifier).logout(), LogoutResult.succeeded);

      expect(logout.calledWith, ['alice', 'bob']);
      expect(activeAccounts.saved, isNull);
      expect(container.read(activeAccountIdProvider), isNull);
    });

    test('ログアウトに失敗したら、アクティブアカウントの記録を残してfailedを返す', () async {
      final container = await makeContainer(useCase: _FakeLogoutUseCase(fails: true));
      final subscription = container.listen(settingsViewModelProvider, (_, _) {});
      addTearDown(subscription.close);

      expect(await container.read(settingsViewModelProvider.notifier).logout(), LogoutResult.failed);

      expect(activeAccounts.saved, 'alice');
    });

    test('サーバーに拒否されたら、アクティブアカウントの記録を残してdeniedを返す', () async {
      final container = await makeContainer(
        useCase: _FakeLogoutUseCase(failure: const TokenUnregisterDeniedException()),
      );
      final subscription = container.listen(settingsViewModelProvider, (_, _) {});
      addTearDown(subscription.close);

      expect(await container.read(settingsViewModelProvider.notifier).logout(), LogoutResult.denied);

      expect(activeAccounts.saved, 'alice');
    });

    test('アカウントの一覧が無ければ、ログアウトしない', () async {
      final container = await makeContainer(accounts: const AsyncLoading());
      final subscription = container.listen(settingsViewModelProvider, (_, _) {});
      addTearDown(subscription.close);

      expect(await container.read(settingsViewModelProvider.notifier).logout(), LogoutResult.failed);

      expect(logout.calledWith, isNull);
    });

    test('ログアウトと再ログインの後も、パスコードは残り、解除をやり直す', () async {
      final container = await makeContainer();
      final settings = container.listen(settingsViewModelProvider, (_, _) {});
      final guard = container.listen(passcodeGuardStatusProvider, (_, _) {});
      addTearDown(settings.close);
      addTearDown(guard.close);
      await pumpEventQueue();
      container.read(unlockedAccountIdProvider.notifier).unlock('alice');
      expect(guard.read(), PasscodeGuardStatus.open);

      await container.read(settingsViewModelProvider.notifier).logout();
      await container.read(activeAccountIdProvider.notifier).setActive('alice');
      await pumpEventQueue();

      expect(passcodes.removeCount, 0);
      expect(guard.read(), PasscodeGuardStatus.locked);
    });
  });
}
