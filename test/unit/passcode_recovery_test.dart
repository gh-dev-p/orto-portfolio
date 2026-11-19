// AuthRepositoryはFirebaseに接続するため、必要な部分だけを持つ偽物を使う。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multi_id_msg/ui/passcode/widgets/passcode_guard.dart';
import 'package:multi_id_msg/l10n/app_localizations.dart';
import 'package:multi_id_msg/data/repositories/auth/auth_repository.dart';
import 'package:multi_id_msg/data/services/passcode/passcode_store.dart';
import 'package:multi_id_msg/data/repositories/user/user_repository.dart';
import 'package:multi_id_msg/ui/account/view_models/account_providers.dart';
import 'package:multi_id_msg/ui/account/view_models/active_account_provider.dart';
import 'package:multi_id_msg/ui/auth/view_models/phone_input_viewmodel.dart';
import 'package:multi_id_msg/ui/auth/view_models/verification_code_viewmodel.dart';
import 'package:multi_id_msg/ui/passcode/view_models/passcode_entry_viewmodel.dart';
import 'package:multi_id_msg/config/preferences_provider.dart';
import 'package:multi_id_msg/config/service_providers.dart';
import 'package:multi_id_msg/config/provider_retry.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum _SendResult { codeSent, autoVerified, failed }

/// ログイン中のユーザの電話番号（偽物のAuthRepositoryが返す）
const _myPhoneNumber = '+819012345678';

class _FakeAuthRepository extends Fake implements AuthRepository {
  _SendResult sendResult = _SendResult.codeSent;
  AuthErrorCode? confirmError;
  final calls = <String>[];
  PhoneVerificationPurpose? _purpose;
  String? _phoneNumber;
  String? _verificationId;

  @override
  AuthUser? get currentUser => const AuthUser(uid: 'uid-1', phoneNumber: _myPhoneNumber);

  @override
  Stream<AuthUser?> get authStateChanges => const Stream.empty();

  @override
  Stream<AuthUser?> get userChanges => const Stream.empty();

  @override
  Future<void> signOut() async {}

  @override
  PhoneVerificationSession? get verificationSession {
    final purpose = _purpose;
    final phoneNumber = _phoneNumber;
    if (purpose == null || phoneNumber == null) return null;
    return PhoneVerificationSession(purpose: purpose, phoneNumber: phoneNumber, codeSent: _verificationId != null);
  }

  @override
  Future<VerificationStart> startVerification({
    required PhoneVerificationPurpose purpose,
    required String phoneNumber,
  }) async {
    _purpose = purpose;
    _phoneNumber = phoneNumber;
    _verificationId = null;
    return _send();
  }

  @override
  Future<VerificationStart> resendCode() => _send();

  Future<VerificationStart> _send() async {
    calls.add('sendCode:${_purpose!.name}:$_phoneNumber');
    switch (sendResult) {
      case _SendResult.codeSent:
        _verificationId = '${_purpose!.name}-id';
        return VerificationStart.codeSent;
      case _SendResult.autoVerified:
        return VerificationStart.verified;
      case _SendResult.failed:
        throw const AuthException(AuthErrorCode.tooManyRequests);
    }
  }

  @override
  Future<void> confirmCode(String smsCode) async {
    calls.add('confirmCode:${_purpose!.name}:$_verificationId:$smsCode');
    final error = confirmError;
    if (error != null) throw AuthException(error);
  }

  @override
  Future<bool> carryOverTransferVerificationIfNeeded() async => false;

  @override
  Future<TransferPasswordStatus> transferPasswordStatus({bool forceRefresh = false}) async =>
      const TransferPasswordStatus(registered: false, sessionVerified: true);
}

class _FakeUserRepository extends Fake implements UserRepository {
  final phoneNumberUpdates = <String>[];

  @override
  Future<void> updateUserPhoneNumber(String uid, String phoneNumber) async => phoneNumberUpdates.add(phoneNumber);
}

class _MemoryStorage implements PasscodeStorage {
  final values = <String, String>{};

  /// trueの間、削除（個別・全消去とも）が失敗する（復旧できない保存領域の異常を模す）。
  bool failDeletes = false;

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;

  @override
  Future<void> delete(String key) async {
    if (failDeletes) throw Exception('delete failed');
    values.remove(key);
  }

