import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/service_providers.dart';
import '../../../domain/models/announcement.dart';

// ============================================================
// Provider
// ============================================================

/// オフ会グループのお知らせ（新しい順。引数はチャットルームID。機能仕様書4.7.8.4）
final meetupAnnouncementsProvider = StreamProvider.autoDispose.family<List<Announcement>, String>((ref, chatRoomId) {
  return ref.watch(groupRepositoryProvider).watchAnnouncements(chatRoomId);
});
