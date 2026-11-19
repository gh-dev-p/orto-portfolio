import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multi_id_msg/ui/core/view_models/locale_provider.dart';

void main() {
  test('端末の言語が日本語なら日本語にする', () {
    expect(initialLocaleFor(const [Locale('ja', 'JP')]), const Locale('ja'));
  });

  test('端末の言語が英語なら英語にする', () {
    expect(initialLocaleFor(const [Locale('en', 'US')]), const Locale('en'));
    expect(initialLocaleFor(const [Locale('en', 'GB')]), const Locale('en'));
  });

  test('端末の言語の優先順で、最初に対応している言語にする', () {
    expect(initialLocaleFor(const [Locale('fr'), Locale('ja'), Locale('en')]), const Locale('ja'));
    expect(initialLocaleFor(const [Locale('ko'), Locale('en'), Locale('ja')]), const Locale('en'));
  });

  test('対応していない言語だけの場合は英語にする', () {
    expect(initialLocaleFor(const [Locale('fr'), Locale('de')]), const Locale('en'));
    expect(initialLocaleFor(const []), const Locale('en'));
  });
}
