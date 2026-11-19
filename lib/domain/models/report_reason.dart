/// 通報の理由（機能仕様書4.3.6）
/// Firestoreには[value]の文字列で保存する（firestore.rulesの`reports`で許可する値と揃える）
enum ReportReason {
  /// スパム・宣伝
  spam('spam'),

  /// 嫌がらせ・いじめ
  harassment('harassment'),

  /// なりすまし
  impersonation('impersonation'),

  /// 不適切なコンテンツ（性的・暴力的な内容等）
  inappropriate('inappropriate'),

  /// その他
  other('other');

  const ReportReason(this.value);

  /// Firestoreに保存する値
  final String value;
}
