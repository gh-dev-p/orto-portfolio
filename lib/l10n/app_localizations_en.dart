// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appHomeHeaderChatTitle => 'Chats';

  @override
  String get appHomeHeaderFriendTitle => 'Friends';

  @override
  String get appHomeHeaderSettingsTitle => 'Settings';

  @override
  String get addMenuAddFriend => 'Add Friend';

  @override
  String get addMenuAddFriendLabel => 'Add\nFriend';

  @override
  String get addMenuCreateGroupLabel => 'Create\nGroup';

  @override
  String get addMenuInvite => 'Invite';

  @override
  String get addMenuCreateChat => 'Chat';

  @override
  String get addMenuCreateGroup => 'Create Group';

  @override
  String get setLanguageTile => 'Language';

  @override
  String get languageJapanese => '日本語';

  @override
  String get languageEnglish => 'English';

  @override
  String get setDisplayModeTile => 'Display mode';

  @override
  String get displayModeLight => 'Light mode';

  @override
  String get displayModeDark => 'Dark mode';

  @override
  String get displayModeLightShort => 'Light';

  @override
  String get displayModeDarkShort => 'Dark';

  @override
  String get displayModeSystem => 'Use device setting';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonSave => 'Save';

  @override
  String get commonClose => 'Close';

  @override
  String get commonSearch => 'Search';

  @override
  String get commonRetry => 'Retry';

  @override
  String get commonReload => 'Reload';

  @override
  String get commonLoading => 'Loading…';

  @override
  String get commonPickCamera => 'Take a photo';

  @override
  String get commonPickGallery => 'Choose from gallery';

  @override
  String get commonPickCameraDenied =>
      'Camera access isn\'t allowed. Please allow camera access in your device\'s Settings app.';

  @override
  String get commonPickPhotoDenied =>
      'Photo access isn\'t allowed. Please allow photo access in your device\'s Settings app.';

  @override
  String get commonPickFailed => 'Couldn\'t select an image. Please try again.';

  @override
  String get commonDisplayNameLabel => 'Display name';

  @override
  String get commonAccountIdLabel => 'Account ID';

  @override
  String get commonDisplayNameHint => 'Enter display name';

  @override
  String get commonAccountIdHint => 'Enter account ID';

  @override
  String get authPhoneInputTitle => 'Enter your phone number';

  @override
  String get authNextButton => 'Next';

  @override
  String get authLegalConsentNotice => 'By tapping \"Next\", you agree to the Terms of Service and Privacy Policy.';

  @override
  String get authVerificationResentSnackbar => 'Verification code resent';

  @override
  String get authVerificationTitle => 'Enter the verification code';

  @override
  String authVerificationSentTo(String phoneNumber) {
    return 'Sent to $phoneNumber';
  }

  @override
  String get authVerificationRepeatedFailure => 'The code hasn\'t matched several times. Please resend the code.';

  @override
  String get authResendCode => 'Resend code';

  @override
  String authResendCodeCooldown(int seconds) {
    return 'Resend code (available in ${seconds}s)';
  }

  @override
  String get authConfirmButton => 'Confirm';

  @override
  String get authErrorInvalidPhoneNumber => 'That phone number isn\'t in a valid format';

  @override
  String get authErrorTooManyRequests => 'Too many requests. Please wait a while and try again.';

  @override
  String get authErrorNetwork => 'A network error occurred. Please try again.';

  @override
  String get authErrorInvalidVerificationCode => 'The verification code doesn\'t match';

  @override
  String get authErrorCodeExpired => 'The code has expired';

  @override
  String get authErrorSignInFailed => 'Sign-in failed';

  @override
  String get commonSelfAddNotAllowed => 'You can\'t add yourself';

  @override
  String get accCreationIdTakenOnSubmit => 'This ID was just taken by someone else. Please enter a different ID.';

  @override
  String get accCreationImageUploadFailed => 'Couldn\'t upload the image. The account was created without it.';

  @override
  String get accCreationFailedGeneric => 'Failed to create the account. Please try again.';

  @override
  String get accDeletionFailedGeneric => 'Failed to delete the account. Please try again.';

  @override
  String get friSearchFailed => 'Search failed. Please try again.';

  @override
  String get friSearchNotFound => 'No matching account was found';

  @override
  String get qrcScanNotFound => 'Couldn\'t read the QR code';

  @override
  String get pushNewMessageBanner => 'You have a new message';

  @override
  String get pushReactionBanner => 'Someone reacted to your message';

  @override
  String get startupErrorTitle => 'Couldn\'t start the app';

  @override
  String get startupErrorMessage => 'Check your connection and restart the app.';

  @override
  String get accountFetchFailedMessage =>
      'Couldn\'t load your account information. Check your connection and try again.';

  @override
  String get accCreationTitle => 'Create Account';

  @override
  String accCreationNumberedTitle(String number) {
    String _temp0 = intl.Intl.selectLogic(number, {
      '1': 'Create your 1st account',
      '2': 'Create your 2nd account',
      '3': 'Create your 3rd account',
      'other': 'Create your ${number}th account',
    });
    return '$_temp0';
  }

  @override
  String get accCreationPickImageButton => 'Choose image';

  @override
  String get accCreationDisplayNameLengthError => 'Enter a display name between 1 and 20 characters';

  @override
  String get accCreationCheckAvailability => 'Check availability';

  @override
  String get accCreationIdImmutableNote => '* You can\'t change or delete the account ID after creating it';

  @override
  String get accCreationSubmitButton => 'Create';

  @override
  String get accCreationIdHintFormat => 'Letters, numbers, and . - _ only, 4-20 characters';

  @override
  String get accCreationIdFormatError => 'Use letters, numbers, and . - _ only, 4-20 characters';

  @override
  String get accCreationIdChecking => 'Checking...';

  @override
  String get accCreationIdAvailable => '✓ Available';

  @override
  String get accCreationIdTaken => 'This ID is already taken';

  @override
  String get accCreationIdReserved => 'This ID can\'t be used';

  @override
  String get accCreationIdCheckHint =>
      'Tap \"Check availability\" to check (you can still create the account without checking)';

  @override
  String get accDeletionTitle => 'Delete Account';

  @override
  String get accDeletionConfirmMessage =>
      'Delete this account?\nIts display name, status message, profile and background images, and its friends, blocks, and chat list will be deleted. Others will see it as a \"Deleted account\".\nMessages you sent remain in the other person\'s chat history.\nIf you delete accounts repeatedly, you won\'t be able to create a new one for a while.\n\n* After deletion, this ID cannot be used to create a new account.';

  @override
  String get accDeletionSubmitButton => 'Delete';

  @override
  String get accListLoadError => 'Failed to load accounts';

  @override
  String get accListEmpty => 'No accounts';

  @override
  String get accListProfileButton => 'Profile';

  @override
  String get accListHeaderTitle => 'Accounts';

  @override
  String get commonUnknownAccount => 'Unknown account';

  @override
  String get commonDeletedAccount => 'Deleted account';

  @override
  String get commonSendFailedRetry => 'Failed to send. Please try again.';

  @override
  String get chaMessagesLoadError => 'Failed to load messages';

  @override
  String get chaEmptyMessages => 'No messages yet';

  @override
  String get chaListYesterday => 'Yesterday';

  @override
  String get chaRetryTooltip => 'Tap to resend';

  @override
  String get chaReadLabel => 'Read';

  @override
  String get chaMessageInputHint => 'Write a message...';

  @override
  String get chaMessageActionUnsend => 'Unsend';

  @override
  String get chaMessageActionDelete => 'Delete';

  @override
  String get chaUnsendConfirmTitle => 'Unsend this message?';

  @override
  String get chaUnsendConfirmMessage =>
      'The message will disappear from your screen and the recipient\'s. This can\'t be undone. Its content will still be kept for a limited time, accessible only to the operator, for purposes such as investigating misuse.';

  @override
  String get chaUnsendFailed => 'Failed to unsend the message';

  @override
  String get chaDeleteConfirmTitle => 'Delete this message?';

  @override
  String get chaDeleteConfirmMessage =>
      'It will only be removed from your screen. It will still appear on the recipient\'s screen.';

  @override
  String get chaDeleteFailed => 'Failed to delete the message';

  @override
  String get chaReactionFailed => 'Failed to react';

  @override
  String get chaMessageActionCopy => 'Copy';

  @override
  String get chaMessageActionPartialCopy => 'Select text';

  @override
  String get chaListLoadError => 'Failed to load chats';

  @override
  String get chaListEmpty => 'No chats yet.\nAdd a friend to start chatting here.';

  @override
  String get bottomNavChatTab => 'Chats';

  @override
  String get bottomNavFriendTab => 'Friends';

  @override
  String get bottomNavSettingsTab => 'Settings';

  @override
  String get commonComingSoon => 'Coming in a future release';

  @override
  String get friListLoadError => 'Failed to load friends';

  @override
  String get friListEmpty => 'No friends yet.\nSearch by account ID to add a friend.';

  @override
  String get friFilterTabLabel => 'Friends';

  @override
  String get friFilterGroupsTabLabel => 'Groups';

  @override
  String get friSearchTitle => 'Search for friends';

  @override
  String get friAddMenuTitle => 'Add a friend';

  @override
  String get friAddMenuQrCode => 'QR code';

  @override
  String friInviteMessage(String accountId, String link) {
    return 'Want to be friends on Orto?\nOpen the link below to add me as a friend. Orto lets you chat without sharing your phone number.\n$link\n\nIf the app doesn\'t open, search for the ID \"$accountId\".';
  }

  @override
  String friInviteMessageNoSearch(String link) {
    return 'Want to be friends on Orto?\nOpen the link below to add me as a friend. Orto lets you chat without sharing your phone number.\n$link';
  }

  @override
  String get friInviteShareFailed => 'Failed to share the invitation';

  @override
  String get friInviteLinkSelf => 'This is your own invitation link';

  @override
  String get friInviteLinkNotFound => 'The account that invited you was not found';

  @override
  String get commonUnset => 'Not set';

  @override
  String get commonIdCopied => 'ID copied';

  @override
  String get commonCopied => 'Copied';

  @override
  String get commonMyQrCode => 'My QR code';

  @override
  String get proFriendAddFailed => 'Failed to add. Please try again.';

  @override
  String get proNicknameDialogTitle => 'Set a nickname';

  @override
  String get proNicknameDialogHint => 'Leave blank and save to clear it';

  @override
  String get proNicknameSaveFailed => 'Failed to save the nickname. Please try again.';

  @override
  String get proEditImageSaveFailed => 'Failed to save the image. Please try again.';

  @override
  String get proEditNameDialogTitle => 'Edit display name';

  @override
  String get proEditNameSaveFailed => 'Failed to save the display name. Please try again.';

  @override
  String get proEditBioLabel => 'Comment';

  @override
  String get proEditBioDialogTitle => 'Edit comment';

  @override
  String get proEditBioHint => 'Add a short comment';

  @override
  String get proEditBioSaveFailed => 'Failed to save the comment. Please try again.';

  @override
  String get proEditSettingsSaveFailed => 'Failed to save the setting. Please try again.';

  @override
  String get proEditAppBarTitle => 'Main Profile';

  @override
  String get proEditAllowIdSearchTitle => 'Allow friend requests by ID';

  @override
  String get proEditAllowIdSearchSubtitle =>
      'When on, others can find you by ID and add you as a friend. Even when off, people can still add you from the QR code or invite link you share.';

  @override
  String get qrcDetectFailed => 'Couldn\'t detect a QR code';

  @override
  String get qrcSegmentScan => 'Scan';

  @override
  String get qrcOverlayHint => 'Align the QR code within the frame';

  @override
  String get qrcCameraPermissionDenied =>
      'Camera access isn\'t allowed. Please allow camera access in your device settings.';

  @override
  String get qrcCameraUnavailable => 'The camera couldn\'t be used.';

  @override
  String get qrcShareFailed => 'Failed to share';

  @override
  String get qrcGenerateFailed => 'Failed to generate the QR code';

  @override
  String get qrcShareButton => 'Share';

  @override
  String get qrcCopyIdButton => 'Copy ID';

  @override
  String get setPasscodeTile => 'Passcode lock';

  @override
  String get passcodeEnterTitle => 'Enter passcode';

  @override
  String get passcodeConfirmCurrentTitle => 'Enter current passcode';

  @override
  String get passcodeWrong => 'Incorrect passcode. Please try again.';

  @override
  String passcodeWaitSeconds(int seconds) {
    return 'Too many wrong attempts. Try again in $seconds s.';
  }

  @override
  String passcodeWaitMinutes(int minutes) {
    return 'Too many wrong attempts. Try again in $minutes min.';
  }

  @override
  String get passcodeExhausted => 'Too many wrong attempts. Tap \"Forgot your passcode?\" to unlock.';

  @override
  String get passcodeExhaustedConfirm => 'Too many wrong attempts. Tap \"Forgot your passcode?\" on the unlock screen.';

  @override
  String notificationSwitchedAccount(String name) {
    return 'Switched to $name';
  }

  @override
  String get transferPasswordContactSupport => 'Contact us';

  @override
  String get passcodeForgot => 'Forgot your passcode?';

  @override
  String get passcodeSetupTitle => 'Set passcode';

  @override
  String get passcodeSetupNewTitle => 'Enter a new passcode';

  @override
  String get passcodeSetupConfirmTitle => 'Enter it again';

  @override
  String get passcodeMismatch => 'Passcodes do not match. Please try again.';

  @override
  String get passcodeSaveFailed => 'Could not set the passcode. Please try again.';

  @override
  String get passcodeResetFailed => 'Could not remove the passcode. Please try again.';

  @override
  String get passcodeKeypadDelete => 'Delete';

  @override
  String get setProfileTile => 'Profile';

  @override
  String get setAccountDeletionTile => 'Delete Account';

  @override
  String get setBlockListTitle => 'Blocked accounts';

  @override
  String get setContactTile => 'Contact us';

  @override
  String get setPrivacyPolicyTile => 'Privacy policy';

  @override
  String setAppVersion(String version, String buildNumber) {
    return 'Version $version ($buildNumber)';
  }

  @override
  String get setTermsOfServiceTile => 'Terms of service';

  @override
  String get setSectionThisAccount => 'This account';

  @override
  String get setSectionAllAccounts => 'All accounts';

  @override
  String get setSectionAppInfo => 'App info';

  @override
  String get setLinkOpenFailed => 'Couldn\'t open this';

  @override
  String get setBlockListEmpty => 'No blocked accounts';

  @override
  String get setBlockListLoadError => 'Failed to load blocked accounts';

  @override
  String get setBlockListUnblockButton => 'Unblock';

  @override
  String get setBlockListUnblockConfirmTitle => 'Unblock this account?';

  @override
  String get setBlockListUnblockConfirmMessage =>
      'Unblocking does not restore your previous friendship. You will need to add them as a friend again.';

  @override
  String get setBlockListUnblockFailed => 'Failed to unblock. Please try again.';

  @override
  String chaRequestSectionTitle(int count) {
    return 'Unconfirmed chat requests ($count)';
  }

  @override
  String get commonBlockButton => 'Block';

  @override
  String get commonBlockConfirmTitle => 'Block this account?';

  @override
  String get commonBlockConfirmMessage =>
      'You will no longer receive messages from this account, and your friendship will be removed. You can unblock them from the blocked accounts list.';

  @override
  String get commonBlockFailed => 'Failed to block. Please try again.';

  @override
  String get setPhoneNumberTile => 'Phone number';

  @override
  String get setNotificationTile => 'Notifications';

  @override
  String get setNotificationMessagesTitle => 'Notifications';

  @override
  String get setNotificationMessagesSubtitle => 'Get notified of messages to this account';

  @override
  String get setNotificationReactionsTitle => 'Reactions';

  @override
  String get setNotificationReactionsSubtitle => 'Get notified of reactions to your messages and show them as unread';

  @override
  String get setNotificationDeviceOff =>
      'Notifications for Orto are turned off in your device settings. Turn them on in your device settings to receive notifications.';

  @override
  String get setNotificationOpenDeviceSettings => 'Open device settings';

  @override
  String get setNotificationLoadError => 'Couldn\'t load notification settings';

  @override
  String get setNotificationUpdateFailed => 'Couldn\'t save the change. Please try again';

  @override
  String get setLogoutTile => 'Sign out';

  @override
  String get setLogoutConfirmTitle => 'Sign out?';

  @override
  String get setLogoutConfirmMessage =>
      'You\'ll be signed out on this device. To use it again, you\'ll need to verify with an SMS code.';

  @override
  String get setLogoutFailed => 'Couldn\'t sign out. Check your connection and try again';

  @override
  String get setLogoutDenied => 'Couldn\'t sign out because the server denied the request';

  @override
  String get setWithdrawalTile => 'Delete user';

  @override
  String get withdrawalTitle => 'Delete user';

  @override
  String get withdrawalMessage =>
      'Deleting your user removes all accounts for this phone number.\nOthers will see them as \"Deleted account\". Messages you sent remain in the other person\'s chat history. If you want any messages removed, contact us before deleting your user (from one year after deletion we can no longer verify your identity and can\'t handle requests).\nIf you sign in again with the same phone number, your previous accounts cannot be restored.\nPaid plan subscriptions are not cancelled when you delete your user. Please cancel them in the store you subscribed from (App Store or Google Play).';

  @override
  String get withdrawalAcknowledge => 'I understand that all my accounts will be deleted and can\'t be restored';

  @override
  String get withdrawalSlideLabel => 'Slide to delete user';

  @override
  String get withdrawalSubmitButton => 'Delete user';

  @override
  String get withdrawalFailed => 'Couldn\'t delete your user. Check your connection and try again';

  @override
  String get phoneChangeTitle => 'Change phone number';

  @override
  String get phoneChangeDescription =>
      'Enter your new phone number.\nWe\'ll confirm it with a code sent by SMS.\nYour accounts, chats, and friends stay the same.';

  @override
  String get phoneChangeCompleted => 'Your phone number has been changed';

  @override
  String get authErrorPhoneNumberInUse => 'This phone number is already used by another user';

  @override
  String get authErrorSamePhoneNumber => 'This is your current phone number';

  @override
  String get authErrorUnsupportedRegion => 'Phone numbers from this country or region aren\'t supported';

  @override
  String get authCountrySelectLabel => 'Select country or region';

  @override
  String get setTransferPasswordTile => 'Transfer password';

  @override
  String get setTransferPasswordRegistered => 'Set';

  @override
  String get setTransferPasswordNotRegistered => 'Not set';

  @override
  String get transferPasswordSetupTitle => 'Transfer password';

  @override
  String get transferPasswordSetupDescription =>
      'When you sign in on a new device, you\'ll be asked for this password in addition to the SMS code.\nThis keeps your accounts safe even if your phone number is later reassigned to someone else.\nIf you forget it, you can\'t transfer your accounts to a new device.';

  @override
  String get transferPasswordFieldLabel => 'Password (8–64 characters)';

  @override
  String get transferPasswordConfirmFieldLabel => 'Password (confirm)';

  @override
  String get transferPasswordFieldHint => 'Enter password';

  @override
  String get transferPasswordConfirmFieldHint => 'Enter it again';

  @override
  String get transferPasswordMismatch => 'Passwords don\'t match';

  @override
  String get transferPasswordSaveButton => 'Save';

  @override
  String get transferPasswordPromptTitle => 'Set a transfer password?';

  @override
  String get transferPasswordPromptMessage =>
      'This keeps your accounts safe even if your phone number is later reassigned to someone else.\nIf you forget it, you can\'t transfer your accounts to a new device.';

  @override
  String get transferPasswordPromptSetUp => 'Set up';

  @override
  String get transferPasswordPromptLater => 'Later';

  @override
  String get transferPasswordSaved => 'Your transfer password has been set';

  @override
  String get transferPasswordEntryTitle => 'Enter transfer password';

  @override
  String get transferPasswordEntryDescription =>
      'A transfer password is set for this phone number.\nEnter it to use your accounts on this device.';

  @override
  String get transferPasswordEntryButton => 'Confirm';

  @override
  String get transferPasswordForgot => 'Forgot password?';

  @override
  String get transferPasswordForgotTitle => 'Forgot password';

  @override
  String get transferPasswordForgotMessage =>
      'Transfer passwords can\'t be reissued. If you\'re still signed in on your previous device, set a new password in its settings.\nIf you can\'t use your previous device, you can delete your previous data (all accounts) and start over with this phone number. The deletion happens 7 days after the request, and it can be canceled from your previous device until then.';

  @override
  String get transferResetStart => 'Delete data and start over';

  @override
  String get transferResetConfirmTitle => 'Delete your previous data?';

  @override
  String get transferResetConfirmMessage =>
      '7 days after the request, all accounts for this phone number will be deleted, the same as deleting your user. This can\'t be undone.\nIf you sign in again after the 7 days, you can start over.\nIf you\'re still signed in on your previous device, it will be notified and can cancel the request.';

  @override
  String get transferResetConfirmButton => 'Request';

  @override
  String transferResetPending(String date) {
    return 'Your previous data will be deleted after $date. Sign in again after that to start over.';
  }

  @override
  String get transferResetCancel => 'Cancel the request';

  @override
  String get transferResetFailed => 'Couldn\'t complete the request. Check your connection and try again';

  @override
  String get transferResetAlertTitle => 'Data deletion requested';

  @override
  String transferResetAlertMessage(String date) {
    return 'Someone on a new device said they forgot the transfer password and requested deletion of the data for this phone number. All accounts will be deleted on $date.\nIf it wasn\'t you, cancel the request.';
  }

  @override
  String get transferResetAlertCancel => 'Cancel request';

  @override
  String get transferResetAlertLater => 'Close';

  @override
  String get transferResetCanceled => 'Request canceled';

  @override
  String get legalUpdateTitle => 'We\'ve updated our Terms and Privacy Policy';

  @override
  String get legalUpdateMessage => 'Please review the updated documents and tap \"Agree\".';

  @override
  String get legalUpdateAgree => 'Agree';

  @override
  String get legalUpdateFailed => 'Couldn\'t save your agreement. Check your connection and try again';

  @override
  String get transferPasswordBackToPhoneInput => 'Back to phone number entry';

  @override
  String get transferPasswordErrorWrong => 'Incorrect password';

  @override
  String get transferPasswordErrorLocked => 'Too many attempts. Please try again later';

  @override
  String get transferPasswordErrorInvalid => 'Enter a password of 8–64 characters';

  @override
  String get transferPasswordErrorNetwork => 'Connection failed. Check your connection and try again';

  @override
  String get chaListReactionPreview => 'Reacted to your message';

  @override
  String get chaImagePreviewLabel => 'Photo';

  @override
  String get chaImageButtonTooltip => 'Send a photo';

  @override
  String get chaImageSendButton => 'Send';

  @override
  String get chaImagePreparing => 'Preparing photo…';

  @override
  String get chaImageSendFailed => 'Couldn\'t send the photo. Please try again';

  @override
  String get chaImageTooLarge => 'This photo is too large to send (up to 10MB)';

  @override
  String get chaImageLoadFailed => 'Couldn\'t load the photo';

  @override
  String get chaImageSaveTooltip => 'Save';

  @override
  String get chaImageSaved => 'Photo saved';

  @override
  String get chaImageSaveFailed => 'Couldn\'t save the photo';

  @override
  String get chaImageSaveDenied =>
      'Access to photos isn\'t allowed. Allow access to photos in your device\'s Settings app.';

  @override
  String get chaImageMine => 'You';

  @override
  String get commonReportButton => 'Report';

  @override
  String get repTitle => 'Report';

  @override
  String get repDescription => 'Choose a reason for your report.\nThe other person won\'t be notified.';

  @override
  String get repReasonLabel => 'Reason';

  @override
  String get repReasonSpam => 'Spam or advertising';

  @override
  String get repReasonHarassment => 'Harassment or bullying';

  @override
  String get repReasonImpersonation => 'Impersonation';

  @override
  String get repReasonInappropriate => 'Inappropriate content';

  @override
  String get repReasonOther => 'Other';

  @override
  String get repDetailLabel => 'Details (optional)';

  @override
  String get repDetailHint => 'What was the problem?';

  @override
  String get repAlsoBlock => 'Block this person';

  @override
  String get repSubmitButton => 'Report';

  @override
  String get repDone => 'Reported';

  @override
  String get repDoneAndBlocked => 'Reported and blocked';

  @override
  String get repBlockFailed => 'Reported, but couldn\'t block';

  @override
  String get repFailed => 'Couldn\'t send the report. Please try again.';

  @override
  String get appUpdateTitle => 'Update required';

  @override
  String get appUpdateMessage => 'Please install the latest version of the app.';

  @override
  String get appUpdateButton => 'Update';

  @override
  String get chaUnsupportedMessage => 'Update the app to view this message';

  @override
  String get chaSendButtonTooltip => 'Send';

  @override
  String get chaStickerButtonTooltip => 'Stickers';

  @override
  String get chaStickerPreviewLabel => 'Sticker';

  @override
  String get chaStickerUnavailable => 'Sticker unavailable';

  @override
  String get proMemoAdd => 'Add a note';

  @override
  String get proMemoSheetTitle => 'Note';

  @override
  String get proMemoHint => 'Add a note only you can see';

  @override
  String get proMemoEdit => 'Edit note';

  @override
  String get proMemoPrivate => 'Only you can see this';

  @override
  String get proMemoPinned => 'Pinned';

  @override
  String get proMemoPin => 'Pin to chat';

  @override
  String get proMemoSaveFailed => 'Failed to save the note. Please try again.';

  @override
  String get planTitle => 'Plan';

  @override
  String get planNameFree => 'Free';

  @override
  String get planNameGrade1 => 'Grade 1';

  @override
  String get planNameGrade2 => 'Grade 2';

  @override
  String get planNameAdmin => 'Operator';

  @override
  String planCurrent(String plan) {
    return 'Current plan: $plan';
  }

  @override
  String planAccountCount(int count, int limit) {
    return 'Accounts $count / $limit';
  }

  @override
  String planAccountCountUnlimited(int count) {
    return 'Accounts $count';
  }

  @override
  String planExtraAccounts(int count) {
    return '+$count accounts';
  }

  @override
  String planTotalAccounts(int count) {
    return 'Up to $count accounts in total';
  }

  @override
  String planPricePerMonth(String price) {
    return '$price / month';
  }

  @override
  String get planBuyButton => 'Subscribe';

  @override
  String get planChangeButton => 'Switch to this plan';

  @override
  String get planCurrentBadge => 'Current plan';

  @override
  String get planRestoreButton => 'Restore purchases';

  @override
  String planManageButton(String store) {
    return 'Cancel or change plan ($store)';
  }

  @override
  String planOtherStoreNotice(String store) {
    return 'This plan was purchased on $store. Use $store to change or cancel it.';
  }

  @override
  String planAutoRenewNotice(String account, String store) {
    return 'This is a monthly auto-renewing subscription charged to your $account. It renews automatically unless cancelled at least 24 hours before the period ends. You can cancel in your $store subscription settings. If you have more accounts than your plan allows after cancelling, the accounts over the limit become read-only.';
  }

  @override
  String get planBillingAccountGoogle => 'Google Account';

  @override
  String get planStoreUnavailable => 'Purchases are not available on this device right now.';

  @override
  String get planLoadError => 'Could not load plans';

  @override
  String get planPurchaseApplied => 'Your plan has been updated';

  @override
  String get planPurchasePending => 'Waiting for purchase approval';

  @override
  String get planPurchaseFailed => 'Could not apply your purchase. Please try \"Restore purchases\" later';

  @override
  String get planNothingToRestore => 'No purchases to restore';

  @override
  String planCurrentScheduled(String plan, String date, String next) {
    return 'Current plan: $plan ($next from $date)';
  }

  @override
  String get planScheduledNotice =>
      'You can keep using your current plan until the change. To cancel the change, use \"Cancel or change plan\".';

  @override
  String get planScheduledBadge => 'Change scheduled';

  @override
  String get planChangeScheduled => 'Plan change scheduled. It takes effect on your next renewal date';

  @override
  String get planPurchaseAlreadyOwned =>
      'You\'re already subscribed to this plan or have a change scheduled. If you subscribed under another login, tap \"Restore purchases\" to move it here';

  @override
  String get planTransferButton => 'Transfer subscription';

  @override
  String planTransferNotice(String account, String plan) {
    return 'This $account has a $plan subscription. Transfer it to use it with this login. If another login is using it, that login returns to the Free plan.';
  }

  @override
  String get planTokushohoLink => 'Commercial Transactions Act notice';

  @override
  String get planReadOnlyNotice => 'Read-only: this account is over your plan\'s limit';

  @override
  String get planReadOnlyExplanation =>
      'You have more accounts than your plan allows, so every account except the ones you keep is read-only. Change your plan or delete accounts to get back within the limit.';

  @override
  String get planLimitReachedUpgrade => 'You\'ve reached your account limit. Change your plan to add more.';

  @override
  String get planLimitReachedTopPlan => 'You\'ve reached your account limit. You can\'t add any more accounts.';

  @override
  String get planKeptAccountsButton => 'Choose accounts to keep';

  @override
  String get keptAccountsTitle => 'Accounts to keep';

  @override
  String keptAccountsDescription(int limit) {
    return 'Choose $limit accounts to keep using. The others become read-only. You can change this once each time your plan changes.';
  }

  @override
  String get keptAccountsConfirmButton => 'Confirm';

  @override
  String get keptAccountsConfirmTitle => 'Keep these accounts?';

  @override
  String get keptAccountsConfirmMessage => 'You can\'t change this again until your plan changes.';

  @override
  String get keptAccountsSaved => 'Your accounts to keep are set';

  @override
  String get keptAccountsSaveFailed => 'Couldn\'t save. Please try again later';

  @override
  String get keptAccountsPromptTitle => 'You\'re over your plan\'s account limit';

  @override
  String get keptAccountsPromptMessage =>
      'You can keep using accounts up to the limit, and the others are read-only. You can change which accounts you keep once.';

  @override
  String get keptAccountsPromptChoose => 'Choose';

  @override
  String get planSeePlansButton => 'See plans';

  @override
  String get grpSelectFriendsTitle => 'Select friends';

  @override
  String get grpNext => 'Next';

  @override
  String get grpSearchHint => 'Search by name';

  @override
  String get grpCreateAction => 'Create';

  @override
  String get grpNameLabel => 'Group name';

  @override
  String get grpNameHint => 'Enter a group name';

  @override
  String get grpPolicyLabel => 'How invited friends join';

  @override
  String get grpPolicyApproval => 'Approval';

  @override
  String get grpPolicyApprovalDescription => 'Invited people can choose \"Join\" or \"Decline\"';

  @override
  String get grpPolicyAuto => 'Automatic';

  @override
  String get grpPolicyAutoDescription => 'Mutual friends join automatically when invited';

  @override
  String get grpPolicyFixedNote => 'This can\'t be changed after creating the group';

  @override
  String get grpCreateFailed => 'Couldn\'t create the group';

  @override
  String get grpListEmpty => 'You haven\'t joined any groups';

  @override
  String grpRequestSectionTitle(int count) {
    return 'Group invitations ($count)';
  }

  @override
  String grpRequestInvitedBy(String name) {
    return 'Invited by $name';
  }

  @override
  String get grpRequestJoin => 'Join';

  @override
  String get grpRequestDecline => 'Decline';

  @override
  String get grpRequestFailed => 'Something went wrong';

  @override
  String grpTitleWithCount(String name, int count) {
    return '$name ($count)';
  }

  @override
  String grpPreviewWithSender(String name, String text) {
    return '$name: $text';
  }

  @override
  String get grpMeetupStatusLate => 'Running late';

  @override
  String get grpMeetupStatusArrived => 'I\'m here';

  @override
  String get grpMeetupStatusNotFound => 'Can\'t find you';

  @override
  String get grpErrorReadOnly => 'Groups aren\'t available while your accounts are read-only';

  @override
  String get grpErrorGroupFull => 'This group is full';

  @override
  String get grpErrorJoinLimit => 'You\'ve reached the limit of groups you can join';

  @override
  String get grpErrorCreateLimit => 'You\'ve reached the limit of groups you can create';

  @override
  String get grpErrorMembersExceeded => 'This would exceed the group\'s member limit';

  @override
  String get grpErrorGroupDeleted => 'This group no longer exists';

  @override
  String get grpErrorInviteInvalid => 'This invite link is invalid';

  @override
  String grpSysCreated(String actor, String group) {
    return '$actor created the group \"$group\"';
  }

  @override
  String grpSysJoined(String name) {
    return '$name joined';
  }

  @override
  String grpSysLeft(String name) {
    return '$name left';
  }

  @override
  String grpSysRemoved(String actor, String target) {
    return '$actor removed $target';
  }

  @override
  String grpSysRenamed(String actor, String group) {
    return '$actor renamed the group to \"$group\"';
  }

  @override
  String grpSysPhotoChanged(String actor) {
    return '$actor changed the group photo';
  }

  @override
  String grpSysInviteReissued(String actor) {
    return '$actor reissued the invite link';
  }

  @override
  String get grpInfoTitle => 'Group info';

  @override
  String get grpNotifications => 'Notifications';

  @override
  String get grpMembersLoadError => 'Couldn\'t load members';

  @override
  String grpMemberMe(String name) {
    return '$name (you)';
  }

  @override
  String get grpRemoveMember => 'Remove';

  @override
  String grpRemoveConfirmMessage(String name) {
    return 'Remove $name from this group?';
  }

  @override
  String get grpLeave => 'Leave group';

  @override
  String get grpLeaveAction => 'Leave';

  @override
  String get grpLeaveConfirmTitle => 'Leave this group?';

  @override
  String get grpLeaveConfirmMessage => 'You won\'t be able to read the chat history, even if you rejoin.';

  @override
  String get grpReportGroup => 'Report this group';

  @override
  String get grpLeftNotice => 'You left this group';

  @override
  String grpReadCount(int count) {
    return 'Read $count';
  }

  @override
  String get repGroupDescription => 'You are reporting this group.\nChoose a reason.';

  @override
  String get pushGroupInviteBanner => 'You were invited to a group';

  @override
  String get grpInvite => 'Invite';

  @override
  String get grpInviteFromFriends => 'Choose from friends';

  @override
  String get grpInviteQrShare => 'Share QR code';

  @override
  String get grpInviteLinkCopy => 'Copy link';

  @override
  String get grpInviteLinkShare => 'Send invite link';

  @override
  String get grpInviteReissue => 'Reissue link and QR code';

  @override
  String get grpInviteReissueAction => 'Reissue';

  @override
  String get grpInviteReissueMessage => 'The current link and QR code will stop working';

  @override
  String get grpInviteNote => 'Anyone with the link can join';

  @override
  String grpInviteShareMessage(String groupName, String link) {
    return 'You\'re invited to the group \"$groupName\" on Orto.\nOpen the link below to see the group and continue to join. Orto lets you chat without sharing your phone number.\n$link';
  }

  @override
  String grpInviteQrShareMessage(String groupName) {
    return 'This is an invite QR code for the group \"$groupName\" on Orto. Scan it with your phone\'s camera to see the group and continue to join.';
  }

  @override
  String get grpInviteAction => 'Invite';

  @override
  String get grpInvited => 'Invited';

  @override
  String get grpJoinedLabel => 'Joined';

  @override
  String get grpMaxMembers => 'Up to 100 members';

  @override
  String get grpJoinTitle => 'Join group';

  @override
  String grpJoinAccount(String name) {
    return 'Joining as $name';
  }

  @override
  String get albPreviewLabel => 'Album';

  @override
  String get albListTitle => 'Albums';

  @override
  String get albEmpty => 'No albums yet';

  @override
  String get albLoadError => 'Couldn\'t load';

  @override
  String get albCreateTitle => 'Create album';

  @override
  String get albNameHint => 'Album name';

  @override
  String get albCreateFailed => 'Couldn\'t create the album';

  @override
  String get albTooManyAlbums => 'This chat can have up to 100 albums';

  @override
  String get albTooManyItems => 'An album can hold up to 1,000 items';

  @override
  String get albNoItems => 'No photos or videos';

  @override
  String get albDeleted => 'Deleted album';

  @override
  String get albSelect => 'Select';

  @override
  String get albRenameTitle => 'Rename';

  @override
  String get albDeleteTitle => 'Delete album';

  @override
  String get albDeleteMessage => 'All photos and videos in the album will be deleted. This can\'t be undone.';

  @override
  String get albDeleteConfirm => 'Delete';

  @override
  String get albDeleteItemsTitle => 'Delete items';

  @override
  String get albDeleteOnlyMine => 'You can delete only items you added';

  @override
  String get albUpdateFailed => 'Something went wrong. Please try again.';

  @override
  String get albSaved => 'Saved';

  @override
  String get albSaveFailed => 'Couldn\'t save';

  @override
  String get albVideoTooLong => 'Videos over 5 minutes can\'t be added';

  @override
  String get albFileTooLarge => 'The file is too large';

  @override
  String get albUnsupported => 'This format isn\'t supported';

  @override
  String get albRejected => 'You\'ve reached a limit or can\'t add items right now';

  @override
  String get albAddFailed => 'Check your connection';

  @override
  String get albRetry => 'Retry';

  @override
  String get albVideoLoadFailed => 'Couldn\'t play the video';

  @override
  String albUploading(int current, int total) {
    return 'Adding ($current/$total)';
  }

  @override
  String albItemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$count items', one: '1 item');
    return '$_temp0';
  }

  @override
  String albSelectedCount(int count) {
    return '$count selected';
  }

  @override
  String albDeleteItemsMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$count items', one: '1 item');
    return 'Delete $_temp0? This can\'t be undone.';
  }

  @override
  String albDeleteMineMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$count items', one: '1 item');
    return 'Delete the $_temp0 you added? Items from others stay.';
  }

  @override
  String albFailedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$count items', one: '1 item');
    return 'Couldn\'t add $_temp0.';
  }

  @override
  String albNoticeCreated(int count) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$count items', one: '1 item');
    return 'Created an album with $_temp0';
  }

  @override
  String albNoticeAdded(int count) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$count items', one: '1 item');
    return 'Added $_temp0 to the album';
  }

  @override
  String get authErrorAccountSuspended => 'This account has been suspended. Please contact support.';

  @override
  String get accCreationBlocked =>
      'You can\'t create a new account for a while because you deleted accounts repeatedly.';

  @override
  String get grpRequestMore => 'More';

  @override
  String get grpRequestBlockInviter => 'Block the person who invited you';

  @override
  String get accCreationInviterLabel => 'Account ID of the person who invited you (optional)';

  @override
  String get accCreationInviterHint => 'e.g. orto_friend';

  @override
  String get accCreationInviterNote => 'If you enter it, you can add them as a friend after creating your account';

  @override
  String get invitePasteTitle => 'Did you come from an invitation link?';

  @override
  String get invitePasteMessage =>
      'Paste the invitation you copied on the invitation page with the button below to go straight to adding your friend or joining the group after signing in.';

  @override
  String get invitePasteNotInvite => 'That was not an invitation link';

  @override
  String get invitePasteReceivedTitle => 'Invitation received';

  @override
  String invitePasteReceivedFriend(String accountId) {
    return 'Inviting account ID: $accountId\nYou can add them as a friend after signing in and creating your account.';
  }

  @override
  String get invitePasteReceivedGroup => 'You can join the group after signing in and creating your account.';

  @override
  String get invitePasteClose => 'Close';

  @override
  String get inviteAccountTitleFriend => 'Which account do you want to add them with?';

  @override
  String get inviteAccountTitleGroup => 'Which account do you want to join with?';

  @override
  String get inviteAccountNote => 'They will only see the account you choose';

  @override
  String inviteAccountId(String accountId) {
    return 'ID: $accountId';
  }

  @override
  String get inviteAccountCurrent => 'In use';

  @override
  String get inviteAccountReadOnly => 'Read-only, can\'t be used';

  @override
  String inviteSwitchedAccount(String name) {
    return 'Switched to $name';
  }

  @override
  String proAddAs(String name) {
    return 'Adding as $name';
  }

  @override
  String grpInviteAs(String name) {
    return 'Inviting as $name';
  }

  @override
  String get friInviteAsTitle => 'Invite with this account';

  @override
  String get friInviteSend => 'Send invitation';

  @override
  String get qrcMyQrAccountNote => 'This is the QR code for this account';

  @override
  String get grpKindTitle => 'Group type';

  @override
  String get grpKindStandard => 'Regular group';

  @override
  String get grpKindStandardDescription => 'A group to chat with friends. Everyone can do the same things.';

  @override
  String get grpKindMeetup => 'Meetup group';

  @override
  String get grpKindMeetupDescription =>
      'A group for meetups and events. The organizer team manages members and posts announcements. It closes after the event.';

  @override
  String get grpKindFixedNote => 'The type can\'t be changed later';

  @override
  String get grpMeetupBadge => 'Meetup';

  @override
  String get grpMeetupDateUndecided => 'Date TBD';

  @override
  String grpMeetupDaysLeft(int count) {
    return '$count days left';
  }

  @override
  String get grpMeetupClosed => 'Ended';

  @override
  String get grpMeetupClosedNotice => 'This group has closed';

  @override
  String grpMeetupClosedNoticeWithDate(String date) {
    return 'This group has closed. Its history will be deleted on $date';
  }

  @override
  String get grpCloseDayTitle => 'Close the group';

  @override
  String get grpCloseDayNextDay => 'Next day';

  @override
  String get grpCloseDay3Days => '3 days later';

  @override
  String get grpCloseDayWeek => '1 week later';

  @override
  String grpCloseDayN(int count) {
    return '$count days after the meetup';
  }

  @override
  String get grpCloseDayNote =>
      'Counted from the meetup date. After the meetup, you can extend it up to 2 weeks from the meetup day. Members are notified 24 hours and 1 hour before it closes';

  @override
  String get grpErrorGroupClosed => 'This group has closed';

  @override
  String get grpErrorInvalidCloseDays => 'Choose a day that is more than 1 hour from now';

  @override
  String grpSysCloseUpdated(String name) {
    return '$name changed when the group closes';
  }

  @override
  String get grpSysClosingSoon24h => 'This group will close within 24 hours';

  @override
  String get grpSysClosingSoon1h => 'This group will close within 1 hour';

  @override
  String get grpSysClosed => 'The group has closed';

  @override
  String pushGroupClosing24hBanner(String name) {
    return '$name will close within 24 hours';
  }

  @override
  String pushGroupClosing1hBanner(String name) {
    return '$name will close within 1 hour';
  }

  @override
  String get grpOrganizerTeamHeading => 'Organizer team';

  @override
  String get grpMembersHeading => 'Members';

  @override
  String get grpOrganizerBadge => 'Organizer';

  @override
  String get grpOrganizerInvitedLabel => 'Invited to organize';

  @override
  String get grpInviteToOrganizers => 'Add to organizer team';

  @override
  String get grpRemoveFromOrganizers => 'Remove from organizer team';

  @override
  String grpRemoveFromOrganizersConfirm(String name) {
    return 'Remove $name from the organizer team?';
  }

  @override
  String get grpLeaveOrganizers => 'Leave organizer team';

  @override
  String get grpLeaveOrganizersConfirm => 'Leave the organizer team?';

  @override
  String grpOrganizerInviteCard(String name) {
    return '$name invited you to the organizer team';
  }

  @override
  String get grpOrganizerInviteAccept => 'Join';

  @override
  String get grpOrganizerInviteDecline => 'Decline';

  @override
  String get grpErrorLastOrganizer =>
      'You\'re the only organizer, so you can\'t leave. Add another member to the organizer team first.';

  @override
  String grpSysOrganizerAdded(String name) {
    return '$name joined the organizer team';
  }

  @override
  String grpSysOrganizerRemoved(String name) {
    return '$name left the organizer team';
  }

  @override
  String get pushOrganizerInviteBanner => 'You\'ve been invited to the organizer team';

  @override
  String grpPersonName(String name) {
    return '$name';
  }

  @override
  String get grpApplyJoin => 'Request to join';

  @override
  String get grpApplyNote =>
      'You can join once the organizer team approves. Only the organizer team sees your answers.';

  @override
  String get grpApplyAnswerHint => 'Your answer';

  @override
  String get grpApplyPending => 'Your request was sent. We\'ll notify you when the organizer team approves it.';

  @override
  String get grpApplyWaitlisted =>
      'You\'re on the waitlist. When a spot opens, the organizer team approves requests in the order they came in.';

  @override
  String grpApplyDeclined(String name) {
    return 'Your request to join $name was not approved';
  }

  @override
  String grpApplyClosed(String name) {
    return 'You couldn\'t join $name';
  }

  @override
  String get grpApplyAgain => 'Request again';

  @override
  String get grpApplyCancel => 'Cancel request';

  @override
  String get grpApplyCancelConfirmTitle => 'Cancel your request?';

  @override
  String get grpApplyCancelConfirmMessage => 'Your answers will also be deleted.';

  @override
  String get grpApplyCancelConfirm => 'Cancel request';

  @override
  String grpApplicationSectionTitle(int count) {
    return 'Join requests ($count)';
  }

  @override
  String get grpApplicationPending => 'Waiting for approval';

  @override
  String get grpApplicationWaitlisted => 'On the waitlist';

  @override
  String get grpApplicationDeclined => 'Not approved';

  @override
  String get grpApplicationClosed => 'Couldn\'t join';

  @override
  String grpJoinRequestBanner(int count) {
    return '$count join requests';
  }

  @override
  String get grpJoinRequestsMenu => 'Join requests';

  @override
  String get grpJoinQuestionsMenu => 'Join questions';

  @override
  String grpJoinQuestionsCount(int count) {
    return '$count';
  }

  @override
  String get grpJoinQuestionsNone => 'None';

  @override
  String get grpJoinRequestsTitle => 'Join requests';

  @override
  String grpJoinRequestsPendingHeading(int count) {
    return 'Waiting for approval ($count)';
  }

  @override
  String grpJoinRequestsWaitlistHeading(int count) {
    return 'Waitlist ($count)';
  }

  @override
  String grpJoinRequestsWaitlistOrder(int order) {
    return '#$order';
  }

  @override
  String get grpJoinRequestsEmpty => 'No join requests';

  @override
  String get grpJoinRequestsNoQuestions => 'No questions';

  @override
  String get grpJoinRequestsLoadError => 'Couldn\'t load join requests';

  @override
  String get grpJoinRequestApprove => 'Approve';

  @override
  String get grpJoinRequestDecline => 'Decline';

  @override
  String grpJoinRequestDeclineTitle(String name) {
    return 'Decline $name\'s request?';
  }

  @override
  String grpJoinRequestDeclineMessage(String group) {
    return 'They\'ll only be told \"Your request to join $group was not approved\".';
  }

  @override
  String get grpJoinRequestApproved => 'Approved';

  @override
  String get grpJoinRequestWaitlisted => 'The group is full, so the request was moved to the waitlist';

  @override
  String get grpErrorApplicantUnavailable => 'This person can\'t join right now. Please try again later';

  @override
  String get grpErrorInvalidAnswers =>
      'The questions changed, so your request wasn\'t sent. Please open the link again';

  @override
  String get grpJoinQuestionsTitle => 'Join questions';

  @override
  String get grpJoinQuestionsDescription =>
      'Questions for people who request to join from the invite link. You can set up to 3. Only the organizer team sees the answers.';

  @override
  String grpJoinQuestionsLabel(int number) {
    return 'Question $number';
  }

  @override
  String get grpJoinQuestionsExample => 'e.g. What\'s your X handle?';

  @override
  String get grpJoinQuestionsAdd => 'Add a question';

  @override
  String get grpJoinQuestionsRemove => 'Remove question';

  @override
  String get grpJoinQuestionsNote => 'Changing the questions doesn\'t change requests you\'ve already received';

  @override
  String get grpJoinQuestionsSaved => 'Saved';

  @override
  String get grpJoinQuestionsDiscardTitle => 'Discard changes?';

  @override
  String get grpJoinQuestionsDiscard => 'Discard';

  @override
  String get grpInviteMeetupNote => 'People who use the link can join once the organizer team approves';

  @override
  String get pushJoinRequestBanner => 'You have a new request to join';

  @override
  String pushJoinApprovedBanner(String name) {
    return 'Your request to join $name was approved';
  }

  @override
  String pushJoinWaitlistedBanner(String name) {
    return 'You\'re on the waitlist for $name';
  }

  @override
  String get grpMemberJoinAnswersNote => 'Answers from their join request (only the organizer team can see these)';

  @override
  String get grpMemberJoinAnswersProfile => 'View profile';

  @override
  String get frqSendButton => 'Send friend request';

  @override
  String frqSendAs(String name) {
    return 'Request as $name';
  }

  @override
  String get frqPending => 'Requested';

  @override
  String get frqAcceptButton => 'Accept';

  @override
  String get frqReceivedNotice => 'Sent you a friend request';

  @override
  String get frqSent => 'Friend request sent';

  @override
  String frqAccepted(String name) {
    return 'You\'re now friends with $name';
  }

  @override
  String get frqSendFailed => 'Couldn\'t send the request. Please try again.';

  @override
  String get frqNotMember => 'Couldn\'t send the request. They may have left the group.';

  @override
  String get frqRespondFailed => 'Something went wrong. Please try again.';

  @override
  String get frqInvalid => 'This request is no longer valid';

  @override
  String frqSectionTitle(int count) {
    return 'Friend requests ($count)';
  }

  @override
  String frqFromGroup(String groupName) {
    return 'From \"$groupName\"';
  }

  @override
  String get frqAccept => 'Accept';

  @override
  String get frqDecline => 'Decline';

  @override
  String get frqDeclineTitle => 'Decline this friend request?';

  @override
  String get frqDeclineMessage => 'They won\'t be notified that you declined.';

  @override
  String get frqMore => 'More';

  @override
  String get pushFriendRequestBanner => 'You received a friend request';

  @override
  String grpSysAnnouncementPosted(String name) {
    return '$name added an announcement';
  }

  @override
  String grpSysEventUpdated(String name) {
    return '$name updated the meetup date and place';
  }

  @override
  String get annPlaceUndecided => 'Place TBD';

  @override
  String annCollapsed(int count) {
    return 'Announcements ($count)';
  }

  @override
  String get annAdd => 'Add announcement';

  @override
  String get annEditTitle => 'Edit announcement';

  @override
  String get annPost => 'Post';

  @override
  String get annEdit => 'Edit';

  @override
  String get annTextHint => 'Meeting point, time, what to bring…';

  @override
  String get annPlaceHint => 'Venue name or address (optional)';

  @override
  String get annPlaceNote => 'Tapping it searches for the place in your maps app';

  @override
  String get annNotifyMembers => 'Notify members';

  @override
  String annUpdatedAt(String time) {
    return 'Updated $time';
  }

  @override
  String get annDeleteConfirm => 'Delete this announcement?';

  @override
  String get annErrorLimit => 'You can have up to 20 announcements. Delete an old one first.';

  @override
  String get annErrorNotFound => 'This announcement has been deleted';

  @override
  String get annMakeFromMessage => 'Announce';

  @override
  String get annEventTitle => 'Date and place';

  @override
  String get annEventEdit => 'Edit date and place';

  @override
  String get annEventDate => 'Date & time';

  @override
  String get annEventDateUnset => 'Not set';

  @override
  String get annEventNote => 'Once set, the date can be changed but not cleared';

  @override
  String get annErrorEventPast => 'Choose a date and time in the future';

  @override
  String get annOpenAppleMaps => 'Open in Apple Maps';

  @override
  String get annOpenGoogleMaps => 'Open in Google Maps';

  @override
  String get annCopyPlace => 'Copy place';

  @override
  String get annMapOpenFailed => 'Couldn\'t open the maps app';

  @override
  String get pushAnnouncementBanner => 'New announcement';

  @override
  String get annDeleteConfirmMessage => 'It will be removed for all members.';

  @override
  String get attTitle => 'Attendance';

  @override
  String get attYes => 'Going';

  @override
  String get attNo => 'Not going';

  @override
  String attSummary(int yes, int no, int unanswered) {
    return 'Going $yes · Not going $no · No reply $unanswered';
  }

  @override
  String attDeadlineAt(String date) {
    return 'Deadline $date';
  }

  @override
  String get attDeadlinePassed => 'Closed';

  @override
  String get attMyResponse => 'Your attendance';

  @override
  String get attDeadlineLabel => 'Deadline';

  @override
  String get attDeadlineNone => 'None';

  @override
  String get attDeadlineClear => 'Remove deadline';

  @override
  String get attNote => 'You can change your reply after the deadline.';

  @override
  String get attNoteAuto => 'Members who haven\'t replied get a reminder 24 hours before the deadline.';

  @override
  String get attRemind => 'Remind members who haven\'t replied';

  @override
  String attRemindConfirm(int count) {
    return 'Send a reminder to $count members who haven\'t replied?';
  }

  @override
  String get attRemindConfirmMessage => 'You can send a reminder once every 6 hours.';

  @override
  String get attRemindSend => 'Send';

  @override
  String attReminded(int count) {
    return 'Reminded $count members';
  }

  @override
  String get attDeadlineUpdated => 'Deadline updated';

  @override
  String attSectionYes(int count) {
    return 'Going ($count)';
  }

  @override
  String attSectionNo(int count) {
    return 'Not going ($count)';
  }

  @override
  String attSectionUnanswered(int count) {
    return 'No reply ($count)';
  }

  @override
  String get attErrorDeadline => 'Choose a deadline after now and no later than the meetup date';

  @override
  String get attErrorReminderTooSoon => 'You can send a reminder once every 6 hours. Please try again later.';

  @override
  String grpSysAttendanceDeadlineUpdated(String name) {
    return '$name updated the attendance deadline';
  }

  @override
  String grpSysCapacityUpdated(String name) {
    return '$name changed the capacity';
  }

  @override
  String get pushAttendanceReminderBanner => 'Please reply with your attendance';

  @override
  String pushJoinPromotedBanner(String name) {
    return 'You moved up from the waitlist for $name';
  }

  @override
  String get pushWaitlistPromotedBanner => 'Someone moved up from the waitlist';

  @override
  String get capTitle => 'Capacity';

  @override
  String capValue(int count) {
    return '$count';
  }

  @override
  String get capNone => 'None';

  @override
  String get capDescription =>
      'Counts all members, including the organizer team. Requests after it\'s full go on the waitlist and move up in order when a spot opens.';

  @override
  String capBelowMembers(int count) {
    return 'There are $count members now. No one will be removed, but no one new can join until a spot opens.';
  }

  @override
  String get capClear => 'No limit';

  @override
  String get capErrorRange => 'Capacity must be between 2 and 100';

  @override
  String capMemberCount(String name, int count, int capacity) {
    return '$name ($count/$capacity)';
  }

  @override
  String capPreview(int count) {
    return 'Capacity: $count';
  }

  @override
  String get capPreviewFull => 'It\'s full, so your request will go on the waitlist';

  @override
  String get grpJoinRequestPromoted => 'Moved up';

  @override
  String get stlTitle => 'Settlement';

  @override
  String stlYen(String amount) {
    return '¥$amount';
  }

  @override
  String get stlYenSuffix => 'JPY';

  @override
  String get stlRowStart => 'Start settlement';

  @override
  String stlRowMine(String amount, String status) {
    return 'Settlement: $amount · $status';
  }

  @override
  String stlRowTotal(String amount) {
    return 'Settlement: total $amount';
  }

  @override
  String get stlNotStarted => 'Settlement hasn\'t started yet.';

  @override
  String get stlNotTarget => 'You\'re not included in this settlement.';

  @override
  String get stlStatusUnpaid => 'Unpaid';

  @override
  String get stlStatusReported => 'Awaiting confirmation';

  @override
  String get stlStatusConfirmed => 'Paid';

  @override
  String get stlStatusFree => 'Nothing to pay';

  @override
  String get stlTotalLabel => 'Total';

  @override
  String stlRoundingValue(int unit) {
    return 'Rounded up to ¥$unit';
  }

  @override
  String get stlMyShare => 'Your share';

  @override
  String stlTierLabel(String name, int percent) {
    return '$name ($percent%)';
  }

  @override
  String get stlReportPaid => 'I\'ve paid';

  @override
  String get stlReportCancel => 'Undo \"I\'ve paid\"';

  @override
  String get stlReportedNote => 'Waiting for the organizer team to confirm.';

  @override
  String get stlConfirmedNote => 'The organizer team confirmed your payment.';

  @override
  String get stlMethodTitle => 'How did you pay?';

  @override
  String get stlMethodLink => 'Payment app';

  @override
  String get stlMethodCash => 'Cash';

  @override
  String get stlMethodOther => 'Other';

  @override
  String get stlLinksHeading => 'Where to pay';

  @override
  String get stlLinksEmpty => 'No payment links yet. Ask the organizer team how to pay.';

  @override
  String get stlLinkPayPay => 'PayPay';

  @override
  String stlLinkPayPayId(String id) {
    return 'PayPay ID: $id';
  }

  @override
  String stlLinkAddedBy(String name) {
    return 'Added by $name';
  }

  @override
  String get stlPayPayNote =>
      'When you send with PayPay, the recipient sees your display name. Receive links expire after 4 days.';

  @override
  String get stlInAppNote => 'Orto doesn\'t handle money. Pay in each service\'s own app.';

  @override
  String get stlLinkAdd => 'Add where to pay';

  @override
  String get stlLinkRemove => 'Remove';

  @override
  String get stlLinkRemoveConfirm => 'Remove this payment link?';

  @override
  String get stlLinkServicePayPayUrl => 'PayPay receive link';

  @override
  String get stlLinkServicePayPayId => 'PayPay ID';

  @override
  String get stlLinkServiceOther => 'Link to another service';

  @override
  String get stlLinkLabelHint => 'Service name (e.g. Rakuten Pay)';

  @override
  String get stlLinkIdHint => 'PayPay ID';

  @override
  String get stlLinkInvalid => 'Enter a PayPay link (paypay.ne.jp), a PayPay ID, or a link starting with https';

  @override
  String get stlLinkAddNote =>
      'Paste a receive link made in your own PayPay, or your PayPay ID. PayPay request links require identity verification for both sides.';

  @override
  String get stlOrganizerHeading => 'Everyone\'s payments';

  @override
  String stlCollected(String amount) {
    return 'Total to collect: $amount';
  }

  @override
  String stlCollectedSurplus(String amount, String surplus) {
    return 'Total to collect: $amount ($surplus over the total from rounding up)';
  }

  @override
  String stlConfirmedSum(String amount) {
    return 'Received: $amount';
  }

  @override
  String stlSectionReported(int count) {
    return 'Awaiting confirmation ($count)';
  }

  @override
  String stlSectionUnpaid(int count) {
    return 'Unpaid ($count)';
  }

  @override
  String stlSectionConfirmed(int count) {
    return 'Paid ($count)';
  }

  @override
  String stlSectionFree(int count) {
    return 'Nothing to pay ($count)';
  }

  @override
  String get stlLeft => 'Left';

  @override
  String stlShareSheetTitle(String name, String amount) {
    return '$name · $amount';
  }

  @override
  String get stlConfirm => 'Confirm received';

  @override
  String stlConfirmWith(String method) {
    return 'Mark as received ($method)';
  }

  @override
  String get stlRevert => 'Mark as unpaid';

  @override
  String get stlRemind => 'Remind unpaid members';

  @override
  String stlRemindConfirm(int count) {
    return 'Send a reminder to $count unpaid members?';
  }

  @override
  String get stlAutoNote =>
      'Unpaid members also get a reminder automatically before the group closes (24 hours before).';

  @override
  String get stlEdit => 'Edit settlement';

  @override
  String get stlDelete => 'Cancel settlement';

  @override
  String get stlDeleteConfirm => 'Cancel this settlement?';

  @override
  String get stlDeleteConfirmMessage => 'Everyone\'s amounts and payment records will be deleted.';

  @override
  String get stlEditTitle => 'Settlement settings';

  @override
  String get stlTotalHint => 'Total amount';

  @override
  String get stlErrorTotal => 'Enter an amount from ¥1 to ¥10,000,000';

  @override
  String get stlRoundingTitle => 'Rounding';

  @override
  String stlRoundingOption(int unit) {
    return '¥$unit';
  }

  @override
  String get stlRoundingNote =>
      'Each share is rounded up to this unit. The organizer team handles any amount collected over the total.';

  @override
  String get stlTiersHeading => 'Tiers (ratio)';

  @override
  String get stlTiersNote =>
      'The total is split by each tier\'s ratio. e.g. Standard 100%, No drinks 70%, Organizer 0% (free)';

  @override
  String get stlTierDefaultName => 'Standard';

  @override
  String get stlTierAdd => 'Add tier';

  @override
  String get stlTierAdded => 'Tier added. Choose a tier for each person.';

  @override
  String get stlTierEditTitle => 'Tier';

  @override
  String get stlTierDelete => 'Delete tier';

  @override
  String get stlTierNameHint => 'Name (e.g. No drinks)';

  @override
  String get stlTierPercentHint => 'Ratio';

  @override
  String get stlTierPercentNote => '0–500%. 100% is the standard; 0% pays nothing.';

  @override
  String stlPercent(int percent) {
    return '$percent%';
  }

  @override
  String stlTargetsHeading(int count) {
    return 'Included ($count)';
  }

  @override
  String get stlTargetsNote => 'At first, members who replied \"Going\" are included.';

  @override
  String stlResetConfirm(int count) {
    return '$count payment records will be reset to unpaid';
  }

  @override
  String get stlResetConfirmMessage => 'Their amounts change, so their payment records will be cleared. Save anyway?';

  @override
  String get stlStarted => 'Settlement started';

  @override
  String get stlSaved => 'Settlement saved';

  @override
  String get stlErrorInvalid => 'Please check your input';

  @override
  String get stlErrorNotFound => 'Settlement hasn\'t started or was cancelled';

  @override
  String get stlErrorNotTarget => 'You\'re not included in this settlement';

  @override
  String get stlErrorPaymentConfirmed => 'The organizer team already confirmed it. Ask them to undo it.';

  @override
  String get stlErrorLinkLimit => 'You can add up to 5 payment links';

  @override
  String grpSysSettlementStarted(String name) {
    return '$name started the settlement';
  }

  @override
  String grpSysSettlementUpdated(String name) {
    return '$name updated the settlement';
  }

  @override
  String grpSysSettlementDeleted(String name) {
    return '$name cancelled the settlement';
  }

  @override
  String get pushSettlementReminderBanner => 'Please pay your share for the meetup';

  @override
  String get nxtMenu => 'Create next round';

  @override
  String get nxtCreatedLabel => 'Created';

  @override
  String get nxtTitle => 'Create next round';

  @override
  String get nxtNameLabel => 'Group name';

  @override
  String get nxtDescription =>
      'Invitations will be sent to members of the last round. Only those who accept will join the next round.';

  @override
  String get nxtCarriedNote =>
      'The group photo, join questions, capacity, and closing day carry over. The date, place, announcements, and attendance don\'t.';

  @override
  String get nxtOrganizerNote => 'Organizers of the last round also join the organizer team when they accept.';

  @override
  String nxtInviteHeading(int count) {
    return 'Invite ($count)';
  }

  @override
  String get nxtNoMembers => 'There are no other members from the last round to invite';

  @override
  String get nxtSubmit => 'Create and send invitations';

  @override
  String get nxtCreated => 'Created the next round';

  @override
  String get nxtErrorExists => 'The next round has already been created';

  @override
  String get nxtErrorExpired => 'The history has been deleted, so the next round can\'t be created';

  @override
  String grpRequestNextRound(String previous, String name) {
    return 'Next round of \"$previous\" · invited by $name';
  }
}
