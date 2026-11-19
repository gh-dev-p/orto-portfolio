/// メッセージの長押しメニューの操作の種類
/// リアクション・コピー・部分コピー・送信取消・削除・通報・お知らせにする（オフ会グループの主催チームのみ）
enum MessageActionType { react, copy, partialCopy, unsend, delete, report, announce }

/// メッセージの長押しメニューで選ばれた操作
/// リアクションなら、選んだ絵文字も持つ
class MessageAction {
  const MessageAction.react(this.emoji) : type = MessageActionType.react;
  const MessageAction.copy() : type = MessageActionType.copy, emoji = null;
  const MessageAction.partialCopy() : type = MessageActionType.partialCopy, emoji = null;
  const MessageAction.unsend() : type = MessageActionType.unsend, emoji = null;
  const MessageAction.delete() : type = MessageActionType.delete, emoji = null;
  const MessageAction.report() : type = MessageActionType.report, emoji = null;
  const MessageAction.announce() : type = MessageActionType.announce, emoji = null;

  final MessageActionType type;
  final String? emoji;
}
