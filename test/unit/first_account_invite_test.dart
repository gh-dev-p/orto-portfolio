// 1つ目のアカウントの作成で受け取った招待（ACC-02の「招待してくれた人のアカウントID」・貼り付け・ログイン前のリンク）が、
// 作成後にアカウント一覧（ACC-01）を挟まずに開けること。
//
// 作成の書き込みは、サーバーの完了を待つ前に端末のアカウント一覧の監視へ届く。届いた時点で使用中のアカウントが無いと、
// 入口（AccountGate）がACC-01に切り替わってACC-02とそのViewModelが破棄され、続きの処理（招待の保存・使用中のアカウントの
// 設定）が動かなかった。偽物のリポジトリで、作成の途中に一覧を流し、画面の破棄と同じくViewModelの監視を外して再現する。

import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multi_id_msg/config/preferences_provider.dart';
import 'package:multi_id_msg/config/provider_retry.dart';
import 'package:multi_id_msg/config/service_providers.dart';
import 'package:multi_id_msg/data/repositories/account/account_repository.dart';
import 'package:multi_id_msg/data/repositories/auth/auth_repository.dart';
import 'package:multi_id_msg/domain/models/account.dart';
import 'package:multi_id_msg/ui/account/view_models/account_creation_viewmodel.dart';
import 'package:multi_id_msg/ui/account/view_models/account_gate_viewmodel.dart';
import 'package:multi_id_msg/ui/account/view_models/account_providers.dart';
import 'package:multi_id_msg/ui/account/view_models/active_account_provider.dart';
import 'package:multi_id_msg/ui/friend/view_models/invite_link_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeAuthRepository extends Fake implements AuthRepository {
  @override
  AuthUser? get currentUser => const AuthUser(uid: 'uid-1', phoneNumber: '+819012345678');
}

/// 作成の途中で、端末のアカウント一覧の監視に作ったアカウントを流す（Firestoreの書き込みの見え方と同じ）
class _FakeAccountRepository extends Fake implements AccountRepository {
  _FakeAccountRepository(this.accountsStream);

  final StreamController<List<Account>> accountsStream;

  /// 一覧が流れた後、作成の完了を返す前に呼ぶ（画面の破棄を真似る）
  Future<void> Function()? afterListed;

  bool idTaken = false;
  bool imageUploadFails = false;

  @override
  Future<bool> isAccountIdAvailable(String accountId) async => !idTaken;

  @override
  Future<Account> createAccount({
    required String accountId,
    required String uid,
    required String displayName,
    String? phoneNumber,
    String? bio,
    String? photoURL,
  }) async {
    if (idTaken) throw const AccountIdTakenException();
    final account = Account(id: accountId, displayName: displayName);
    accountsStream.add([account]);
    await afterListed?.call();
    return account;
  }

  @override
  Future<void> updateProfileImage({required String accountId, required File image}) async {
    if (imageUploadFails) throw Exception('upload failed');
  }
}

void main() {
  late StreamController<List<Account>> accountsStream;
  late _FakeAccountRepository repository;
  late ProviderContainer container;
  late ProviderSubscription<AccountCreationState> screen;
  final gateHistory = <AccountGateStatus?>[];

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    accountsStream = StreamController<List<Account>>.broadcast();
    repository = _FakeAccountRepository(accountsStream);
    container = ProviderContainer(
      retry: noProviderRetry,
      overrides: [
        sharedPreferencesProvider.overrideWithValue(await SharedPreferences.getInstance()),
        authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
        accountRepositoryProvider.overrideWithValue(repository),
        accountsProvider.overrideWith((ref) => accountsStream.stream),
      ],
    );
    addTearDown(() {
      container.dispose();
      accountsStream.close();
    });
    gateHistory.clear();
    container.listen(accountGateViewModelProvider, (_, next) => gateHistory.add(next.value), fireImmediately: true);
    accountsStream.add(const []);
    await Future<void>.delayed(Duration.zero);
    expect(container.read(accountGateViewModelProvider).value, AccountGateStatus.noAccount);

    // ACC-02が表示中の間だけ、ViewModelを監視する。入口がACC-02以外に切り替わったら画面が消えるのと同じく監視を外す。
    screen = container.listen(accountCreationViewModelProvider, (_, _) {});
    repository.afterListed = () async {
      await Future<void>.delayed(Duration.zero);
      if (container.read(accountGateViewModelProvider).value != AccountGateStatus.noAccount) screen.close();
      // 監視が外れたViewModelが破棄されるのを待つ。
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
    };
  });

  AccountCreationViewModel viewModel() => container.read(accountCreationViewModelProvider.notifier);

  void fill({String inviter = ''}) {
    viewModel().updateDisplayName('シムエア');
    viewModel().updateAccountId('simcheck.air');
    viewModel().updateInviterAccountId(inviter);
  }

  test('招待してくれた人のIDを入れて1つ目を作ると、ACC-01を挟まずにホームへ進み、招待が開く予定に残る', () async {
    fill(inviter: 'review.google');
    final outcome = await viewModel().create();
    await Future<void>.delayed(Duration.zero);

    expect(outcome, isNot(AccountCreationOutcome.failed));
    expect(container.read(activeAccountIdProvider), 'simcheck.air');
    expect(container.read(pendingInviteProvider), 'review.google');
    expect(container.read(accountGateViewModelProvider).value, AccountGateStatus.home);
    expect(gateHistory, isNot(contains(AccountGateStatus.selectAccount)), reason: 'ACC-01を挟まない');
  });

  test('貼り付け・ログイン前のリンクで受け取った招待があれば、それを残したまま、ACC-01を挟まずにホームへ進む', () async {
    container.read(pendingInviteProvider.notifier).set('review.google');
    fill();
    await viewModel().create();
    await Future<void>.delayed(Duration.zero);

    expect(container.read(activeAccountIdProvider), 'simcheck.air');
    expect(container.read(pendingInviteProvider), 'review.google');
    expect(gateHistory, isNot(contains(AccountGateStatus.selectAccount)));
  });

  test('作成に失敗したら、使用中のアカウントと、入力から入れた招待を元に戻す', () async {
    repository.idTaken = true;
    fill(inviter: 'review.google');
    expect(await viewModel().create(), AccountCreationOutcome.failed);

    expect(container.read(activeAccountIdProvider), isNull);
    expect(container.read(pendingInviteProvider), isNull);
    expect(container.read(accountGateViewModelProvider).value, AccountGateStatus.noAccount);
  });
}