  @override
  Future<void> deleteAll() async {
    if (failDeletes) throw Exception('deleteAll failed');
    values.clear();
  }
}

void main() {
  group('SMS認証の手続き（再認証：AUT-04→AUT-03）', () {
    late _FakeAuthRepository auth;
    late ProviderContainer container;

    setUp(() {
      auth = _FakeAuthRepository();
      container = ProviderContainer(
        retry: noProviderRetry,
        overrides: [
          authRepositoryProvider.overrideWithValue(auth),
          userRepositoryProvider.overrideWithValue(_FakeUserRepository()),
        ],
      );
      addTearDown(container.dispose);
      // autoDisposeのProviderを、テスト中は破棄させない。
      container.listen(passcodeEntryViewModelProvider('a'), (_, _) {});
    });

    PasscodeEntryViewModel passcodeEntry() => container.read(passcodeEntryViewModelProvider('a').notifier);

    /// AUT-03のViewModel（手続き中の状態から作られるため、送信の後に初めて読む）
    VerificationCodeViewModel verificationCode() {
      container.listen(verificationCodeViewModelProvider, (_, _) {});
      return container.read(verificationCodeViewModelProvider.notifier);
    }

    VerificationCodeState verificationState() => container.read(verificationCodeViewModelProvider);

    test('再認証を始めると、ログイン中のユーザの電話番号宛に送り、再認証の手続きになる', () async {
      final start = await passcodeEntry().startRecovery();

      expect(start, VerificationStart.codeSent);
      expect(auth.calls, ['sendCode:reauthentication:$_myPhoneNumber']);
      final session = auth.verificationSession!;
      expect(session.purpose, PhoneVerificationPurpose.reauthentication);
      expect(session.phoneNumber, _myPhoneNumber);
      expect(session.codeSent, isTrue);
      expect(verificationState().purpose, PhoneVerificationPurpose.reauthentication);
      expect(verificationState().phoneNumber, _myPhoneNumber);
    });

    test('送信に失敗したら、失敗を返しエラー種別を持つ', () async {
      auth.sendResult = _SendResult.failed;

      final start = await passcodeEntry().startRecovery();

      expect(start, VerificationStart.failed);
      expect(container.read(passcodeEntryViewModelProvider('a')).errorCode, AuthErrorCode.tooManyRequests);
      expect(container.read(passcodeEntryViewModelProvider('a')).busy, isFalse);
    });

    test('端末の自動検証で再認証まで完了した場合は、コード入力なしの成功を返す', () async {
      auth.sendResult = _SendResult.autoVerified;

      expect(await passcodeEntry().startRecovery(), VerificationStart.verified);
    });

    test('再認証の手続きの認証コード確認は、サインインではなく再認証として行う', () async {
      await passcodeEntry().startRecovery();
      final viewModel = verificationCode();

      viewModel.updateCode('123456');
      expect(await viewModel.confirm(), isTrue);

      expect(auth.calls, [
        'sendCode:reauthentication:$_myPhoneNumber',
        'confirmCode:reauthentication:reauthentication-id:123456',
      ]);
    });

    test('再認証のコードが誤りなら、失敗としてエラー種別を持つ', () async {
      await passcodeEntry().startRecovery();
      auth.confirmError = AuthErrorCode.invalidVerificationCode;
      final viewModel = verificationCode();

      viewModel.updateCode('000000');
      expect(await viewModel.confirm(), isFalse);

      expect(verificationState().errorCode, AuthErrorCode.invalidVerificationCode);
      expect(verificationState().failureCount, 1);
    });

    test('通常のログインの認証コード確認は、これまでどおりサインインとして行う', () async {
      container.listen(phoneInputViewModelProvider(false), (_, _) {});
      final phoneInput = container.read(phoneInputViewModelProvider(false).notifier);
      phoneInput.updateInput('090-1234-5678');
      await phoneInput.submit();
      final viewModel = verificationCode();

      viewModel.updateCode('123456');
      expect(await viewModel.confirm(), isTrue);

      expect(verificationState().purpose, PhoneVerificationPurpose.signIn);
      expect(auth.calls, ['sendCode:signIn:+819012345678', 'confirmCode:signIn:signIn-id:123456']);
    });
  });

  group('SMS認証の手続き（電話番号の変更：AUT-02→AUT-03）', () {
    late _FakeAuthRepository auth;
    late _FakeUserRepository users;
    late ProviderContainer container;

    setUp(() {
      auth = _FakeAuthRepository();
      users = _FakeUserRepository();
      container = ProviderContainer(
        retry: noProviderRetry,
        overrides: [
          authRepositoryProvider.overrideWithValue(auth),
          userRepositoryProvider.overrideWithValue(users),
        ],
      );
      addTearDown(container.dispose);
      container.listen(phoneInputViewModelProvider(true), (_, _) {});
    });

    PhoneInputViewModel phoneInput() => container.read(phoneInputViewModelProvider(true).notifier);
    PhoneInputState phoneInputState() => container.read(phoneInputViewModelProvider(true));

    VerificationCodeViewModel verificationCode() {
      container.listen(verificationCodeViewModelProvider, (_, _) {});
      return container.read(verificationCodeViewModelProvider.notifier);
    }

    VerificationCodeState verificationState() => container.read(verificationCodeViewModelProvider);

    test('新しい番号宛に送り、認証コードの確認で電話番号を差し替えてusersも更新する', () async {
      phoneInput().updateInput('080-1111-2222');
      expect(await phoneInput().submit(), VerificationStart.codeSent);
      expect(auth.verificationSession!.purpose, PhoneVerificationPurpose.phoneNumberChange);
      final viewModel = verificationCode();

      viewModel.updateCode('123456');
      expect(await viewModel.confirm(), isTrue);

      expect(auth.calls, [
        'sendCode:phoneNumberChange:+818011112222',
        'confirmCode:phoneNumberChange:phoneNumberChange-id:123456',
      ]);
      // フェイクのユーザの電話番号（差し替え後の値として扱う）でusersを更新する。
      expect(users.phoneNumberUpdates, [_myPhoneNumber]);
    });

    test('現在と同じ番号は、SMSを送らずにエラーにする', () async {
      phoneInput().updateInput('090-1234-5678');
      expect(await phoneInput().submit(), VerificationStart.failed);

      expect(phoneInputState().errorCode, AuthErrorCode.samePhoneNumber);
      expect(auth.calls, isEmpty);
    });

    test('新しい番号が別のユーザに使われていれば、専用のエラー種別になり、usersは更新しない', () async {
      phoneInput().updateInput('080-1111-2222');
      await phoneInput().submit();
      auth.confirmError = AuthErrorCode.phoneNumberInUse;
      final viewModel = verificationCode();

      viewModel.updateCode('123456');
      expect(await viewModel.confirm(), isFalse);

      expect(verificationState().errorCode, AuthErrorCode.phoneNumberInUse);
      expect(users.phoneNumberUpdates, isEmpty);
    });
  });

  group('「パスコードを忘れた場合」（AUT-04：SMS再認証でパスコードを解除）', () {
    late _FakeAuthRepository auth;
    late _MemoryStorage storage;
    late ProviderContainer container;

    Future<void> startLocked(WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      auth = _FakeAuthRepository();
      storage = _MemoryStorage();
      await PasscodeStore(storage).save('a', '1234');
      container = ProviderContainer(
        retry: noProviderRetry,
        overrides: [
          sharedPreferencesProvider.overrideWithValue(await SharedPreferences.getInstance()),
          authRepositoryProvider.overrideWithValue(auth),
          userRepositoryProvider.overrideWithValue(_FakeUserRepository()),
          passcodeStoreProvider.overrideWithValue(PasscodeStore(storage)),
          accountByIdProvider.overrideWith((ref, accountId) => Stream.value(null)),
        ],
      );
      await container.read(activeAccountIdProvider.notifier).setActive('a');
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            locale: const Locale('ja'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => PasscodeGuard(child: child!),
            home: const Scaffold(body: Center(child: Text('HOME'))),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(find.text('パスコードを入力'), findsOneWidget);
    }

    /// 再送の待ち時間のタイマー（AUT-03のViewModel内）が残らないよう、テストの最後に画面とContainerを片付ける。
    Future<void> finish(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
      container.dispose();
      await tester.pump();
    }

    Future<void> tapForgot(WidgetTester tester) async {
      await tester.tap(find.text('パスコードを忘れた場合'));
      await tester.pumpAndSettle();
    }

    /// 認証コードを入れる。6桁そろうと、確認ボタンを押さなくても確認する
    Future<void> submitCode(WidgetTester tester, String code) async {
      await tester.enterText(find.byType(TextField), code);
      await tester.pumpAndSettle();
    }

    testWidgets('誤りの回数の上限に達しても、SMS再認証で復帰できる', (tester) async {
      await startLocked(tester);
      final store = PasscodeStore(storage);
      for (var i = 0; i < PasscodeAttemptPolicy.maxFailures; i++) {
        storage.values['passcodeAttempts.a'] = '${i + 1}:0';
      }
      expect((await store.lockout('a')).exhausted, isTrue);

      await tapForgot(tester);
      await submitCode(tester, '123456');

      expect(storage.values, isEmpty, reason: 'パスコードと誤りの回数の両方が消える');
      expect(find.text('HOME').hitTestable(), findsOneWidget);
      await finish(tester);
    });

    testWidgets('SMSのコードで再認証できたら、パスコードが削除され、ガードなしで先へ進む', (tester) async {
      await startLocked(tester);

      await tapForgot(tester);
      expect(find.text('認証コードを入力してください'), findsOneWidget, reason: '認証コード入力画面が開く');
      expect(auth.calls, ['sendCode:reauthentication:$_myPhoneNumber']);

      await submitCode(tester, '123456');

      expect(auth.calls.last, 'confirmCode:reauthentication:reauthentication-id:123456');
      expect(find.text('パスコードを入力'), findsNothing);
      expect(find.text('HOME').hitTestable(), findsOneWidget);
      expect(await container.read(passcodeStoreProvider).isEnabled('a'), isFalse);
      await finish(tester);
    });

    testWidgets('端末の自動検証で再認証が完了した場合も、コード入力なしでパスコードが削除される', (tester) async {
      await startLocked(tester);
      auth.sendResult = _SendResult.autoVerified;

      await tapForgot(tester);

      expect(find.text('HOME').hitTestable(), findsOneWidget);
      expect(await container.read(passcodeStoreProvider).isEnabled('a'), isFalse);
      await finish(tester);
    });

    testWidgets('再認証に成功しても、パスコードを消せなかったら、エラーを表示する（黙って残さない）', (tester) async {
      await startLocked(tester);
      storage.failDeletes = true;
      await tapForgot(tester);

      await submitCode(tester, '123456');

      // 再認証に成功した本人は、その回は先へ進める（次の起動では、消えていないので再びロックされる）。
      expect(find.text('HOME').hitTestable(), findsOneWidget);
      expect(find.text('パスコードを解除できませんでした。もう一度お試しください'), findsWidgets);
      storage.failDeletes = false;
      expect(await container.read(passcodeStoreProvider).isEnabled('a'), isTrue);
      await finish(tester);
    });

    testWidgets('SMSの送信に失敗したら、エラーを出してロックのまま（パスコードは残る）', (tester) async {
      await startLocked(tester);
      auth.sendResult = _SendResult.failed;

      await tapForgot(tester);

      expect(find.text('パスコードを入力'), findsOneWidget);
      // SnackBarは、ガードの下の画面のScaffoldにも重ねて出るため、1つとは限らない。
      expect(find.byType(SnackBar), findsWidgets);
      expect(find.text('HOME').hitTestable(), findsNothing);
      expect(await container.read(passcodeStoreProvider).isEnabled('a'), isTrue);
      await finish(tester);
    });

    testWidgets('認証コードが誤りなら、エラーを出してロックのまま（パスコードは残る）', (tester) async {
      await startLocked(tester);
      await tapForgot(tester);
      auth.confirmError = AuthErrorCode.invalidVerificationCode;

      await submitCode(tester, '000000');

      expect(find.text('認証コードを入力してください'), findsOneWidget, reason: '認証コード入力画面に留まる');
      expect(find.text('HOME').hitTestable(), findsNothing);
      expect(await container.read(passcodeStoreProvider).isEnabled('a'), isTrue);
      await finish(tester);
    });

    testWidgets('認証コード入力画面から戻ると、パスコード入力画面に戻り、ロックのまま', (tester) async {
      await startLocked(tester);
      await tapForgot(tester);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      expect(find.text('パスコードを入力'), findsOneWidget);
      expect(find.text('HOME').hitTestable(), findsNothing);
      expect(await container.read(passcodeStoreProvider).isEnabled('a'), isTrue);
      await finish(tester);
    });
  });
}
