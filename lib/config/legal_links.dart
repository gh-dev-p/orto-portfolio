/// お問い合わせ・プライバシーポリシー・利用規約・特定商取引法の表記の連絡先／URL（SET-01、SET-07）。
///
/// 公開ページは運営者のWebサイトにあり、日本語と英語（翻訳）の2つを持つ。
abstract final class LegalLinks {
  /// 利用規約とプライバシーポリシーの今の版（最終改定日）。Cloud Functionsの`LEGAL_DOCUMENT_VERSION`と揃える。
  /// これより前の版にしか同意していない人には、ホームで再同意を求める。
  static const documentVersion = '2026-11-19';

  /// お問い合わせ先メールアドレス。
  static const contactEmail = 'support@example.com';

  static const _siteOrigin = 'https://orto.example.com';

  /// 表示言語が日本語なら日本語のページ、それ以外は英語のページ。
  static String _pageUrl(String languageCode, String page) =>
      languageCode == 'ja' ? '$_siteOrigin/$page' : '$_siteOrigin/en/$page';

  static String privacyPolicyUrl(String languageCode) => _pageUrl(languageCode, 'privacy');

  static String termsOfServiceUrl(String languageCode) => _pageUrl(languageCode, 'terms');

  static String tokushohoUrl(String languageCode) => _pageUrl(languageCode, 'legal/commerce');
}
