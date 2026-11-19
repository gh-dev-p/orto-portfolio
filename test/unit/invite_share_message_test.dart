import 'package:flutter_test/flutter_test.dart';
import 'package:multi_id_msg/l10n/app_localizations.dart';
import 'package:multi_id_msg/l10n/app_localizations_en.dart';
import 'package:multi_id_msg/l10n/app_localizations_ja.dart';
import 'package:multi_id_msg/ui/friend/widgets/invite_share.dart';

// 招待の共有文（機能仕様書4.3.5.1・4.7.2.3）
void main() {
  const link = 'https://orto.example.com/group/token';
  final locales = <String, AppLocalizations>{'ja': AppLocalizationsJa(), 'en': AppLocalizationsEn()};

  for (final MapEntry(key: locale, value: l10n) in locales.entries) {
    group(locale, () {
      test('グループの共有文に、グループ名とリンクが入る', () {
        final text = l10n.grpInviteShareMessage('ボドゲ会', link);
        expect(text, contains('ボドゲ会'));
        expect(text, endsWith(link));
      });

      test('QRコードの共有文に、グループ名が入り、リンクは入らない', () {
        final text = l10n.grpInviteQrShareMessage('ボドゲ会');
        expect(text, contains('ボドゲ会'));
        expect(text, isNot(contains('https://')));
      });

      test('友だちの招待文に、リンクとアカウントIDが入る', () {
        final text = l10n.friInviteMessage('alice', 'https://orto.example.com/invite/alice');
        expect(text, contains('https://orto.example.com/invite/alice'));
        expect(text, contains(locale == 'ja' ? 'ID「alice」' : 'ID "alice"'));
      });

      test('「IDで検索されない」アカウントの招待文には、IDで検索する案内を付けない', () {
        const link = 'https://orto.example.com/invite/alice?k=key';
        final searchable = friendInviteMessage(l10n, accountId: 'alice', link: link, allowIdSearch: true);
        final hidden = friendInviteMessage(l10n, accountId: 'alice', link: link, allowIdSearch: false);
        expect(searchable, contains(locale == 'ja' ? 'ID「alice」' : 'ID "alice"'));
        expect(hidden, endsWith(link));
        expect(hidden, isNot(contains(locale == 'ja' ? '検索' : 'search')));
      });
    });
  }
}
