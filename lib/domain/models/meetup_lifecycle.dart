/// オフ会グループの期限（機能仕様書4.7.8.6〜4.7.8.8、データ設計書8.17）
/// 閉じたかは期限の時刻で決める（サーバーのfirestore.rules・Cloud Functionsと同じ判定）
library;

/// 閉じる日の初期値（会の3日後）
const meetupDefaultCloseAfterDays = 3;

/// 延ばせる上限（会の日から2週間）
const meetupMaxCloseAfterDays = 14;

/// 会の前に選べる閉じる日（翌日・3日後・1週間後）
const meetupCloseDayChoices = [1, 3, 7];

/// 閉じたあと記録を残す期間
const meetupRetention = Duration(days: 30);

/// 新しい期限は今からこの時間より後であること（サーバーの`invalid-close-days`と同じ）
const meetupMinCloseLead = Duration(hours: 1);

/// 閉じているか。[closedAt]（閉じる処理の印）があるか、[closesAt]を過ぎたら閉じている。期限が無ければ閉じない
bool isMeetupClosed({DateTime? closesAt, DateTime? closedAt, required DateTime now}) {
  if (closedAt != null) return true;
  return closesAt != null && !now.isBefore(closesAt);
}

/// 閉じるまでの残り日数（日に切り上げる。24時間を切ったら1）。期限が無い・閉じたあとはnull
int? meetupDaysLeft({DateTime? closesAt, DateTime? closedAt, required DateTime now}) {
  if (closesAt == null || isMeetupClosed(closesAt: closesAt, closedAt: closedAt, now: now)) return null;
  final left = closesAt.difference(now);
  const day = Duration(days: 1);
  return (left.inMicroseconds + day.inMicroseconds - 1) ~/ day.inMicroseconds;
}

/// 記録が消える日時（期限の30日後）
DateTime meetupPurgeAt(DateTime closesAt) => closesAt.add(meetupRetention);

/// 会の日時[eventAt]の[days]日後（閉じる日時）
DateTime meetupClosesAt(DateTime eventAt, int days) => eventAt.add(Duration(days: days));

/// GRP-08の「グループを閉じる日」で選べる日数（機能仕様書4.7.8.6）
/// 会の前は「翌日・3日後・1週間後」（今の値がほかなら、それも）。会の日時を過ぎたら1〜14日のうち、
/// 閉じる日時が今から1時間より後になるもの（延長）。今の値は、選べなくなっていても表示のために入れる
List<int> meetupCloseDayOptions({required DateTime eventAt, required int current, required DateTime now}) {
  final started = !now.isBefore(eventAt);
  final candidates = started
      ? [for (var days = 1; days <= meetupMaxCloseAfterDays; days++) days]
      : {...meetupCloseDayChoices, current}.toList();
  final limit = now.add(meetupMinCloseLead);
  final options = candidates.where((days) => meetupClosesAt(eventAt, days).isAfter(limit)).toSet()..add(current);
  return options.toList()..sort();
}
