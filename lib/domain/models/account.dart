import 'package:cloud_firestore/cloud_firestore.dart';

import '../../utils/storage_image_url.dart';
import 'firestore_values.dart';

/// `accounts/{accountId}` ドキュメント。
/// accountId（ドキュメントID）＝アカウントID（検索用ID、作成後不変）。
/// データ設計書 3.2 参照。
class Account {
  const Account({
    required this.id,
    required this.displayName,
    this.photoURL,
    this.backgroundURL,
    this.allowIdSearch = true,
    this.bio,
    this.isDeleted = false,
  });

  final String id;
  final String displayName;
  final String? photoURL;
  final String? backgroundURL;
  final bool allowIdSearch;

  /// ひとこと（PRO-03で編集する任意項目）。
  final String? bio;

  /// ソフトデリートフラグ（機能仕様書4.2.3・データ設計書3.2）。trueの場合、
  /// UI上は実データに関わらず「退会済みアカウント」として表示する。
  final bool isDeleted;

  /// 他の人の画面に出すプロフィール画像・背景画像・ひとこと。退会済み（[isDeleted]）なら、ドキュメントに
  /// 値が残っていても出さない（UI上は実データに関わらず「退会済みアカウント」として表示する。データ設計書3.2）。
  /// アカウント削除（ACC-03）では画像URL・ひとことがドキュメントに残るため、表示側で必ずこちらを使う。
  String? get visiblePhotoURL => isDeleted ? null : photoURL;
  String? get visibleBackgroundURL => isDeleted ? null : backgroundURL;
  String? get visibleBio => isDeleted ? null : bio;

  factory Account.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    // 自分のアカウントの画像でないURLは無いものとして扱う（古いドキュメント・古いルールへの備え。データ設計書7.1）
    String? ownImage(Object? url) => url is String && isOwnImageUrl(url, doc.id) ? url : null;
    return Account(
      id: doc.id,
      displayName: stringOrNull(data['displayName']) ?? '',
      photoURL: ownImage(data['photoURL']),
      backgroundURL: ownImage(data['backgroundURL']),
      allowIdSearch: data['allowIdSearch'] is bool ? data['allowIdSearch'] as bool : true,
      bio: stringOrNull(data['bio']),
      isDeleted: data['isDeleted'] == true,
    );
  }

  Account copyWith({
    String? displayName,
    String? photoURL,
    String? backgroundURL,
    bool? allowIdSearch,
    String? bio,
    bool? isDeleted,
  }) => Account(
    id: id,
    displayName: displayName ?? this.displayName,
    photoURL: photoURL ?? this.photoURL,
    backgroundURL: backgroundURL ?? this.backgroundURL,
    allowIdSearch: allowIdSearch ?? this.allowIdSearch,
    bio: bio ?? this.bio,
    isDeleted: isDeleted ?? this.isDeleted,
  );

  /// 公開プロフィールのみ。保有ユーザのuidも時刻も持たない（データ設計書3.2）。
  Map<String, dynamic> toFirestore() => {
    'accountId': id,
    'displayName': displayName,
    'photoURL': photoURL,
    'backgroundURL': backgroundURL,
    'allowIdSearch': allowIdSearch,
    'bio': bio,
    'isDeleted': isDeleted,
  };
}

/// 退会済み（`isDeleted: true`）の場合は実際の表示名を隠し、「退会済みアカウント」に
/// 差し替える（機能仕様書4.3.2・4.4.1・4.4.3・4.2.3）。ニックネームより優先する。
///
/// 本モデル層はBuildContextに依存しないため（architecture-design.md 2章）、
/// フォールバック文言はAppLocalizations経由で解決した文字列を呼び出し元
/// （View）から渡してもらう（commonUnknownAccount／commonDeletedAccount）。
String resolveDisplayName(
  Account? account, {
  String? nickname,
  required String unknownAccountLabel,
  required String deletedAccountLabel,
}) {
  if (account == null) return unknownAccountLabel;
  if (account.isDeleted) return deletedAccountLabel;
  return nickname ?? account.displayName;
}
