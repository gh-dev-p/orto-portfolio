import 'dart:async';

import '../../services/passcode/passcode_store.dart';

export '../../services/passcode/passcode_attempts.dart';

// ============================================================
// リポジトリ
// ============================================================

/// パスコードのリポジトリ（機能仕様書4.2.4）
/// アカウントごとの4桁のパスコードの設定・照合・削除を扱い、設定の有無の変化を流す
///
/// パスコードは端末内だけに保存する（[PasscodeStore]、Firestoreには送らない）
class PasscodeRepository {
  PasscodeRepository(this._store);

  // ---- 状態・初期化 ----

  /// パスコードの保存先のサービス
  final PasscodeStore _store;

  /// 設定・削除したアカウントのIDを流す
  /// [watchEnabled]が、変わったアカウントの設定の有無を読み直すのに使う
  final _changes = StreamController<String>.broadcast();

  /// パスコードの桁数
  static const length = PasscodeStore.length;

  // ---- 設定の有無 ----

  /// アカウント[accountId]にパスコードが設定されているかを監視する
  /// 設定・削除のたびに読み直して流す（保存領域が読めないときは、素通りさせないよう設定ありとして扱う）
  Stream<bool> watchEnabled(String accountId) {
    late final StreamController<bool> controller;
    StreamSubscription<String>? subscription;
    // 読み直しが重なっても、新しい結果が古い結果に上書きされないよう、順番に読む。
    var pending = Future<void>.value();
    void emit() {
      pending = pending.then((_) async {
        final enabled = await _store.isEnabled(accountId);
        if (!controller.isClosed) controller.add(enabled);
      });
    }

    controller = StreamController<bool>(
      onListen: () {
        subscription = _changes.stream.where((id) => id == accountId).listen((_) => emit());
        emit();
      },
      onCancel: () => subscription?.cancel(),
    );
    return controller.stream;
  }

  // ---- 設定・照合・削除 ----

  /// アカウント[accountId]のパスコードを[passcode]（数字4桁）に設定する（上書き）
  Future<void> save(String accountId, String passcode) async {
    await _store.save(accountId, passcode);
    _changes.add(accountId);
  }

  /// [passcode]が、アカウント[accountId]に設定したパスコードと一致するか
  /// 未設定・保存値の破損・読み取りの失敗ならfalse
  Future<bool> verify(String accountId, String passcode) => _store.verify(accountId, passcode);

  /// [passcode]を照合し、誤りの回数に反映する（待ち時間の間は照合しない）
  Future<PasscodeAttemptResult> attempt(String accountId, String passcode) => _store.attempt(accountId, passcode);

  /// アカウント[accountId]の、今の入力の制限
  Future<PasscodeLockout> lockout(String accountId) => _store.lockout(accountId);

  /// アカウント[accountId]にパスコードが設定されているか
  Future<bool> isEnabled(String accountId) => _store.isEnabled(accountId);

  /// アカウント[accountId]のパスコードを削除する
  /// 保存領域が壊れて個別に消せないときは、領域ごと消す（他のアカウントのパスコードも消える。[PasscodeStore.remove]）。消せなければ例外を投げる
  Future<void> remove(String accountId) async {
    try {
      await _store.remove(accountId);
    } finally {
      // 領域ごと消した場合や、途中で失敗した場合も、表示を実際の状態に合わせる。
      _changes.add(accountId);
    }
  }
}
