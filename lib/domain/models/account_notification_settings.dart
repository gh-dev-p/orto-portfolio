import 'package:flutter/foundation.dart';

// ============================================================
// ドメインモデル
// ============================================================

/// アカウントごとの通知設定（データ設計書3.1.1）
/// `users/{uid}/ownedAccounts/{accountId}`に持つ。フィールドが無いとき（設定したことがない）はオンとして扱う
///
/// Cloud Functions（firebase/functions/index.js）が通知を送る前にこの値を見て、オフなら送らない
class AccountNotificationSettings {
  const AccountNotificationSettings({required this.messages, required this.reactions, this.mutedGroupIds = const []});

  /// 初期値（どちらもオン）
  static const defaults = AccountNotificationSettings(messages: true, reactions: true);

  /// このアカウント宛ての通知を受け取るか（`notificationsEnabled`）
  /// オフなら、メッセージ・リアクションのどちらの通知も送らない
  final bool messages;

  /// 自分のメッセージへのリアクションの通知を受け取るか（`reactionNotificationsEnabled`）
  /// [messages]がオフのときは、この値に関係なく送らない
  final bool reactions;

  /// 通知をオフにしたグループのチャットルームID（機能仕様書4.7.3.5）
  final List<String> mutedGroupIds;

  /// Firestoreのフィールド名
  static const messagesField = 'notificationsEnabled';
  static const reactionsField = 'reactionNotificationsEnabled';
  static const mutedGroupIdsField = 'mutedGroupIds';

  /// `ownedAccounts`ドキュメントのデータから作る
  /// ドキュメントが無い・フィールドが無いときはオン
  factory AccountNotificationSettings.fromData(Map<String, dynamic>? data) =>
      AccountNotificationSettings(
        messages: data?[messagesField] != false,
        reactions: data?[reactionsField] != false,
        mutedGroupIds: List<String>.from(data?[mutedGroupIdsField] as List? ?? const []),
      );

  @override
  bool operator ==(Object other) =>
      other is AccountNotificationSettings &&
      other.messages == messages &&
      other.reactions == reactions &&
      listEquals(other.mutedGroupIds, mutedGroupIds);

  @override
  int get hashCode => Object.hash(messages, reactions, Object.hashAll(mutedGroupIds));
}
