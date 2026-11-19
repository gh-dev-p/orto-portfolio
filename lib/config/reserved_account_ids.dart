/// 運営者へのなりすまし防止のため、アカウントIDとして使用できない予約ID。
///
/// 「support」を名乗る偽アカウントからの「SMSコードを送って」等の詐欺を防ぐのが目的で、
/// ブランド名・著名人名は対象外（利用規約のなりすまし禁止＋通報対応で扱う）。
/// 大文字小文字と記号（`.` `-` `_`）の違いで回避されないよう、[normalizeAccountIdForReservedCheck]で
/// 正規化した形で照合する（例：`Sup.port`・`ORTO_official`も該当）。
///
/// firestore.rulesの`isReservedAccountId`にも同じリストがあり、変更時は両方を更新すること
/// （アプリ側のチェックは画面表示用で、登録の拒否はルール側で保証する）。
abstract final class ReservedAccountIds {
  static const Set<String> normalized = {
    // 運営・公式を連想させる汎用語
    'admin',
    'administrator',
    'official',
    'support',
    'help',
    'helpdesk',
    'staff',
    'system',
    'root',
    'security',
    'info',
    'contact',
    'moderator',
    'operator',
    'unei',
    // アプリ名とその派生
    'orto',
    'ortoapp',
    'ortoofficial',
    'officialorto',
    'ortosupport',
    'ortoteam',
    'ortostaff',
    'ortoadmin',
  };
}

String normalizeAccountIdForReservedCheck(String id) => id.toLowerCase().replaceAll(RegExp(r'[._-]'), '');

bool isReservedAccountId(String id) =>
    ReservedAccountIds.normalized.contains(normalizeAccountIdForReservedCheck(id.trim()));
