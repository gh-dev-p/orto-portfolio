import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/service_providers.dart';

// ============================================================
// ViewModel
// ============================================================

/// アクティブアカウント（現在操作しているアカウント）のIDを持つNotifier
/// アプリ全体で共有し、変更は[ActiveAccountRepository]で端末内に保存する（アプリの再起動後も引き継ぐ。機能仕様書4.2.2）
class ActiveAccountNotifier extends Notifier<String?> {

  // ---- 状態・初期化 ----

  /// 最初の状態を作る
  /// 端末内に保存しているIDから始める（起動時に読み込み済みのため、復元を待つ間に未選択の状態が一瞬見えることはない）
  @override
  String? build() => ref.watch(activeAccountRepositoryProvider).read();

  // ---- 操作 ----

  /// アクティブアカウントを切り替える
  /// 切り替えたIDを端末内に保存する
  Future<void> setActive(String accountId) async {
    state = accountId;
    await ref.read(activeAccountRepositoryProvider).save(accountId);
  }

  /// アクティブアカウントを未選択に戻す
  /// サインアウト時（退会・AUT-05から電話番号の入力に戻るとき・管理者のログアウト）と、AUT-04（パスコードのガード）を閉じるときに呼ぶ（別のユーザが同じ端末で再ログインしたときに、前のユーザのアクティブアカウントを引き継がないため）
  Future<void> clear() async {
    state = null;
    await ref.read(activeAccountRepositoryProvider).clear();
  }
}

// ============================================================
// Provider
// ============================================================

/// [ActiveAccountNotifier]のProvider
/// アプリ全体で共有するため、破棄しない
final activeAccountIdProvider = NotifierProvider<ActiveAccountNotifier, String?>(ActiveAccountNotifier.new);
