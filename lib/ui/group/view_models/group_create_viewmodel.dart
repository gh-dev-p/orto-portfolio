import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/service_providers.dart';
import '../../../domain/models/group.dart';

// ============================================================
// enum・定数
// ============================================================

/// グループ名の最大文字数（Cloud Functionsの`createGroup`と揃える）
const groupNameMaxLength = 50;

// ============================================================
// 状態クラス
// ============================================================

/// GRP-02（グループ作成）の状態
class GroupCreateState {
  const GroupCreateState({this.name = '', this.image, this.joinPolicy = GroupJoinPolicy.approval});

  /// 入力中のグループ名
  final String name;

  /// 選んだ画像（任意）
  final File? image;

  /// 友だち選択の招待の方式
  final GroupJoinPolicy joinPolicy;

  /// 前後の空白を除いたグループ名
  String get trimmedName => name.trim();

  /// 作成できるか
  bool get canCreate => trimmedName.isNotEmpty && trimmedName.runes.length <= groupNameMaxLength;

  /// 指定した項目だけを変えた、新しい状態を作る
  GroupCreateState copyWith({String? name, File? image, GroupJoinPolicy? joinPolicy}) {
    return GroupCreateState(
      name: name ?? this.name,
      image: image ?? this.image,
      joinPolicy: joinPolicy ?? this.joinPolicy,
    );
  }
}

// ============================================================
// ViewModel
// ============================================================

/// GRP-02（グループ作成）のViewModel
///
/// 機能仕様書：4.7.1.1 / 画面設計書：5.10.2
class GroupCreateViewModel extends Notifier<GroupCreateState> {
  @override
  GroupCreateState build() => const GroupCreateState();

  void updateName(String name) => state = state.copyWith(name: name);

  void selectImage(File image) => state = state.copyWith(image: image);

  void selectJoinPolicy(GroupJoinPolicy joinPolicy) => state = state.copyWith(joinPolicy: joinPolicy);

  /// グループを作成し、チャットルームIDを返す
  /// 画像のアップロードに失敗しても、画像なしで作成を完了する（機能仕様書4.7.1.1）。作成に失敗したら[GroupException]を投げる
  /// [kind]はGRP-06で選んだグループの種類（機能仕様書4.7.8.1）
  Future<String> create({
    required String accountId,
    required List<String> friendAccountIds,
    GroupKind kind = GroupKind.standard,
  }) async {
    final repository = ref.read(groupRepositoryProvider);
    final chatRoomId = await repository.createGroup(
      accountId: accountId,
      kind: kind,
      name: state.trimmedName,
      joinPolicy: state.joinPolicy,
      friendAccountIds: friendAccountIds,
    );
    final image = state.image;
    if (image != null) {
      try {
        await repository.setInitialPhoto(accountId: accountId, chatRoomId: chatRoomId, file: image);
      } catch (error) {
        debugPrint('[Group] initial photo failed: $error');
      }
    }
    return chatRoomId;
  }
}

// ============================================================
// Provider
// ============================================================

/// [GroupCreateViewModel]のProvider
final groupCreateViewModelProvider = NotifierProvider.autoDispose<GroupCreateViewModel, GroupCreateState>(
  GroupCreateViewModel.new,
);
