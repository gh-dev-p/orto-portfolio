import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/reserved_account_ids.dart';
import '../../../config/service_providers.dart';
import '../../../data/repositories/account/account_repository.dart';
import '../../../utils/validators.dart';
import '../../friend/view_models/invite_link_provider.dart';
import 'account_providers.dart';
import 'active_account_provider.dart';

// ============================================================
// enum
// ============================================================

/// アカウント作成の失敗の種類
/// 表示文言への変換はView側で行う
enum AccountCreationError {
  /// 作成しようとしたときに、アカウントIDが既に使われていた
  idTaken,

  /// アカウントの削除を繰り返したため、しばらく作成できない（機能仕様書4.2.3）
  blocked,

  /// そのほかの失敗
  unknown,
}

/// アカウント作成の結果
enum AccountCreationOutcome {
  /// 作成できた
  created,

  /// アカウントは作成できたが、画像のアップロードだけ失敗した
  createdWithoutImage,

  /// 作成できなかった
  failed,
}

// ============================================================
// 状態クラス
// ============================================================

/// copyWithで「指定されなかった」ことを表す目印
const _unset = Object();

/// ACC-02（アカウント作成画面）の状態
class AccountCreationState {
  const AccountCreationState({
    this.displayName = '',
    this.accountId = '',
    this.image,
    this.inviterAccountId = '',
    this.idAvailable,
    this.busy = false,
    this.errorCode,
  });

  /// 入力中の表示名（入力されたまま）
  final String displayName;

  /// 入力中のアカウントID（入力されたまま）
  final String accountId;

  /// 入力中の、招待してくれた人のアカウントID（任意。1つ目のアカウントの作成のときだけ入力欄を出す。機能仕様書4.3.5.2）
  final String inviterAccountId;

  /// 選んだプロフィール画像
  /// 選んでいなければnull
  final File? image;

  /// アカウントIDが使えるかの確認結果
  /// null：未確認（または入力を変えたため、確認し直しが必要）
  final bool? idAvailable;

  /// アカウントIDの確認中、または作成中か
  /// 1つのフラグで表すため、確認中も作成ボタンを押せなくなる（二重送信の防止として許容。確認済み）
  final bool busy;

  /// 作成の失敗の種類（null：失敗していない）
  final AccountCreationError? errorCode;

  /// 表示名が正しいか
  /// 前後の空白を除いて1〜20文字
  bool get displayNameValid => isValidTrimmedLength(displayName, minLength: 1, maxLength: 20);

  /// アカウントIDの形式が正しいか
  bool get accountIdFormatValid => isValidAccountIdFormat(accountId.trim());

  /// アカウントIDが予約されたIDか
  /// 予約されたIDは使えない
  bool get accountIdReserved => isReservedAccountId(accountId);

  /// アカウントIDが、使えるかの確認・作成に進める形か
  /// 形式が正しく、予約されたIDでないときtrue
  bool get accountIdUsable => accountIdFormatValid && !accountIdReserved;

  /// 招待してくれた人のアカウントIDが、空か正しい形式か
  bool get inviterAccountIdValid => inviterAccountId.trim().isEmpty || isValidAccountIdFormat(inviterAccountId.trim());

  /// 作成ボタンを押せるか
  bool get canCreate => displayNameValid && accountIdUsable && inviterAccountIdValid && !busy;

  /// 指定した項目だけを変えた、新しい状態を作る
  /// 指定しなかった項目は今の値を引き継ぐ（image・idAvailable・errorCodeはnullを渡すと消える）
  AccountCreationState copyWith({
    String? displayName,
    String? accountId,
    String? inviterAccountId,
    Object? image = _unset,
    Object? idAvailable = _unset,
    bool? busy,
    Object? errorCode = _unset,
  }) {
    return AccountCreationState(
      displayName: displayName ?? this.displayName,
      accountId: accountId ?? this.accountId,
      inviterAccountId: inviterAccountId ?? this.inviterAccountId,
      image: identical(image, _unset) ? this.image : image as File?,
      idAvailable: identical(idAvailable, _unset) ? this.idAvailable : idAvailable as bool?,
      busy: busy ?? this.busy,
      errorCode: identical(errorCode, _unset) ? this.errorCode : errorCode as AccountCreationError?,
    );
  }
}

// ============================================================
// ViewModel
// ============================================================

/// ACC-02（アカウント作成画面）のViewModel
/// 表示名・アカウントID・プロフィール画像の入力と、アカウントIDが使えるかの確認・作成を扱う
///
/// 機能仕様書：4.2.1 / 画面設計書：5.2.2
class AccountCreationViewModel extends Notifier<AccountCreationState> {
  // ---- 状態・初期化 ----

  /// 最初の状態を作る
  /// 何も入力していない状態から始める
  @override
  AccountCreationState build() => const AccountCreationState();

  // ---- 入力 ----

  /// 表示名の入力を更新する
  void updateDisplayName(String value) => state = state.copyWith(displayName: value);

  /// アカウントIDの入力を更新する
  /// 前回の確認結果は捨てる（確認し直しが必要な状態に戻す）
  void updateAccountId(String value) => state = state.copyWith(accountId: value, idAvailable: null);

  /// 招待してくれた人のアカウントIDの入力を更新する
  void updateInviterAccountId(String value) => state = state.copyWith(inviterAccountId: value);

  /// プロフィール画像を選ぶ
  void selectImage(File image) => state = state.copyWith(image: image);

  // ---- 確認・作成 ----

