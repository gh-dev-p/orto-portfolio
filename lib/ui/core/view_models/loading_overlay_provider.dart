import 'package:flutter_riverpod/flutter_riverpod.dart';

/// ボタン押下時などの非同期処理中に、画面全体を薄暗くしてタップをブロックする
/// オーバーレイ（[LoadingOverlayHost]）の表示状態を管理する。
///
/// 状態は「実行中の処理の数」。処理が重なってもすべて終わるまで表示を維持する。
/// 破棄されない（autoDisposeでない）ため、処理中に呼び出し元の画面が閉じられても
/// 表示が残り続けることはない（[run]の`finally`で必ず減算される）。
class LoadingOverlayController extends Notifier<int> {
  @override
  int build() => 0;

  /// [action]の実行中だけオーバーレイを表示する。成功・失敗にかかわらず終了時に非表示へ戻し、
  /// 例外は握りつぶさずそのまま呼び出し元へ伝える。
  Future<T> run<T>(Future<T> Function() action) async {
    state++;
    try {
      return await action();
    } finally {
      state--;
    }
  }
}

final loadingOverlayProvider = NotifierProvider<LoadingOverlayController, int>(LoadingOverlayController.new);
