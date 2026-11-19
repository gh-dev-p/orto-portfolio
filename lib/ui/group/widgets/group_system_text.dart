import '../../../l10n/app_localizations.dart';

/// システムメッセージ・誘いのカード・確認の文に入れる人の名前（機能仕様書4.7）
/// 日本語は「さん」を付ける。名前の代わりの「退会済みアカウント」「不明なアカウント」には付けない
String groupPersonName(AppLocalizations l10n, String name) {
  if (name == l10n.commonDeletedAccount || name == l10n.commonUnknownAccount) return name;
  return l10n.grpPersonName(name);
}

/// システムメッセージの本文（機能仕様書4.7）
/// [actorName]は操作した人、[targetName]は対象の人の表示名。知らない種類（新しいバージョンのアプリ向け）は[l10n.chaUnsupportedMessage]
String groupSystemText(
  AppLocalizations l10n, {
  required String? systemType,
  required String actorName,
  required String targetName,
  String? groupName,
  int? hoursLeft,
}) {
  actorName = groupPersonName(l10n, actorName);
  targetName = groupPersonName(l10n, targetName);
  return switch (systemType) {
    'group_created' => l10n.grpSysCreated(actorName, groupName ?? ''),
    'member_joined' => l10n.grpSysJoined(targetName),
    'member_left' => l10n.grpSysLeft(targetName),
    'member_removed' => l10n.grpSysRemoved(actorName, targetName),
    'group_renamed' => l10n.grpSysRenamed(actorName, groupName ?? ''),
    'group_photo_changed' => l10n.grpSysPhotoChanged(actorName),
    'invite_reissued' => l10n.grpSysInviteReissued(actorName),
    'organizer_added' => l10n.grpSysOrganizerAdded(targetName),
    'organizer_removed' => l10n.grpSysOrganizerRemoved(targetName),
    'announcement_posted' => l10n.grpSysAnnouncementPosted(actorName),
    'event_updated' => l10n.grpSysEventUpdated(actorName),
    'attendance_deadline_updated' => l10n.grpSysAttendanceDeadlineUpdated(actorName),
    'capacity_updated' => l10n.grpSysCapacityUpdated(actorName),
    // 精算（機能仕様書4.7.8.12）
    'settlement_started' => l10n.grpSysSettlementStarted(actorName),
    'settlement_updated' => l10n.grpSysSettlementUpdated(actorName),
    'settlement_deleted' => l10n.grpSysSettlementDeleted(actorName),
    // オフ会グループの期限（機能仕様書4.7.8.6・4.7.8.7）
    'close_updated' => l10n.grpSysCloseUpdated(actorName),
    'closing_soon' => hoursLeft == 1 ? l10n.grpSysClosingSoon1h : l10n.grpSysClosingSoon24h,
    'group_closed' => l10n.grpSysClosed,
    _ => l10n.chaUnsupportedMessage,
  };
}
