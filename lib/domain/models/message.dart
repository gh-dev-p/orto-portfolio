import 'package:cloud_firestore/cloud_firestore.dart';

import 'album.dart';
import 'firestore_values.dart';

export 'album.dart' show AlbumEvent;

/// `chatRooms/{chatRoomId}/messages/{messageId}` ドキュメント。
/// データ設計書 3.3.1 参照。既読管理はメッセージ単位（`readBy`配列）。
class Message {
  const Message({
    required this.id,
    required this.senderId,
    required this.text,
    this.type = MessageType.text,
    this.imagePath,
    this.imageWidth,
    this.imageHeight,
    this.stickerPackId,
    this.stickerId,
    this.albumId,
    this.albumEvent,
    this.albumItemCount,
    this.albumName,
    this.meetupStatus,
    this.systemType,
    this.targetAccountIds = const [],
    this.groupName,
    this.hoursLeft,
    required this.createdAt,
    required this.readBy,
    this.reactions = const {},
    this.hiddenFor = const [],
    this.unsentAt,
    this.isPending = false,
    this.isFailed = false,
    this.localImagePath,
    this.uploadProgress,
  });

  final String id;
  final String senderId;

  /// 本文。画像メッセージ・送信取消後は空。
  final String text;

  final MessageType type;

  /// 画像メッセージのStorage上のパス（`chatRooms/{chatRoomId}/images/{messageId}.jpg`）。表示時に
  /// ダウンロードURLを取得する（URLはFirestoreに保存しない。データ設計書3.3.1）。
  final String? imagePath;
  final int? imageWidth;
  final int? imageHeight;

  /// スタンプメッセージのパックのID（機能仕様書4.4.8）。
  final String? stickerPackId;

  /// スタンプメッセージの、パックの中のスタンプのID。
  final String? stickerId;

  /// アルバムの案内の対象のアルバム（機能仕様書4.4.9）。
  final String? albumId;

  /// アルバムの案内の種類（作成・追加）。
  final AlbumEvent? albumEvent;

  /// アルバムの案内の、追加した件数。
  final int? albumItemCount;

  /// アルバムの案内を送った時点のアルバムの名前。
  final String? albumName;

  /// 当日の定型連絡（オフ会グループのみ）の中身（機能仕様書4.7.8.11）。
  final MeetupStatus? meetupStatus;

  /// システムメッセージ（グループのみ）の種類（データ設計書8.2）。
  final String? systemType;

  /// システムメッセージの対象のアカウントID（参加した人・退会した人など）。
  final List<String> targetAccountIds;

  /// システムメッセージに載せるグループ名（作成時・名前の変更時）。
  final String? groupName;

  /// 閉じる前の知らせ（`closing_soon`、データ設計書8.17）の残り時間（24か1）。
  final int? hoursLeft;

  final DateTime? createdAt;
  final List<String> readBy;

  /// リアクション。accountIdをキー、絵文字文字列を値とするmap（1人1メッセージにつき1つまで）。
  final Map<String, String> reactions;

  /// 「削除」（自分の画面のみ非表示）したaccountIdの一覧。
  final List<String> hiddenFor;

  /// 送信取消した日時。取消済みのメッセージは双方の画面に表示しない。本文はCloud Functions
  /// が管理者専用の場所へ移してメッセージから削除するため、取消後は[text]が空になる。
  final DateTime? unsentAt;

  /// Firestoreへの書き込みがまだサーバー確定していない（楽観的UI表示中）かどうか。
  final bool isPending;

  /// 送信自体が失敗し、Firestoreに書き込めなかったローカルのみのメッセージかどうか
  /// （画面設計書5.3.2異常系「送信失敗状態（再送アイコン）」）。trueの場合、このMessageは
  /// Firestoreには存在せず、[ChatScreen]がローカルで保持しているだけの一時的な表示用データ。
  final bool isFailed;

  /// 送信に失敗した画像メッセージ（[isFailed]）の、端末上の画像ファイルのパス。失敗した画像をトークに
  /// 表示し、再送でこのファイルのアップロードからやり直す（機能仕様書4.4.4.2）。
  final String? localImagePath;

  /// アップロード中の画像メッセージ（[ChatScreen]がローカルで保持する、[isPending]かつ[localImagePath]を
  /// 持つ一時的な表示用データ）の進み具合（0〜1）。進み具合がまだ分からない間はnull（画面設計書5.3.2）。
  final double? uploadProgress;

