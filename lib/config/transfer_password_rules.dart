/// 引き継ぎパスワードの文字数の範囲（firebase/functions/index.jsと同じ値）。
abstract final class TransferPasswordRules {
  static const minLength = 8;
  static const maxLength = 64;
}
