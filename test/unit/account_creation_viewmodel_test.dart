// ACC-02（アカウント作成画面）のViewModel：入力の判定・アカウントIDの重複・画像のアップロードの失敗。
// AccountRepository・AuthRepositoryはFirebaseに接続するため、必要な部分だけを持つ偽物を使う。

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
import 'package:multi_id_msg/ui/account/view_models/active_account_provider.dart';
import 'package:multi_id_msg/ui/friend/view_models/invite_link_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeAuthRepository extends Fake implements AuthRepository {
  @override
  AuthUser? get currentUser => const AuthUser(uid: 'uid-1', phoneNumber: '+819012345678');
}

class _FakeAccountRepository extends Fake implements AccountRepository {
  /// trueなら、作成時にアカウントIDが既に使われている扱いにする
  bool idTaken = false;
  bool creationBlocked = false;

  /// trueなら、画像のアップロードに失敗する
  bool imageUploadFails = false;

  final created = <String>[];
  final imageUpdates = <String>[];

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
    if (creationBlocked) throw const AccountCreationBlockedException();
    created.add('$uid:$accountId:$displayName');
    return Account(id: accountId, displayName: displayName);
  }

  @override
  Future<void> updateProfileImage({required String accountId, required File image}) async {
    if (imageUploadFails) throw Exception('upload failed');
    imageUpdates.add(accountId);
  }
}

void main() {
  late _FakeAccountRepository accounts;
  late ProviderContainer container;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    accounts = _FakeAccountRepository();
    container = ProviderContainer(
      retry: noProviderRetry,
      overrides: [
        sharedPreferencesProvider.overrideWithValue(await SharedPreferences.getInstance()),
        authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
        accountRepositoryProvider.overrideWithValue(accounts),
      ],
    );
    addTearDown(container.dispose);
    // autoDisposeのProviderを、テスト中は破棄させない。
    container.listen(accountCreationViewModelProvider, (_, _) {});
  });

  AccountCreationViewModel viewModel() => container.read(accountCreationViewModelProvider.notifier);
  AccountCreationState state() => container.read(accountCreationViewModelProvider);

  test('表示名・アカウントIDが正しく、予約されたIDでないときだけ作成できる', () {
    expect(state().canCreate, isFalse);

    viewModel().updateDisplayName('たろう');
    viewModel().updateAccountId('ab');
    expect(state().accountIdFormatValid, isFalse, reason: '4文字未満');
    expect(state().canCreate, isFalse);

    viewModel().updateAccountId('taro_01');
    expect(state().canCreate, isTrue);
  });

  test('アカウントIDを変えると、使えるかの確認結果は捨てる', () async {
    viewModel().updateAccountId('taro_01');
    await viewModel().checkIdAvailability();
    expect(state().idAvailable, isTrue);

    viewModel().updateAccountId('taro_02');
    expect(state().idAvailable, isNull);
  });

  test('作成すると、作成したアカウントをアクティブアカウントにする', () async {
    viewModel().updateDisplayName(' たろう ');
    viewModel().updateAccountId('taro_01');

    expect(await viewModel().create(), AccountCreationOutcome.created);

    expect(accounts.created, ['uid-1:taro_01:たろう']);
    expect(container.read(activeAccountIdProvider), 'taro_01');
  });

  test('作成時にアカウントIDが既に使われていたら、専用のエラーになり、使えない扱いにする', () async {
    accounts.idTaken = true;
    viewModel().updateDisplayName('たろう');
    viewModel().updateAccountId('taro_01');

    expect(await viewModel().create(), AccountCreationOutcome.failed);

    expect(state().errorCode, AccountCreationError.idTaken);
    expect(state().idAvailable, isFalse);
    expect(state().busy, isFalse);
    expect(container.read(activeAccountIdProvider), isNull);
  });

  test('削除の繰り返しで作成できないときは、専用のエラーになる', () async {
    accounts.creationBlocked = true;
    viewModel().updateDisplayName('たろう');
    viewModel().updateAccountId('taro_01');

    expect(await viewModel().create(), AccountCreationOutcome.failed);

    expect(state().errorCode, AccountCreationError.blocked);
    expect(state().busy, isFalse);
  });

  test('画像のアップロードだけ失敗しても、アカウントは作成済みとして扱う', () async {
    accounts.imageUploadFails = true;
    viewModel().updateDisplayName('たろう');
    viewModel().updateAccountId('taro_01');
    viewModel().selectImage(File('dummy.jpg'));

    expect(await viewModel().create(), AccountCreationOutcome.createdWithoutImage);

    expect(accounts.created, hasLength(1));
    expect(container.read(activeAccountIdProvider), 'taro_01');
  });

  group('招待してくれた人のID（機能仕様書4.3.5.2）', () {
    setUp(() {
      viewModel().updateDisplayName('たろう');
      viewModel().updateAccountId('taro_01');
    });

    test('形式が違えば作成できない。空なら作成できる', () {
      viewModel().updateInviterAccountId('ab');
      expect(state().canCreate, isFalse);
      viewModel().updateInviterAccountId('');
      expect(state().canCreate, isTrue);
    });

    test('入れて作成すると、開く予定の招待にする', () async {
      viewModel().updateInviterAccountId(' hanako ');
      await viewModel().create();
      expect(container.read(pendingInviteProvider), 'hanako');
    });

    test('招待リンクで受け取った招待があれば、そちらを優先する', () async {
      container.read(pendingInviteProvider.notifier).set('from_link');
      viewModel().updateInviterAccountId('hanako');
      await viewModel().create();
      expect(container.read(pendingInviteProvider), 'from_link');
    });

    test('作成に失敗したら、開く予定の招待にしない', () async {
      accounts.idTaken = true;
      viewModel().updateInviterAccountId('hanako');
      await viewModel().create();
      expect(container.read(pendingInviteProvider), isNull);
    });
  });
}
