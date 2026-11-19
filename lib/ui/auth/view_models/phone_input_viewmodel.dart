import 'package:country_picker/country_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phone_numbers_parser/phone_numbers_parser.dart';

import '../../../config/service_providers.dart';
import '../../../data/repositories/auth/auth_repository.dart';
import '../../../utils/phone_number_normalize.dart';
import 'auth_providers.dart';

// ============================================================
// 状態クラス
// ============================================================

/// copyWithで「errorCodeが指定されなかった」ことを表す目印
const _unset = Object();

/// AUT-02（電話番号入力画面）の状態
class PhoneInputState {
  const PhoneInputState({required this.country, this.input = '', this.sending = false, this.errorCode});

  /// 選んでいる国・地域
  /// 初期値は日本
  final Country country;

  /// 入力中の電話番号（入力されたまま）
  final String input;

  /// SMSを送信中か
  final bool sending;

  /// エラーの種類（null：エラーなし）
  /// 表示文言への変換はView側で行う
  final AuthErrorCode? errorCode;

  /// 入力をE.164形式に正規化した電話番号
  /// 選んでいる国・地域の番号として解釈する（番号が正しくない場合はnull）
  String? get normalized => normalizePhoneNumberToE164(input, isoCountryCode: country.countryCode);

  /// 入力が電話番号として正しいか
  /// 正規化できた（[normalized]がnullでない）ときtrue
  bool get isValid => normalized != null;

  /// 指定した項目だけを変えた、新しい状態を作る
  /// 指定しなかった項目は今の値を引き継ぐ（errorCodeはnullを渡すと消える）
  PhoneInputState copyWith({Country? country, String? input, bool? sending, Object? errorCode = _unset}) {
    return PhoneInputState(
      country: country ?? this.country,
      input: input ?? this.input,
      sending: sending ?? this.sending,
      errorCode: identical(errorCode, _unset) ? this.errorCode : errorCode as AuthErrorCode?,
    );
  }
}

// ============================================================
// ViewModel
// ============================================================

/// AUT-02（電話番号入力画面）のViewModel
/// サインインと、電話番号の変更（[phoneNumberChange]、SET-01から開く）の2つの用途で使う
///
/// 機能仕様書：4.1.1・4.1.3 / 画面設計書：5.1.2
class PhoneInputViewModel extends Notifier<PhoneInputState> {
  PhoneInputViewModel(this.phoneNumberChange);

  // ---- 状態・初期化 ----

  /// 電話番号の変更として開いたか
  final bool phoneNumberChange;

  /// 最初の状態を作る
  /// 国・地域は日本から始める
  @override
  PhoneInputState build() => PhoneInputState(country: Country.parse('JP'));

  /// 何のための認証か
  PhoneVerificationPurpose get purpose =>
      phoneNumberChange ? PhoneVerificationPurpose.phoneNumberChange : PhoneVerificationPurpose.signIn;

  // ---- 入力 ----

  /// 国・地域を選び直す
  /// 同じ国なら何もしない。変えたらエラーを消し、入力をその国の番号として解釈し直す
  void selectCountry(Country country) {
    if (country.countryCode == state.country.countryCode) return;
    state = state.copyWith(country: country, errorCode: null);
  }

  /// 入力を更新する
  /// 前回のエラー表示は消す
  void updateInput(String input) => state = state.copyWith(input: input, errorCode: null);

  // ---- 送信 ----

  /// 入力された番号宛に認証コードを送る
  /// 結果を返す（[VerificationStart.codeSent]ならAUT-03へ進む）。番号が正しくない・送信中・失敗ならfailed（失敗の理由はerrorCodeに入る）
  ///
  /// 電話番号の変更では、今と同じ番号ならエラーにする。端末の自動検証で完了したら、ここで後処理まで行う
  Future<VerificationStart> submit() async {
    final normalized = state.normalized;
    // 番号が無効、または送信中なら何もしない（連打で二重送信しないため）
    if (normalized == null || state.sending) return VerificationStart.failed;

    final repository = ref.read(authRepositoryProvider);
    if (phoneNumberChange && normalized == repository.currentUser?.phoneNumber) {
      state = state.copyWith(errorCode: AuthErrorCode.samePhoneNumber);
      return VerificationStart.failed;
    }

    state = state.copyWith(sending: true, errorCode: null);
    try {
      final result = await repository.startVerification(purpose: purpose, phoneNumber: normalized);
      if (result == VerificationStart.verified) await completePhoneVerification(ref, purpose);
      if (ref.mounted) state = state.copyWith(sending: false);
      return result;
    } on AuthException catch (e) {
      if (ref.mounted) state = state.copyWith(sending: false, errorCode: e.code);
      return VerificationStart.failed;
    }
  }
}

// ============================================================
// Provider
// ============================================================

/// [PhoneInputViewModel]のProvider
/// 引数は電話番号の変更として開いたか。誰も監視しなくなったら破棄される（autoDispose）
final phoneInputViewModelProvider = NotifierProvider.autoDispose.family<PhoneInputViewModel, PhoneInputState, bool>(
  PhoneInputViewModel.new,
);

// ============================================================
// 定数
// ============================================================

/// 国・地域の一覧に出す国
/// country_pickerの国のうち、phone_numbers_parserで番号を検証できるもの
final List<String> selectableCountryCodes = () {
  final supported = IsoCode.values.asNameMap();
  return CountryService().getAll().map((c) => c.countryCode).where(supported.containsKey).toList();
}();