  /// 端末上だけにある表示用の状態（画像の大きさ・アップロードの進み具合）を変えたコピー。
  Message copyWith({int? imageWidth, int? imageHeight, double? uploadProgress}) => Message(
    id: id,
    senderId: senderId,
    text: text,
    type: type,
    imagePath: imagePath,
    imageWidth: imageWidth ?? this.imageWidth,
    imageHeight: imageHeight ?? this.imageHeight,
    stickerPackId: stickerPackId,
    stickerId: stickerId,
    albumId: albumId,
    albumEvent: albumEvent,
    albumItemCount: albumItemCount,
    albumName: albumName,
    meetupStatus: meetupStatus,
    systemType: systemType,
    targetAccountIds: targetAccountIds,
    groupName: groupName,
    hoursLeft: hoursLeft,
    createdAt: createdAt,
    readBy: readBy,
    reactions: reactions,
    hiddenFor: hiddenFor,
    unsentAt: unsentAt,
    isPending: isPending,
    isFailed: isFailed,
    localImagePath: localImagePath,
    uploadProgress: uploadProgress ?? this.uploadProgress,
  );

  /// アップロード中で、まだFirestoreに書き込んでいない画像メッセージか。
  bool get isUploadingImage => isImage && isPending && localImagePath != null;

  bool isMine(String myAccountId) => senderId == myAccountId;
  bool isReadBy(String accountId) => readBy.contains(accountId);
  bool isHiddenFor(String accountId) => hiddenFor.contains(accountId);
  bool get isUnsent => unsentAt != null;
  bool get isImage => type == MessageType.image;

  /// このバージョンのアプリが知らない種類のメッセージか（機能仕様書4.4.3）。
  bool get isUnsupported => type == MessageType.unknown;

  bool get isSticker => type == MessageType.sticker;

  /// アルバムの作成・追加の案内か（機能仕様書4.4.9）。
  bool get isAlbum => type == MessageType.album;

  /// 当日の定型連絡か（機能仕様書4.7.8.11）。中身が読めないもの（取消済み・壊れたデータ）は含めない。
  bool get isMeetupStatus => type == MessageType.meetupStatus && meetupStatus != null;

  /// グループの参加・退会などを知らせるシステムメッセージか（Cloud Functionsだけが作る）。
  bool get isSystem => type == MessageType.system;
  String? reactionOf(String accountId) => reactions[accountId];

  factory Message.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return Message(
      id: doc.id,
      senderId: data['senderId'] as String,
      text: stringOrNull(data['text']) ?? '',
      type: MessageType.fromValue(stringOrNull(data['type'])),
      imagePath: stringOrNull(data['imagePath']),
      imageWidth: intOrNull(data['imageWidth']),
      imageHeight: intOrNull(data['imageHeight']),
      stickerPackId: stringOrNull(data['stickerPackId']),
      stickerId: stringOrNull(data['stickerId']),
      albumId: stringOrNull(data['albumId']),
      albumEvent: AlbumEvent.fromValue(stringOrNull(data['albumEvent'])),
      albumItemCount: intOrNull(data['albumItemCount']),
      albumName: stringOrNull(data['albumName']),
      meetupStatus: MeetupStatus.fromValue(stringOrNull(data['meetupStatus'])),
      systemType: stringOrNull(data['systemType']),
      targetAccountIds: stringList(data['targetAccountIds']),
      groupName: stringOrNull(data['groupName']),
      hoursLeft: intOrNull(data['hoursLeft']),
      createdAt: dateOrNull(data['createdAt']),
      readBy: stringList(data['readBy']),
      reactions: stringMap(data['reactions']),
      hiddenFor: stringList(data['hiddenFor']),
      unsentAt: dateOrNull(data['unsentAt']),
      isPending: doc.metadata.hasPendingWrites,
    );
  }
}

/// メッセージの種類。`type`フィールドが無い旧データはテキストとして扱う。
/// 新しいバージョンのアプリが送った、このバージョンの知らない種類は[unknown]になる。
enum MessageType {
  text('text'),
  image('image'),
  sticker('sticker'),
  album('album'),
  meetupStatus('meetupStatus'),
  system('system'),
  unknown('unknown');

  const MessageType(this.value);

  final String value;

  static MessageType fromValue(String? value) {
    if (value == null) return text;
    return values.firstWhere((type) => type.value == value, orElse: () => unknown);
  }
}

/// 当日の定型連絡の中身（機能仕様書4.7.8.11、データ設計書3.3.1）。文言は持たず、表示する側の言語で出す。
enum MeetupStatus {
  late('late'),
  arrived('arrived'),
  notFound('notFound');

  const MeetupStatus(this.value);

  final String value;

  /// 知らない値・無い値はnull
  static MeetupStatus? fromValue(String? value) {
    for (final status in values) {
      if (status.value == value) return status;
    }
    return null;
  }
}
