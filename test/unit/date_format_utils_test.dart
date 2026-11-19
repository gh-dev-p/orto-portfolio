import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:multi_id_msg/utils/date_format_utils.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ja');
    await initializeDateFormatting('en');
  });

  // 2026-09-25（金）12:00を「現在」とする。
  final now = DateTime(2026, 9, 25, 12);

  String format(DateTime dateTime, String localeName, String yesterdayLabel) =>
      formatChatTimestamp(dateTime, localeName: localeName, yesterdayLabel: yesterdayLabel, now: now);

  test('今日は時刻を表示する（日本語は24時間表記、英語は英語の書式）', () {
    expect(format(DateTime(2026, 9, 25, 9, 5), 'ja', '昨日'), '09:05');
    expect(format(DateTime(2026, 9, 25, 15, 5), 'ja', '昨日'), '15:05');
    expect(format(DateTime(2026, 9, 25, 15, 5), 'en', 'Yesterday'), matches(RegExp(r'^3:05\sPM$')));
  });

  test('昨日は言語ごとの文言を表示する', () {
    expect(format(DateTime(2026, 9, 24, 9), 'ja', '昨日'), '昨日');
    expect(format(DateTime(2026, 9, 24, 9), 'en', 'Yesterday'), 'Yesterday');
  });

  test('7日以内は言語ごとの曜日を表示する', () {
    // 2026-09-22は火曜日
    expect(format(DateTime(2026, 9, 22, 9), 'ja', '昨日'), '火');
    expect(format(DateTime(2026, 9, 22, 9), 'en', 'Yesterday'), 'Tue');
  });

  test('それより前は月日を表示する（日本語はMM/dd、英語は英語の書式）', () {
    expect(format(DateTime(2026, 9, 1, 9), 'ja', '昨日'), '09/01');
    expect(format(DateTime(2026, 9, 1, 9), 'en', 'Yesterday'), 'Sep 1');
  });

  test('メッセージの時刻は、日本語は24時間表記、英語は英語の書式で表示する', () {
    expect(formatMessageTime(DateTime(2026, 9, 25, 15, 5), 'ja'), '15:05');
    expect(formatMessageTime(DateTime(2026, 9, 25, 15, 5), 'en'), matches(RegExp(r'^3:05\sPM$')));
    expect(formatMessageTime(null, 'en'), '');
  });
}
