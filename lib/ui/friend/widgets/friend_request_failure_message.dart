import '../../../domain/models/friend_request.dart';
import '../../../l10n/app_localizations.dart';

/// 友だち申請の失敗[failure]を、画面に出す文言にする（機能仕様書4.3.8の異常系）
/// 理由を特定できないときは[fallback]を返す
String friendRequestFailureMessage(AppLocalizations l10n, FriendRequestFailure failure, {required String fallback}) {
  return switch (failure) {
    FriendRequestFailure.readOnly => l10n.planReadOnlyNotice,
    FriendRequestFailure.notMember => l10n.frqNotMember,
    FriendRequestFailure.groupClosed => l10n.grpErrorGroupClosed,
    FriendRequestFailure.requestNotFound || FriendRequestFailure.requestInvalid => l10n.frqInvalid,
    FriendRequestFailure.accountNotFound ||
    FriendRequestFailure.alreadyFriend ||
    FriendRequestFailure.unknown => fallback,
  };
}
