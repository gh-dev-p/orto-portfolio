import 'package:cloud_firestore/cloud_firestore.dart';

/// お知らせの件数の上限（機能仕様書4.7.8.4）
const announcementMaxCount = 20;

/// お知らせの本文の最大文字数
const announcementMaxTextLength = 1000;

/// お知らせ・会の場所の最大文字数
const announcementMaxPlaceLength = 100;

/// `chatRooms/{chatRoomId}/announcements/{announcementId}` ドキュメント（データ設計書8.15）
/// オフ会グループのお知らせ。参加者は読める。書くのはCloud Functionsのみ
class Announcement {
  const Announcement({
    required this.announcementId,
    required this.text,
    this.place,
    required this.createdBy,
    this.createdAt,
    this.updatedAt,
  });

  final String announcementId;

  /// 本文
  final String text;

  /// 場所（店名か住所。押すと地図アプリで検索する）。無ければnull
  final String? place;

  /// 出したアカウントID
  final String createdBy;

  /// 出した日時（並び順に使う。サーバーで確定する前はnull）
  final DateTime? createdAt;

  /// 最後に直した日時
  final DateTime? updatedAt;

  factory Announcement.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    final place = data['place'];
    return Announcement(
      announcementId: doc.id,
      text: data['text'] as String? ?? '',
      place: place is String && place.isNotEmpty ? place : null,
      createdBy: data['createdBy'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }
}

/// 地図アプリで場所[place]を検索するURL（機能仕様書4.7.8.4）。地図はアプリの中に持たない
/// どちらもアプリが入っていればアプリで、無ければブラウザで開く
abstract final class MapSearchLinks {
  /// Apple マップ（iOS）
  static Uri apple(String place) => Uri.https('maps.apple.com', '/', {'q': place});

  /// Google マップ
  static Uri google(String place) => Uri.https('www.google.com', '/maps/search/', {'api': '1', 'query': place});

  /// Androidの端末の地図アプリ（`geo:`を受け取るアプリ）
  static Uri geo(String place) => Uri.parse('geo:0,0?q=${Uri.encodeQueryComponent(place)}');
}
