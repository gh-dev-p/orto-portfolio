import '../utils/validators.dart';
import 'app_flavor.dart';

/// 招待リンク（FRI-03）：`https://{ホスト}/invite/{accountId}?k={招待キー}`
/// 招待キー（データ設計書3.14）は、IDによる友だち追加を許可していないアカウントにも、招待を受け取った人が追加できるようにするもの
/// グループの招待リンク（GRP-04、機能仕様書4.7.2.3）：`https://{ホスト}/group/{招待トークン}`
/// QRコード（マイQRコード・GRP-04）にも同じ招待リンクを入れる
///
/// 環境ごとの2つのドメインのどちらでも、タップするとアプリが開く（iOSのAssociated Domains・AndroidのApp Linksに両方を登録している）
/// 招待文・QRコードには1つ目を載せる。2つ目は、カスタムURLスキームに切り替えるまでの間、案内ページの「アプリをお持ちの方はこちら」ボタンに使う
/// （iOSは、表示中のページと同じドメインへのリンクではアプリを開かない。2つのドメインも同じドメインとして扱われ、Safariでは効かない）
///
/// カスタムURLスキーム：`{スキーム}://invite/{accountId}`・`{スキーム}://group/{招待トークン}`
/// 案内ページのボタンから確実にアプリを開くためのもの。Universal Linksと違い、Safari・アプリ内ブラウザのどちらからでもアプリが開く
/// 以前のQRコードの`orto://friend/{accountId}`も、標準のカメラで読んだときにアプリが開くよう、同じく受け付ける
/// 本番の案内ページは運営者のWebサイト、開発環境はFirebase Hosting
///
/// ホストはiOSの`ios/Flutter/*.xcconfig`（`INVITE_LINK_HOST`）・Androidの`android/app/build.gradle.kts`（`inviteLinkHost`）と揃える
/// スキームも同じく`APP_URL_SCHEME`・`appUrlScheme`と揃える
abstract final class InviteLinks {
  /// 環境ごとのドメイン（招待文に載せるもの、案内ページのボタン用のもの）
  static const _hosts = {
    AppFlavor.dev: ['orto-dev.example.com', 'open-dev.example.com'],
    AppFlavor.prod: ['orto.example.com', 'open.example.com'],
  };

  /// 招待キーの形式（32バイトの乱数のBase64URL。Cloud Functionsの`KEY_PATTERN`と同じ）
  static final _inviteKeyFormat = RegExp(r'^[A-Za-z0-9_-]{43}$');

  /// 招待リンクの中で招待キーを入れるクエリの名前
  static const _inviteKeyParam = 'k';

  /// 環境ごとのカスタムURLスキーム。開発版と本番版を両方入れた端末で取り合わないよう分ける
  static const _schemes = {AppFlavor.dev: 'orto-dev', AppFlavor.prod: 'orto'};

  /// [flavor]の環境のカスタムURLスキーム
  static String scheme(AppFlavor flavor) => _schemes[flavor]!;

  /// 招待したアカウントの、カスタムURLスキームの招待リンク（案内ページのボタン用。アプリでは組み立てない）
  static String appSchemeForAccount(String accountId, AppFlavor flavor) => '${scheme(flavor)}://invite/$accountId';

  /// グループの、カスタムURLスキームの招待リンク（案内ページのボタン用。アプリでは組み立てない）
  static String appSchemeForGroup(String token, AppFlavor flavor) => '${scheme(flavor)}://group/$token';

  /// [accountId]への招待リンク
  /// [inviteKey]があれば付ける
  static String forAccount(String accountId, AppFlavor flavor, {String? inviteKey}) {
    final link = 'https://${_hosts[flavor]!.first}/invite/$accountId';
    return inviteKey == null ? link : '$link?$_inviteKeyParam=$inviteKey';
  }

  /// 以前のQRコードの接頭辞（データ設計書8.11・4.1）。アプリのスキャナーの中だけで照合していた
  /// iPhoneの標準のカメラで開けないため、今はQRコードにも招待リンク（https）を入れる。
  /// 配った・保存した古いQRコードを読めるよう、読み取りだけは受け付ける
  static const _legacyGroupQrPrefix = 'orto://group/';
  static const _legacyFriendQrPrefix = 'orto://friend/';

  /// 招待トークンの形式（32バイトの乱数のBase64URL。Cloud Functionsの`TOKEN_PATTERN`と同じ）
  static final _groupTokenFormat = RegExp(r'^[A-Za-z0-9_-]{43}$');

  /// グループの招待リンク
  static String forGroup(String token, AppFlavor flavor) => 'https://${_hosts[flavor]!.first}/group/$token';

  /// グループの招待のQRコード（GRP-04）の内容。招待リンクと同じ
  /// 標準のカメラで読むとUniversal Linksでアプリ（入っていなければ案内ページ）が開く
  static String groupQrData(String token, AppFlavor flavor) => forGroup(token, flavor);

  /// マイQRコード（QRC-01）の内容。友だちの招待リンクと同じ
  static String friendQrData(String accountId, AppFlavor flavor, {String? inviteKey}) =>
      forAccount(accountId, flavor, inviteKey: inviteKey);

