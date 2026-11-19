import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multi_id_msg/config/app_check_activation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// App Checkのプロバイダーの選び方と、App Attestが通らないときのDeviceCheckへの切り替え。
class _FakeAppCheck {
  _FakeAppCheck(this.tokens);

  /// getTokenを呼ぶたびに先頭から1つずつ使う。Exceptionなら投げる。
  final List<Object?> tokens;
  final List<AppleAppCheckProvider> appleProviders = [];
  final List<AndroidAppCheckProvider> androidProviders = [];
  final List<bool> forceRefreshes = [];

  Future<void> activate({
    required AndroidAppCheckProvider providerAndroid,
    required AppleAppCheckProvider providerApple,
  }) async {
    androidProviders.add(providerAndroid);
    appleProviders.add(providerApple);
  }

  Future<String?> getToken({required bool forceRefresh}) async {
    forceRefreshes.add(forceRefresh);
    final next = tokens.removeAt(0);
    if (next is Exception) throw next;
    return next as String?;
  }
}

Future<(AppCheckActivator, _FakeAppCheck, SharedPreferences)> _setUp({
  required bool debug,
  required bool apple,
  bool appAttest = true,
  required List<Object?> tokens,
  Map<String, Object> saved = const {},
}) async {
  SharedPreferences.setMockInitialValues(saved);
  final preferences = await SharedPreferences.getInstance();
  final fake = _FakeAppCheck(tokens);
  final activator = AppCheckActivator(
    preferences: preferences,
    debug: debug,
    apple: apple,
    appAttest: appAttest,
    activate: fake.activate,
    getToken: fake.getToken,
  );
  return (activator, fake, preferences);
}

void main() {
  test('デバッグビルドはDebug Providerで、トークンの確かめをしない', () async {
    final (activator, fake, _) = await _setUp(debug: true, apple: true, tokens: []);
    await activator.activate();
    expect(fake.appleProviders.single, isA<AppleDebugProvider>());
    expect(fake.androidProviders.single, isA<AndroidDebugProvider>());
    expect(activator.verification, isNull);
  });

  test('Androidのリリースビルドは、Play Integrityで確かめをしない', () async {
    final (activator, fake, _) = await _setUp(debug: false, apple: false, tokens: []);
    await activator.activate();
    expect(fake.androidProviders.single, isA<AndroidPlayIntegrityProvider>());
    expect(activator.verification, isNull);
  });

  test('iOSのリリースビルドは、App Attest（DeviceCheckへのフォールバック付き）を使う', () async {
    final (activator, fake, preferences) = await _setUp(debug: false, apple: true, tokens: ['token']);
    await activator.activate();
    await activator.verification;
    expect(fake.appleProviders.single, isA<AppleAppAttestWithDeviceCheckFallbackProvider>());
    // まだ一度も通っていないので、古いトークンを使わずに取り直す
    expect(fake.forceRefreshes, [true]);
    expect(preferences.getBool(AppCheckActivator.appAttestVerifiedKey), isTrue);
  });

  test('devのflavorのiOSのリリースビルドは、DeviceCheckのままで確かめをしない', () async {
    final (activator, fake, _) = await _setUp(debug: false, apple: true, appAttest: false, tokens: []);
    await activator.activate();
    expect(fake.appleProviders.single, isA<AppleDeviceCheckProvider>());
    expect(activator.verification, isNull);
  });

  test('一度通った後は、取り直さずに今のトークンで確かめる', () async {
    final (activator, fake, _) = await _setUp(
      debug: false,
      apple: true,
      tokens: ['token'],
      saved: {AppCheckActivator.appAttestVerifiedKey: true},
    );
    await activator.activate();
    await activator.verification;
    expect(fake.forceRefreshes, [false]);
    expect(fake.appleProviders, hasLength(1));
  });

  test('App Attestでトークンが取れないときは、この起動の間DeviceCheckに切り替える', () async {
    final (activator, fake, preferences) = await _setUp(
      debug: false,
      apple: true,
      tokens: [Exception('attestation failed'), 'device-check-token'],
      saved: {AppCheckActivator.appAttestVerifiedKey: true},
    );
    await activator.activate();
    await activator.verification;
    expect(fake.appleProviders, [
      isA<AppleAppAttestWithDeviceCheckFallbackProvider>(),
      isA<AppleDeviceCheckProvider>(),
    ]);
    expect(fake.androidProviders.last, isA<AndroidPlayIntegrityProvider>());
    expect(fake.forceRefreshes, [false, true]);
    // 次の起動では、また取り直してApp Attestを確かめる
    expect(preferences.getBool(AppCheckActivator.appAttestVerifiedKey), isFalse);
  });

  test('空のトークンも失敗として扱う', () async {
    final (activator, fake, _) = await _setUp(debug: false, apple: true, tokens: [null, 'device-check-token']);
    await activator.activate();
    await activator.verification;
    expect(fake.appleProviders.last, isA<AppleDeviceCheckProvider>());
  });

  test('時間内に取れないときも、DeviceCheckに切り替える', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final fake = _FakeAppCheck([]);
    var calls = 0;
    final activator = AppCheckActivator(
      preferences: preferences,
      debug: false,
      apple: true,
      appAttest: true,
      activate: fake.activate,
      getToken: ({required bool forceRefresh}) async {
        calls++;
        if (calls == 1) {
          await Future<void>.delayed(const Duration(milliseconds: 200));
        }
        return 'token';
      },
      verifyTimeout: const Duration(milliseconds: 20),
    );
    await activator.activate();
    await activator.verification;
    expect(fake.appleProviders.last, isA<AppleDeviceCheckProvider>());
  });

  test('DeviceCheckでも取れないとき（オフラインなど）も、例外を外に出さない', () async {
    final (activator, fake, _) = await _setUp(
      debug: false,
      apple: true,
      tokens: [Exception('offline'), Exception('offline')],
    );
    await activator.activate();
    await expectLater(activator.verification, completes);
    expect(fake.appleProviders.last, isA<AppleDeviceCheckProvider>());
  });
}
