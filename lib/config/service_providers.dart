import 'package:app_links/app_links.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/account/account_repository.dart';
import '../data/repositories/account/active_account_repository.dart';
import '../data/repositories/app_config/app_config_repository.dart';
import '../data/repositories/auth/auth_repository.dart';
import '../data/repositories/auth/transfer_password_prompt_repository.dart';
import '../data/services/common/cloud_functions_service.dart';
import '../data/services/auth/firebase_auth_service.dart';
import '../data/services/billing/store_purchase_service.dart';
import '../data/repositories/billing/billing_repository.dart';
import '../data/repositories/block/block_repository.dart';
import '../data/services/chat/album_media_service.dart';
import '../data/services/chat/chat_image_storage_service.dart';
import '../data/services/chat/video_processing_service.dart';
import '../data/services/chat/photo_library_service.dart';
import '../data/repositories/chat/album_repository.dart';
import '../data/repositories/chat/chat_repository.dart';
import '../data/repositories/chat/firebase_album_repository.dart';
import '../data/services/common/firestore_cache_cleaner.dart';
import '../data/services/common/firestore_paths.dart';
import '../data/services/invite_link/invite_clipboard_service.dart';
import '../data/services/invite_link/invite_link_service.dart';
import '../data/repositories/friend/friend_repository.dart';
import '../data/repositories/friend/friend_request_repository.dart';
import '../data/repositories/group/group_repository.dart';
import '../data/repositories/notification/notification_repository.dart';
import '../data/repositories/passcode/passcode_repository.dart';
import '../data/repositories/report/report_repository.dart';
import '../data/services/passcode/passcode_store.dart';
import '../data/services/profile/profile_storage_service.dart';
import '../data/services/notification/push_notification_service.dart';
import '../data/repositories/user/user_repository.dart';
import '../domain/use_cases/complete_phone_verification_use_case.dart';
import '../domain/use_cases/logout_use_case.dart';
import '../domain/use_cases/withdraw_use_case.dart';
import 'preferences_provider.dart';

final firebaseAuthServiceProvider = Provider<FirebaseAuthService>((ref) => FirebaseAuthService(FirebaseAuth.instance));

final cloudFunctionsServiceProvider = Provider<CloudFunctionsService>(
  (ref) => CloudFunctionsService(FirebaseFunctions.instanceFor(region: 'asia-northeast1')),
);

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.watch(firebaseAuthServiceProvider), ref.watch(cloudFunctionsServiceProvider)),
);

/// Firestoreのパス（接続先の[FirebaseFirestore]）。Repositoryはこれを通してFirestoreを読み書きする。
final firestorePathsProvider = Provider<FirestorePaths>((ref) => FirestorePaths(FirebaseFirestore.instance));

final appConfigRepositoryProvider = Provider<AppConfigRepository>(
  (ref) => AppConfigRepository(ref.watch(firestorePathsProvider)),
);

final accountRepositoryProvider = Provider<AccountRepository>(
  (ref) => AccountRepository(ref.watch(firestorePathsProvider), ref.watch(profileStorageServiceProvider)),
);

final activeAccountRepositoryProvider = Provider<ActiveAccountRepository>(
  (ref) => ActiveAccountRepository(ref.watch(sharedPreferencesProvider)),
);

final transferPasswordPromptRepositoryProvider = Provider<TransferPasswordPromptRepository>(
  (ref) => TransferPasswordPromptRepository(ref.watch(sharedPreferencesProvider)),
);

final userRepositoryProvider = Provider<UserRepository>(
  (ref) => UserRepository(ref.watch(firestorePathsProvider), ref.watch(cloudFunctionsServiceProvider)),
);

final storePurchaseServiceProvider = Provider<StorePurchaseService>((ref) => StorePurchaseService());

final billingRepositoryProvider = Provider<BillingRepository>(
  (ref) => BillingRepository(ref.watch(cloudFunctionsServiceProvider)),
);

