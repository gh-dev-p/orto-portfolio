import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ============================================================
// サービス
// ============================================================

/// 端末のFirestoreのキャッシュ（メッセージ・友だち等の写し）の消去（機能仕様書4.1.5）
/// 退会しても端末に前の持ち主のデータを残さないために使う
///
/// `clearPersistence`はFirestoreを使い始める前にしか呼べないため、退会のときは印だけ付け、次の起動で消す
class FirestoreCacheCleaner {
  FirestoreCacheCleaner(this._preferences);

  /// 端末内の設定の保存先
  final SharedPreferences _preferences;

  /// 消去の予定の印のキー
  static const _key = 'firestoreCacheClearRequested';

  /// 次の起動での消去を予定する
  Future<void> request() => _preferences.setBool(_key, true);

  /// 予定があれば消す
  /// 起動時、Firestoreを使い始める前に呼ぶ。失敗したら印を残し、次の起動でやり直す
  Future<void> clearIfRequested(FirebaseFirestore firestore) async {
    if (!(_preferences.getBool(_key) ?? false)) return;
    await firestore.clearPersistence();
    await _preferences.remove(_key);
  }
}
