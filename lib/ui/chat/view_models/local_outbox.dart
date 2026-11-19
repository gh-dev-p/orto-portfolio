import '../../../domain/models/message.dart';
import '../../../domain/models/message_history.dart';

// ============================================================
// 状態クラス
// ============================================================

/// CHA-02（トーク）の、端末上だけにあるメッセージ（Firestoreにはまだ無い・書き込めなかったもの）
/// CHA-02の`ChatViewModel`が持つ（変更後の表示の更新は、ViewModelが行う）
///
/// - 送信失敗：送信自体に失敗したテキスト・画像（画面設計書5.3.2 異常系「送信失敗状態（再送アイコン）」）。タップで再送する（機能仕様書4.4.3.2・4.4.4.2）
/// - アップロード中：送信前から画像の吹き出しを出し、アップロードの進み具合を重ねて表示する（画面設計書5.3.2.4）。メッセージIDはFirestore側と同じため、メッセージができたらFirestore側の表示に入れ替わる
class LocalOutbox {
  // ---- 状態 ----

  /// 送信失敗のメッセージ
  final _failed = <Message>[];

  /// アップロード中の画像のメッセージ
  final _uploading = <Message>[];

  /// 送信失敗のメッセージに付ける、次の連番
  int _failedSeq = 0;

  // ---- 送信失敗 ----

  /// テキストの送信に失敗したメッセージを加える
  void addFailedText({required String senderId, required String text}) {
    _failed.add(
      Message(
        id: _nextFailedId(),
        senderId: senderId,
        text: text.trim(),
        createdAt: DateTime.now(),
        readBy: const [],
        isFailed: true,
      ),
    );
  }

  /// 画像のアップロード・送信に失敗したメッセージを加える
  /// [localImagePath]のファイルから再送する
  void addFailedImage({required String senderId, required String localImagePath, int? width, int? height}) {
    _failed.add(
      Message(
        id: _nextFailedId(),
        senderId: senderId,
        text: '',
        type: MessageType.image,
        imageWidth: width,
        imageHeight: height,
        createdAt: DateTime.now(),
        readBy: const [],
        isFailed: true,
        localImagePath: localImagePath,
      ),
    );
  }

  /// 送信失敗のメッセージを外す
  /// 再送するときに呼ぶ
  void removeFailed(String id) => _failed.removeWhere((m) => m.id == id);

  // ---- アップロード ----

  /// アップロード中の画像のメッセージを加える
  /// [messageId]は、Firestoreに作るメッセージと同じID
  /// 大きさは読み取りに時間がかかるため、後から[updateSize]で入れる
  void startUpload({required String messageId, required String senderId, required String localImagePath}) {
    _uploading.add(
      Message(
        id: messageId,
        senderId: senderId,
        text: '',
        type: MessageType.image,
        createdAt: DateTime.now(),
        readBy: const [],
        isPending: true,
        localImagePath: localImagePath,
      ),
    );
  }

  /// アップロード中の画像の大きさ（px）を入れる
  /// アップロード中でなければ何もせずfalse（表示の更新は不要）
  bool updateSize(String messageId, {required int width, required int height}) {
    final index = _uploading.indexWhere((m) => m.id == messageId);
    if (index < 0) return false;
    _uploading[index] = _uploading[index].copyWith(imageWidth: width, imageHeight: height);
    return true;
  }

  /// アップロードの進み具合（0〜1）を更新する
  /// アップロード中でなければ何もせずfalse（表示の更新は不要）
  bool updateProgress(String messageId, double progress) {
    final index = _uploading.indexWhere((m) => m.id == messageId);
    if (index < 0) return false;
    _uploading[index] = _uploading[index].copyWith(uploadProgress: progress);
    return true;
  }

  /// アップロード中の画像のメッセージを外す
  /// アップロード（とメッセージの作成）が終わった・失敗したときに呼ぶ
  void finishUpload(String messageId) => _uploading.removeWhere((m) => m.id == messageId);

  // ---- 表示 ----

  /// 表示するメッセージ
  /// 「削除」（自分の画面のみ非表示）済み・送信取消済みのメッセージは除き、端末上だけにあるメッセージを送った順に後ろへ並べる（アップロード中の画像は、Firestore側に同じIDのメッセージができた時点でそちらを表示する）
  List<Message> visibleMessages(MessageHistory history, {required String myAccountId}) {
    final ids = {for (final m in history.messages) m.id};
    final local = [..._failed, ..._uploading.where((m) => !ids.contains(m.id))]
      ..sort((a, b) => a.createdAt!.compareTo(b.createdAt!));
    return [...history.messages.where((m) => !m.isHiddenFor(myAccountId) && !m.isUnsent), ...local];
  }

  /// 送信失敗のメッセージに付ける、端末内だけのID
  String _nextFailedId() => 'local-failed-${_failedSeq++}';
}
