import 'package:cloud_firestore/cloud_firestore.dart';

/// Firestoreから読んだ値を、型が違っても例外にせず取り出す
/// 他の人が書いた値を解析するときに使う（1件の不正な値で、一覧やトークの全体を止めないため。データ設計書6章）

String? stringOrNull(Object? value) => value is String ? value : null;

/// NaN・Infinityも無いものとして扱う（`toInt`が例外を投げるため）
int? intOrNull(Object? value) => value is num && value.isFinite ? value.toInt() : null;

DateTime? dateOrNull(Object? value) => value is Timestamp ? value.toDate() : null;

List<String> stringList(Object? value) => value is List ? value.whereType<String>().toList() : const [];

Map<String, String> stringMap(Object? value) => value is Map
    ? {
        for (final entry in value.entries)
          if (entry.key is String && entry.value is String) entry.key as String: entry.value as String,
      }
    : const {};

/// [items]を[parse]で変換する。解析できない項目は飛ばす
List<T> parseSkippingBroken<S, T>(Iterable<S> items, T Function(S item) parse) {
  final parsed = <T>[];
  for (final item in items) {
    try {
      parsed.add(parse(item));
    } catch (_) {
      continue;
    }
  }
  return parsed;
}