  /// アカウントIDが使えるかを確認する
  /// 結果は[AccountCreationState.idAvailable]に入る（確認に失敗したら未確認のまま）。確認・作成中なら何もしない
  Future<void> checkIdAvailability() async {
    if (state.busy || !state.accountIdUsable) return;
    final accountId = state.accountId.trim();
    state = state.copyWith(busy: true);
    try {
      final available = await ref.read(accountRepositoryProvider).isAccountIdAvailable(accountId);
      if (ref.mounted) state = state.copyWith(busy: false, idAvailable: available);
    } catch (_) {
      if (ref.mounted) state = state.copyWith(busy: false, idAvailable: null);
    }
  }

  /// アカウントを作成する
  /// 結果を返す（画像のアップロードだけ失敗した場合もアカウントは作成済みで、View側でその旨を知らせる。画面設計書5.2.2）
  ///
  /// 作成したアカウントをアクティブアカウントにする
  Future<AccountCreationOutcome> create() async {
    if (!state.canCreate) return AccountCreationOutcome.failed;
    final accountId = state.accountId.trim();
    final displayName = state.displayName.trim();
    final image = state.image;
    final inviterAccountId = state.inviterAccountId.trim();
    state = state.copyWith(busy: true, errorCode: null);

    // 作成の書き込みは、サーバーの完了を待つ前に端末のアカウント一覧（accountsProvider）に届く。1つ目のアカウントでは、
    // 届いた時点で使用中のアカウントが無いと入口（AccountGate）がACC-01に切り替わり、本画面とこのViewModelが破棄されて、
    // 以降の処理（招待の保存・使用中のアカウントの設定）が動かなかった。そのため、
    // ・使う側のNotifier（破棄されないProvider）は最初に取っておき、ViewModelが破棄された後も使えるようにする
    // ・1つ目のアカウントは、書き込みの前に使用中のアカウントと招待を入れておき、一覧に届いた時点でホームへ進ませる
    //   （失敗したら元に戻す。アカウントが無い間は、使用中のアカウントがあっても入口はACC-02のまま）
    final activeAccount = ref.read(activeAccountIdProvider.notifier);
    final pendingInvite = ref.read(pendingInviteProvider.notifier);
    final isFirstAccount = (ref.read(accountsProvider).value ?? const []).isEmpty;
    // 招待してくれた人を入れたら、招待リンクを開いたときと同じく、ホームでPRO-01へ進む。
    // 招待リンク・貼り付けで受け取った招待があれば、そちらを優先する。
    final setsInvite = inviterAccountId.isNotEmpty && ref.read(pendingInviteProvider) == null;
    if (isFirstAccount) {
      if (setsInvite) pendingInvite.set(inviterAccountId);
      await activeAccount.setActive(accountId);
    }

    try {
      final repository = ref.read(accountRepositoryProvider);
      final user = ref.read(authRepositoryProvider).currentUser;
      if (user == null) {
        await _undoFirstAccount(isFirstAccount, setsInvite, activeAccount, pendingInvite);
        if (ref.mounted) state = state.copyWith(busy: false);
        return AccountCreationOutcome.failed;
      }

      final account = await repository.createAccount(
        accountId: accountId,
        uid: user.uid,
        displayName: displayName,
        phoneNumber: user.phoneNumber,
      );

      if (!isFirstAccount) {
        if (setsInvite) pendingInvite.set(inviterAccountId);
        await activeAccount.setActive(account.id);
      }

      var imageUploadFailed = false;
      if (image != null) {
        try {
          await repository.updateProfileImage(accountId: account.id, image: image);
        } catch (_) {
          // 画像のアップロードに失敗したら、画面設計書5.2.2の異常系に倣い、画像なしで作成を完了させる（失敗した旨はView側で知らせる）。
          imageUploadFailed = true;
        }
      }

      if (ref.mounted) state = const AccountCreationState();
      return imageUploadFailed ? AccountCreationOutcome.createdWithoutImage : AccountCreationOutcome.created;
    } on AccountIdTakenException {
      // 使用可能の事前確認の後に、他のユーザが先に使った場合（「一意性保証」）。
      await _undoFirstAccount(isFirstAccount, setsInvite, activeAccount, pendingInvite);
      if (ref.mounted) {
        state = state.copyWith(busy: false, idAvailable: false, errorCode: AccountCreationError.idTaken);
      }
      return AccountCreationOutcome.failed;
    } on AccountCreationBlockedException {
      await _undoFirstAccount(isFirstAccount, setsInvite, activeAccount, pendingInvite);
      if (ref.mounted) state = state.copyWith(busy: false, errorCode: AccountCreationError.blocked);
      return AccountCreationOutcome.failed;
    } catch (_) {
      await _undoFirstAccount(isFirstAccount, setsInvite, activeAccount, pendingInvite);
      if (ref.mounted) state = state.copyWith(busy: false, errorCode: AccountCreationError.unknown);
      return AccountCreationOutcome.failed;
    }
  }

  /// 1つ目のアカウントの作成に失敗したら、書き込みの前に入れた使用中のアカウントと招待を元に戻す
  Future<void> _undoFirstAccount(
    bool isFirstAccount,
    bool setsInvite,
    ActiveAccountNotifier activeAccount,
    PendingInviteNotifier pendingInvite,
  ) async {
    if (!isFirstAccount) return;
    if (setsInvite) pendingInvite.clear();
    await activeAccount.clear();
  }
}

// ============================================================
// Provider
// ============================================================

/// [AccountCreationViewModel]のProvider
/// 誰も監視しなくなったら破棄される（autoDispose）
final accountCreationViewModelProvider = NotifierProvider.autoDispose<AccountCreationViewModel, AccountCreationState>(
  AccountCreationViewModel.new,
);