  /// アプリのスキャナー（QRC-01）で読み取った[rawValue]を、招待として読む
  /// 招待リンク（[flavor]の環境の2つのドメインのどちらでも、カスタムURLスキームでも）と、以前の`orto://`のQRコードの両方を受け付ける
  /// グループ・友だちのどちらの形でもなければnull。形は合うが中身（トークン・ID）の形式が合わなければ、中身をnullにして返す
  static QrInvite? qrInviteFrom(String rawValue, AppFlavor flavor) {
    final value = rawValue.trim();
    if (value.startsWith(_legacyGroupQrPrefix)) {
      final token = value.substring(_legacyGroupQrPrefix.length);
      return GroupQrInvite(_groupTokenFormat.hasMatch(token) ? token : null);
    }
    if (value.startsWith(_legacyFriendQrPrefix)) {
      final accountId = value.substring(_legacyFriendQrPrefix.length);
      return FriendQrInvite(isValidAccountIdFormat(accountId) ? accountId : null);
    }
    final uri = Uri.tryParse(value);
    if (uri == null) return null;
    return switch (_parse(uri, flavor)) {
      (kind: _InviteKind.group, value: final token) => GroupQrInvite(_groupTokenFormat.hasMatch(token) ? token : null),
      (kind: _InviteKind.account, value: final accountId) => FriendQrInvite(
        isValidAccountIdFormat(accountId) ? accountId : null,
        inviteKey: inviteKeyFrom(uri),
      ),
      null => null,
    };
  }

  /// 招待リンク[uri]から、グループの招待トークンを取り出す
  /// [flavor]の環境のグループの招待リンク（https・カスタムURLスキーム）でない・形式に合わない場合はnull
  static String? groupTokenFrom(Uri uri, AppFlavor flavor) {
    final parsed = _parse(uri, flavor);
    if (parsed == null || parsed.kind != _InviteKind.group) return null;
    return _groupTokenFormat.hasMatch(parsed.value) ? parsed.value : null;
  }

  /// 招待リンク[uri]から、招待したアカウントIDを取り出す
  /// [flavor]の環境の招待リンク（https・カスタムURLスキーム）でない・IDの形式に合わない場合はnull
  static String? accountIdFrom(Uri uri, AppFlavor flavor) {
    final parsed = _parse(uri, flavor);
    if (parsed == null || parsed.kind != _InviteKind.account) return null;
    return isValidAccountIdFormat(parsed.value) ? parsed.value : null;
  }

  /// 友だちの招待リンク[uri]から、招待キーを取り出す
  /// 付いていない・形式に合わない場合はnull（環境とパスは[accountIdFrom]で確かめる）
  static String? inviteKeyFrom(Uri uri) {
    final key = uri.queryParameters[_inviteKeyParam];
    return key != null && _inviteKeyFormat.hasMatch(key) ? key : null;
  }

  /// 招待リンク[uri]を、招待の種類と中身（トークン・ID。形式は確かめない。パスの数が合わなければ空）に分ける
  /// - https：[flavor]の環境の2つのドメインのどちらかで、パスが`/invite/{ID}`・`/group/{トークン}`
  /// - カスタムURLスキーム：[flavor]の環境のスキームで、`invite`・`friend`（以前のQRコード）・`group`がホスト、パスが中身だけ
  /// どちらでもなければnull
  static ({_InviteKind kind, String value})? _parse(Uri uri, AppFlavor flavor) {
    final segments = uri.pathSegments.where((segment) => segment.isNotEmpty).toList();
    final String kindName;
    final String value;
    // パスの数が合わないときは、中身を空（どの形式にも合わない）にする。
    if (uri.scheme == 'https' && _hosts[flavor]!.contains(uri.host)) {
      if (segments.isEmpty) return null;
      kindName = segments.first;
      value = segments.length == 2 ? segments.last : '';
    } else if (uri.scheme == scheme(flavor)) {
      // 以前のQRコードの`orto://friend/`は、招待リンクの`invite`と同じ扱い
      kindName = uri.host == 'friend' ? 'invite' : uri.host;
      value = segments.length == 1 ? segments.single : '';
    } else {
      return null;
    }
    final kind = switch (kindName) {
      'invite' => _InviteKind.account,
      'group' => _InviteKind.group,
      _ => null,
    };
    return kind == null ? null : (kind: kind, value: value);
  }
}

/// 招待リンクの種類
enum _InviteKind {
  /// 友だちの招待（`invite`）
  account,
  /// グループの招待（`group`）
  group,
}

/// アプリのスキャナーで読み取った招待（[InviteLinks.qrInviteFrom]）
sealed class QrInvite {
  const QrInvite();
}

/// グループの招待のQRコード。[token]は形式が合わなければnull
class GroupQrInvite extends QrInvite {
  const GroupQrInvite(this.token);

  final String? token;
}

/// 友だちのQRコード（マイQRコード）。[accountId]は形式が合わなければnull
class FriendQrInvite extends QrInvite {
  const FriendQrInvite(this.accountId, {this.inviteKey});

  final String? accountId;

  /// 招待キー。無い・形式が合わなければnull
  final String? inviteKey;
}
