import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/invite_links.dart';
import '../../../config/service_providers.dart';
import '../../../domain/models/account.dart';
import '../../account/view_models/account_providers.dart';

// ============================================================
// enum
// ============================================================

/// QRC-01の読み取りの失敗
/// Viewが表示の文言に変換する
enum QrScanError {
  /// 自分のQRコードを読み取った
  selfAdd,

  /// 見つからなかった（このアプリのQRでない・退会済み・ブロック関係にあるアカウントも含む）
  notFound,
}

// ============================================================
// 状態クラス
// ============================================================

/// QRC-01（QRコード）の状態
class QrScanState {
  const QrScanState({this.myAccount, this.resolving = false, this.error});

  /// 使用中のアカウント
  /// マイQRコードに表示する（使用中のアカウントが無ければnull）
  final Account? myAccount;

  /// 読み取ったQRコードを、アカウントに解決中か
  final bool resolving;

  /// 直前の読み取りの失敗
  /// 失敗していなければnull
  final QrScanError? error;
}

// ============================================================
// ViewModel
// ============================================================

/// QRC-01（QRコード：読み取り・マイQRコード）のViewModel
/// 読み取ったQRコードをアカウントに解決し、マイQRコードに使用中のアカウントを渡す
///
/// カメラの起動・停止（`MobileScannerController`）は、ハードウェアの制御の都合でViewが行う。解決できたアカウントは状態に持たず、[resolve]の戻り値で返す
///
/// 機能仕様書：4.3.1 / 画面設計書：5.5.1・5.5.2
class QrScanViewModel extends Notifier<QrScanState> {
  // ---- 状態・初期化 ----

  /// 表示内容を作る
  /// 使用中のアカウントを監視し、変わったら、読み取りの状態を残したまま差し替える
  @override
  QrScanState build() {
    final myAccount = ref.watch(activeAccountProvider);
    final previous = stateOrNull;
    return QrScanState(myAccount: myAccount, resolving: previous?.resolving ?? false, error: previous?.error);
  }

  // ---- 読み取り ----

  /// 読み取ったQRコードの友だちの招待（[InviteLinks.qrInviteFrom]で読んだアカウントID）を、アカウントに解決する
  /// 解決できたらそのアカウント。招待でない（[accountId]がnull）・自分自身・見つからない場合はnullを返し、失敗を状態に入れる
  /// （招待のQRコードでなければ、無関係なQRを誤って解決しないよう、検索自体をしない。データ設計書4.1）
  Future<Account?> resolve({required String? accountId, required String myAccountId}) async {
    if (accountId == null) {
      _setResult(error: QrScanError.notFound);
      return null;
    }

    if (accountId == myAccountId) {
      _setResult(error: QrScanError.selfAdd);
      return null;
    }

    state = QrScanState(myAccount: state.myAccount, resolving: true);

    Account? found;
    try {
      found = await ref.read(accountRepositoryProvider).getAccount(accountId);
    } catch (_) {
      found = null;
    }

    if (!ref.mounted) return found;

    // 退会済みのアカウントは友だち追加の対象外のため、無い場合と同じ扱いにする。
    if (found == null || found.isDeleted) {
      _setResult(error: QrScanError.notFound);
      return null;
    }

    // ブロック関係にあるアカウントは、ID検索（FRI-04）と同じく「見つからない」扱いにする
    // （ブロックした事実を悟らせない）。
    final blocked = await ref.read(blockRepositoryProvider).isBlockedEitherWay(myAccountId, found.id);
    if (!ref.mounted) return null;
    if (blocked) {
      _setResult(error: QrScanError.notFound);
      return null;
    }

    _setResult();
    return found;
  }

  /// 解決を終え、結果（失敗なら[error]）を状態に入れる
  void _setResult({QrScanError? error}) => state = QrScanState(myAccount: state.myAccount, error: error);
}

// ============================================================
// Provider
// ============================================================

/// [QrScanViewModel]のProvider
/// 誰も監視しなくなったら破棄される（autoDispose）
final qrScanViewModelProvider = NotifierProvider.autoDispose<QrScanViewModel, QrScanState>(QrScanViewModel.new);
