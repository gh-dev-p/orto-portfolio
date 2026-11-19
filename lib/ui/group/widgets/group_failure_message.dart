import '../../../domain/models/group.dart';
import '../../../l10n/app_localizations.dart';

/// グループの操作の失敗[failure]を、画面に出す文言にする（機能仕様書4.7の異常系）
/// 理由を特定できないときは[fallback]を返す
String groupFailureMessage(AppLocalizations l10n, GroupFailure failure, {required String fallback}) {
  return switch (failure) {
    GroupFailure.readOnly => l10n.grpErrorReadOnly,
    GroupFailure.groupFull => l10n.grpErrorGroupFull,
    GroupFailure.joinLimit => l10n.grpErrorJoinLimit,
    GroupFailure.createLimit => l10n.grpErrorCreateLimit,
    GroupFailure.membersExceeded => l10n.grpErrorMembersExceeded,
    GroupFailure.groupDeleted => l10n.grpErrorGroupDeleted,
    GroupFailure.inviteInvalid => l10n.grpErrorInviteInvalid,
    GroupFailure.lastOrganizer => l10n.grpErrorLastOrganizer,
    GroupFailure.applicantUnavailable => l10n.grpErrorApplicantUnavailable,
    GroupFailure.invalidAnswers => l10n.grpErrorInvalidAnswers,
    GroupFailure.announcementLimit => l10n.annErrorLimit,
    GroupFailure.announcementNotFound => l10n.annErrorNotFound,
    GroupFailure.invalidEventAt => l10n.annErrorEventPast,
    GroupFailure.invalidDeadline => l10n.attErrorDeadline,
    GroupFailure.reminderTooSoon => l10n.attErrorReminderTooSoon,
    GroupFailure.invalidCapacity => l10n.capErrorRange,
    GroupFailure.invalidCloseDays => l10n.grpErrorInvalidCloseDays,
    GroupFailure.groupClosed => l10n.grpErrorGroupClosed,
    GroupFailure.invalidSettlement => l10n.stlErrorInvalid,
    GroupFailure.settlementNotFound => l10n.stlErrorNotFound,
    GroupFailure.notSettlementTarget => l10n.stlErrorNotTarget,
    GroupFailure.paymentConfirmed => l10n.stlErrorPaymentConfirmed,
    GroupFailure.invalidLink => l10n.stlLinkInvalid,
    GroupFailure.linkLimit => l10n.stlErrorLinkLimit,
    GroupFailure.nextRoundExists => l10n.nxtErrorExists,
    GroupFailure.notMember ||
    GroupFailure.approvalRequired ||
    GroupFailure.approvalNotRequired ||
    GroupFailure.joinRequestNotFound ||
    GroupFailure.invalidQuestions ||
    GroupFailure.notOrganizer ||
    GroupFailure.organizerInviteNotFound ||
    GroupFailure.invalidResponse ||
    GroupFailure.invalidPayment ||
    GroupFailure.notMeetup ||
    GroupFailure.groupNotClosed ||
    GroupFailure.unknown => fallback,
  };
}