final chatRepositoryProvider = Provider<ChatRepository>(
  (ref) => ChatRepository(
    ref.watch(firestorePathsProvider),
    ref.watch(chatImageStorageServiceProvider),
    const PhotoLibraryService(),
    () => ref.read(firebaseAuthServiceProvider).currentUser?.uid,
  ),
);

/// トークのアルバム（機能仕様書4.4.9、データ設計書3.13）
final albumRepositoryProvider = Provider<AlbumRepository>(
  (ref) => FirebaseAlbumRepository(
    ref.watch(firestorePathsProvider),
    ref.watch(chatImageStorageServiceProvider),
    ref.watch(chatRepositoryProvider),
    ref.watch(reportRepositoryProvider),
  ),
);

/// トークのアルバムの入口を出すか
final albumFeatureEnabledProvider = Provider<bool>((ref) => true);

final albumMediaServiceProvider = Provider<AlbumMediaService>((ref) => AlbumMediaService(VideoProcessingService()));

final groupRepositoryProvider = Provider<GroupRepository>(
  (ref) => GroupRepository(
    ref.watch(firestorePathsProvider),
    ref.watch(cloudFunctionsServiceProvider),
    ref.watch(profileStorageServiceProvider),
  ),
);

final friendRepositoryProvider = Provider<FriendRepository>(
  (ref) => FriendRepository(ref.watch(firestorePathsProvider), ref.watch(cloudFunctionsServiceProvider)),
);

final friendRequestRepositoryProvider = Provider<FriendRequestRepository>(
  (ref) => FriendRequestRepository(ref.watch(firestorePathsProvider), ref.watch(cloudFunctionsServiceProvider)),
);

final inviteLinkServiceProvider = Provider<InviteLinkService>((ref) => InviteLinkService(AppLinks()));

final inviteClipboardServiceProvider = Provider<InviteClipboardService>((ref) => InviteClipboardService());

final blockRepositoryProvider = Provider<BlockRepository>((ref) => BlockRepository(ref.watch(firestorePathsProvider)));

final reportRepositoryProvider = Provider<ReportRepository>((ref) => ReportRepository(ref.watch(firestorePathsProvider)));

final chatImageStorageServiceProvider = Provider<ChatImageStorageService>(
  (ref) => ChatImageStorageService(FirebaseStorage.instance),
);

final profileStorageServiceProvider = Provider<ProfileStorageService>(
  (ref) => ProfileStorageService(FirebaseStorage.instance),
);

final pushNotificationServiceProvider = Provider<PushNotificationService>(
  (ref) => PushNotificationService(FirebaseMessaging.instance),
);

final notificationRepositoryProvider = Provider<NotificationRepository>(
  (ref) => NotificationRepository(ref.watch(pushNotificationServiceProvider), ref.watch(firestorePathsProvider)),
);

final passcodeStoreProvider = Provider<PasscodeStore>((ref) => PasscodeStore(const SecurePasscodeStorage()));

final passcodeRepositoryProvider = Provider<PasscodeRepository>(
  (ref) => PasscodeRepository(ref.watch(passcodeStoreProvider)),
);

final completePhoneVerificationUseCaseProvider = Provider<CompletePhoneVerificationUseCase>(
  (ref) => CompletePhoneVerificationUseCase(ref.watch(authRepositoryProvider), ref.watch(userRepositoryProvider)),
);

final logoutUseCaseProvider = Provider<LogoutUseCase>(
  (ref) => LogoutUseCase(
    ref.watch(authRepositoryProvider),
    ref.watch(notificationRepositoryProvider),
    FirestoreCacheCleaner(ref.watch(sharedPreferencesProvider)),
  ),
);

final withdrawUseCaseProvider = Provider<WithdrawUseCase>(
  (ref) => WithdrawUseCase(
    ref.watch(userRepositoryProvider),
    ref.watch(passcodeRepositoryProvider),
    FirestoreCacheCleaner(ref.watch(sharedPreferencesProvider)),
  ),
);
