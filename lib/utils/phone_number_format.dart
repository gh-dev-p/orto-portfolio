/// 設定画面（SET-01）に表示する電話番号の形式。
///
/// 日本の番号（`+81`）は国内形式にし、先頭と末尾4桁以外を伏せる（例：`+819012345678` → `090-****-5678`）。
/// それ以外の国の番号はE.164のまま、国番号付きの先頭3文字と末尾4桁以外を伏せる。
/// 伏せるのは、画面を人に見られたときに番号全体が分からないようにするため。
String formatMaskedPhoneNumber(String e164) {
  if (e164.startsWith('+81')) {
    final national = '0${e164.substring(3)}';
    if (national.length == 11) {
      return '${national.substring(0, 3)}-****-${national.substring(7)}';
    }
    return _maskMiddle(national, head: 2);
  }
  return _maskMiddle(e164, head: 3);
}

String _maskMiddle(String value, {required int head}) {
  if (value.length <= head + 4) return value;
  return '${value.substring(0, head)}${'*' * (value.length - head - 4)}${value.substring(value.length - 4)}';
}
