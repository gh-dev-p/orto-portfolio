import 'package:intl/intl.dart';

/// チャット一覧・チャット画面向けの簡易日時表示（画面設計書5.3.1のワイヤーフレーム準拠）。
/// 今日は時刻（[formatMessageTime]）、昨日は[yesterdayLabel]、7日以内は曜日、それより前は月日
/// （日本語は`09/18`、それ以外は[localeName]の書式。例：`Sep 18`）。[now]はテスト用（省略時は現在時刻）。
String formatChatTimestamp(
  DateTime? dateTime, {
  required String localeName,
  required String yesterdayLabel,
  DateTime? now,
}) {
  if (dateTime == null) return '';
  final current = now ?? DateTime.now();
  final today = DateTime(current.year, current.month, current.day);
  final target = DateTime(dateTime.year, dateTime.month, dateTime.day);
  final diff = today.difference(target).inDays;

  if (diff == 0) return formatMessageTime(dateTime, localeName);
  if (diff == 1) return yesterdayLabel;
  if (diff < 7) return DateFormat('E', localeName).format(dateTime);
  if (localeName == 'ja') return DateFormat('MM/dd').format(dateTime);
  return DateFormat.MMMd(localeName).format(dateTime);
}

/// チャット画面（CHA-02）のメッセージ時刻表示。日付に関わらず時刻だけを表示する。
/// 日本語は24時間表記の`HH:mm`、それ以外は[localeName]の書式（例：`9:05 AM`）。[Message.createdAt]は
/// `Timestamp.toDate()`（`DateTime.fromMicrosecondsSinceEpoch`）由来ですでに端末の
/// ローカルタイムゾーンの日時になっているため、ここでは追加の変換は不要。
String formatMessageTime(DateTime? dateTime, String localeName) {
  if (dateTime == null) return '';
  if (localeName == 'ja') return DateFormat('HH:mm').format(dateTime);
  return DateFormat.jm(localeName).format(dateTime);
}

/// チャット画面（CHA-02）の日付区切りラベル（LINE準拠）。相対表記
/// （「今日」「昨日」）は使わず日付そのものを表示する。日本語は「年月日＋曜日」形式
/// （例：2026年9月18日(金)）、その他ロケールはロケールに応じた日付表記
/// （例：Sep 18, 2026）。
String formatDateDividerLabel(DateTime date, String localeName) {
  if (localeName == 'ja') {
    final weekday = DateFormat('E', 'ja').format(date);
    return '${date.year}年${date.month}月${date.day}日($weekday)';
  }
  return DateFormat.yMMMd(localeName).format(date);
}

/// [a]と[b]がローカルタイムゾーンで同じ日付かどうか（の日付区切り判定基準：
/// UTCのままではなくローカル日付を基準に判定する）。
bool isSameLocalDate(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

/// オフ会グループの会の日時（機能仕様書4.7.8.4）。CHA-02のお知らせの枠・GRP-08に出す
/// 日本語は「11月22日(土) 19:00」、今年でなければ年を付ける（「2027年1月5日(火) 19:00」）。
/// それ以外は[localeName]の書式（例：`Sat, Nov 22, 7:00 PM`）。[now]はテスト用
String formatEventDateTime(DateTime dateTime, String localeName, {DateTime? now}) {
  final thisYear = (now ?? DateTime.now()).year == dateTime.year;
  if (localeName == 'ja') {
    final weekday = DateFormat('E', 'ja').format(dateTime);
    final year = thisYear ? '' : '${dateTime.year}年';
    return '$year${dateTime.month}月${dateTime.day}日($weekday) ${DateFormat('HH:mm').format(dateTime)}';
  }
  final date = thisYear ? DateFormat.MMMEd(localeName) : DateFormat.yMMMEd(localeName);
  return '${date.format(dateTime)}, ${DateFormat.jm(localeName).format(dateTime)}';
}
