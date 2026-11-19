import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/service_providers.dart';
import '../../../domain/models/account.dart';
import '../../account/view_models/account_providers.dart';

// ============================================================
// 状態クラス
// ============================================================

/// PRO-03（プロフィール編集）の状態
class ProfileEditState {
  const ProfileEditState({
    this.account,
    this.uploadingBackground = false,
    this.uploadingPhoto = false,
    this.pendingAllowIdSearch,
  });

  /// 編集するアカウント
  /// Firestoreの最新の内容（保存した内容も監視を通してそのまま反映される）。取得前はnull
  final Account? account;

  /// 背景画像をアップロード中か
  /// 背景のバナーにだけスピナーを出す（アバターとは別々に出すため、1つの読み込み中にまとめない）
  final bool uploadingBackground;

  /// プロフィール画像をアップロード中か
  /// アバターにだけスピナーを出す
  final bool uploadingPhoto;

  /// 「IDによる友だち追加を許可」を切り替えてから、保存が終わるまでの間の値
  /// nullならアカウントの値をそのまま表示する
  final bool? pendingAllowIdSearch;

  /// 「IDによる友だち追加を許可」に表示する値
  /// 保存中は切り替えた値、それ以外はアカウントの値
  bool get allowIdSearch => pendingAllowIdSearch ?? account?.allowIdSearch ?? false;

  /// 指定した項目だけを変えた、新しい状態を作る
  /// 指定しなかった項目は今の値を引き継ぐ（pendingAllowIdSearchは[clearPendingAllowIdSearch]がtrueなら消す）
  ProfileEditState copyWith({
    Account? account,
    bool? uploadingBackground,
    bool? uploadingPhoto,
    bool? pendingAllowIdSearch,
    bool clearPendingAllowIdSearch = false,
  }) {
    return ProfileEditState(
      account: account ?? this.account,
      uploadingBackground: uploadingBackground ?? this.uploadingBackground,
      uploadingPhoto: uploadingPhoto ?? this.uploadingPhoto,
      pendingAllowIdSearch: clearPendingAllowIdSearch ? null : pendingAllowIdSearch ?? this.pendingAllowIdSearch,
    );
  }
}

// ============================================================
// ViewModel
// ============================================================

/// PRO-03（プロフィール編集）のViewModel
/// 各行を編集し終えたときに、その項目だけをすぐに保存する（画面全体の保存ボタンは無い）
///
/// 機能仕様書：4.5.1 / 画面設計書：5.7.3
class ProfileEditViewModel extends Notifier<ProfileEditState> {
  ProfileEditViewModel(this.accountId);

  // ---- 状態・初期化 ----

  /// 編集するアカウントのID
  final String accountId;

  /// 表示内容を作る
  /// 編集するアカウントを監視し、変わったら、アップロード中・保存中の表示を残したまま差し替える
  @override
  ProfileEditState build() {
    final account = ref.watch(accountByIdProvider(accountId)).value;
    return stateOrNull?.copyWith(account: account) ?? ProfileEditState(account: account);
  }

  // ---- 保存 ----

  /// 背景画像・プロフィール画像をアップロードして保存する
  /// 成功したらtrue
  Future<bool> uploadImage({required bool isBackground, required File file}) async {
    state = isBackground ? state.copyWith(uploadingBackground: true) : state.copyWith(uploadingPhoto: true);
    final repository = ref.read(accountRepositoryProvider);
    try {
      if (isBackground) {
        await repository.updateBackgroundImage(accountId: accountId, image: file);
      } else {
        await repository.updateProfileImage(accountId: accountId, image: file);
      }
      return true;
    } catch (_) {
      return false;
    } finally {
      if (ref.mounted) {
        state = isBackground ? state.copyWith(uploadingBackground: false) : state.copyWith(uploadingPhoto: false);
      }
    }
  }

  /// 表示名を保存する
  /// 成功したらtrue
  Future<bool> updateDisplayName(String value) => _save(() async {
    await ref.read(accountRepositoryProvider).updateProfile(accountId: accountId, displayName: value);
  });

  /// ひとことを保存する
  /// 成功したらtrue
  Future<bool> updateBio(String value) => _save(() async {
    await ref.read(accountRepositoryProvider).updateProfile(accountId: accountId, bio: value);
  });

  /// 「IDによる友だち追加を許可」を切り替えて保存する（画面設計書5.7.3構成要素9）
  /// 保存が終わるまでは切り替えた値を表示し、失敗したらアカウントの値に戻す。成功したらtrue
  Future<bool> toggleAllowIdSearch(bool value) async {
    state = state.copyWith(pendingAllowIdSearch: value);
    final saved = await _save(() async {
      await ref.read(accountRepositoryProvider).updateProfile(accountId: accountId, allowIdSearch: value);
    });
    if (ref.mounted) state = state.copyWith(clearPendingAllowIdSearch: true);
    return saved;
  }

  /// [save]を実行する
  /// 成功したらtrue、例外が出たらfalse
  Future<bool> _save(Future<void> Function() save) async {
    try {
      await save();
      return true;
    } catch (_) {
      return false;
    }
  }
}

// ============================================================
// Provider
// ============================================================

/// [ProfileEditViewModel]のProvider
/// 引数は編集するアカウントのID。誰も監視しなくなったら破棄される（autoDispose）
final profileEditViewModelProvider = NotifierProvider.autoDispose
    .family<ProfileEditViewModel, ProfileEditState, String>(ProfileEditViewModel.new);
