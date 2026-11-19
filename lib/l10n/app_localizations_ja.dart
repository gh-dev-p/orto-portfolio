// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get appHomeHeaderChatTitle => 'トーク';

  @override
  String get appHomeHeaderFriendTitle => '友だち';

  @override
  String get appHomeHeaderSettingsTitle => '設定';

  @override
  String get addMenuAddFriend => '友だち追加';

  @override
  String get addMenuAddFriendLabel => '友だち\n追加';

  @override
  String get addMenuCreateGroupLabel => 'グループ\n作成';

  @override
  String get addMenuInvite => '招待';

  @override
  String get addMenuCreateChat => 'トークルーム作成';

  @override
  String get addMenuCreateGroup => 'グループ作成';

  @override
  String get setLanguageTile => '言語';

  @override
  String get languageJapanese => '日本語';

  @override
  String get languageEnglish => 'English';

  @override
  String get setDisplayModeTile => '画面モード';

  @override
  String get displayModeLight => 'ライトモード';

  @override
  String get displayModeDark => 'ダークモード';

  @override
  String get displayModeLightShort => 'ライト';

  @override
  String get displayModeDarkShort => 'ダーク';

  @override
  String get displayModeSystem => '端末の設定に従う';

  @override
  String get commonCancel => 'キャンセル';

  @override
  String get commonSave => '保存';

  @override
  String get commonClose => '閉じる';

  @override
  String get commonSearch => '検索';

  @override
  String get commonRetry => '再試行';

  @override
  String get commonReload => '再読み込み';

  @override
  String get commonLoading => '読み込み中…';

  @override
  String get commonPickCamera => 'カメラで撮影';

  @override
  String get commonPickGallery => 'ギャラリーから選択';

  @override
  String get commonPickCameraDenied => 'カメラの利用が許可されていません。端末の設定アプリからカメラへのアクセスを許可してください。';

  @override
  String get commonPickPhotoDenied => '写真へのアクセスが許可されていません。端末の設定アプリから写真へのアクセスを許可してください。';

  @override
  String get commonPickFailed => '画像を選択できませんでした。もう一度お試しください';

  @override
  String get commonDisplayNameLabel => '表示名';

  @override
  String get commonAccountIdLabel => 'アカウントID';

  @override
  String get commonDisplayNameHint => '表示名を入力';

  @override
  String get commonAccountIdHint => 'アカウントIDを入力';

  @override
  String get authPhoneInputTitle => '電話番号を入力してください';

  @override
  String get authNextButton => '次へ';

  @override
  String get authLegalConsentNotice => '「次へ」を押すと、利用規約とプライバシーポリシーに同意したものとします。';

  @override
  String get authVerificationResentSnackbar => '認証コードを再送しました';

  @override
  String get authVerificationTitle => '認証コードを入力してください';

  @override
  String authVerificationSentTo(String phoneNumber) {
    return '$phoneNumber に送信しました';
  }

  @override
  String get authVerificationRepeatedFailure => '認証コードが繰り返し一致しません。コードを再送してください';

  @override
  String get authResendCode => 'コードを再送する';

  @override
  String authResendCodeCooldown(int seconds) {
    return 'コードを再送する（$seconds秒後に可能）';
  }

  @override
  String get authConfirmButton => '確認';

  @override
  String get authErrorInvalidPhoneNumber => '電話番号の形式が正しくありません';

  @override
  String get authErrorTooManyRequests => 'リクエストが多すぎます。しばらく時間をおいて再度お試しください';

  @override
  String get authErrorNetwork => '通信エラーが発生しました。再度お試しください';

  @override
  String get authErrorInvalidVerificationCode => '認証コードが一致しません';

  @override
  String get authErrorCodeExpired => 'コードの有効期限が切れました';

  @override
  String get authErrorSignInFailed => 'サインインに失敗しました';

  @override
  String get commonSelfAddNotAllowed => '自分自身は追加できません';

  @override
  String get accCreationIdTakenOnSubmit => 'このIDは他の方に使用されました。別のIDを入力してください';

  @override
  String get accCreationImageUploadFailed => '画像のアップロードに失敗しました。アカウントは画像なしで作成されました';

  @override
  String get accCreationFailedGeneric => '作成に失敗しました。再度お試しください';

  @override
  String get accDeletionFailedGeneric => '削除に失敗しました。再度お試しください';

  @override
  String get friSearchFailed => '検索に失敗しました。再度お試しください';

  @override
  String get friSearchNotFound => '該当するアカウントが見つかりません';

  @override
  String get qrcScanNotFound => 'QRコードを読み取れませんでした';

  @override
  String get pushNewMessageBanner => '新規メッセージがあります';

  @override
  String get pushReactionBanner => 'メッセージにリアクションがありました';

  @override
  String get startupErrorTitle => 'アプリを起動できませんでした';

  @override
  String get startupErrorMessage => '通信環境を確かめて、アプリを起動し直してください。';

  @override
  String get accountFetchFailedMessage => 'アカウント情報を読み込めませんでした。通信環境を確かめて、もう一度お試しください。';

  @override
  String get accCreationTitle => 'アカウント作成';

  @override
  String accCreationNumberedTitle(String number) {
    return '$numberつ目のアカウントを作成';
  }

  @override
  String get accCreationPickImageButton => '画像を選択';

  @override
  String get accCreationDisplayNameLengthError => '表示名は1〜20文字で入力してください';

  @override
  String get accCreationCheckAvailability => '使用可能か確認';

  @override
  String get accCreationIdImmutableNote => '※アカウントIDは作成後に変更・削除できません';

  @override
  String get accCreationSubmitButton => '作成する';

  @override
  String get accCreationIdHintFormat => '半角英数字・記号（. - _）のみ、4〜20文字';

  @override
  String get accCreationIdFormatError => '半角英数字・記号（. - _）のみ、4〜20文字で入力してください';

  @override
  String get accCreationIdChecking => '確認中...';

  @override
  String get accCreationIdAvailable => '✓ 使用可能です';

  @override
  String get accCreationIdTaken => 'このIDは既に使用されています';

  @override
  String get accCreationIdReserved => 'このIDは使用できません';

  @override
  String get accCreationIdCheckHint => '「使用可能か確認」で確認できます（未確認でも作成は可能です）';

  @override
  String get accDeletionTitle => 'アカウント削除';

  @override
  String get accDeletionConfirmMessage =>
      'このアカウントを削除しますか？\n表示名、一言コメント、プロフィール画像、背景画像と、友だち・ブロック・トーク一覧の情報を削除します。相手には「退会済みアカウント」として表示されます。\n送ったメッセージは、相手のトーク履歴に残ります。\n短い期間に削除を繰り返すと、しばらく新しいアカウントを作れなくなります。\n\n※削除後は、このIDを使って新しいアカウントを作成できません。';

  @override
  String get accDeletionSubmitButton => '削除する';

  @override
  String get accListLoadError => 'アカウント一覧の取得に失敗しました';

  @override
  String get accListEmpty => 'アカウントがありません';

  @override
  String get accListProfileButton => 'プロフィール';

  @override
  String get accListHeaderTitle => 'アカウント';

  @override
  String get commonUnknownAccount => '不明なアカウント';

  @override
  String get commonDeletedAccount => '退会済みアカウント';

  @override
  String get commonSendFailedRetry => '送信に失敗しました。再度お試しください';

  @override
  String get chaMessagesLoadError => 'メッセージの取得に失敗しました';

  @override
  String get chaEmptyMessages => 'まだメッセージがありません';

  @override
  String get chaListYesterday => '昨日';

  @override
  String get chaRetryTooltip => 'タップで再送';

  @override
  String get chaReadLabel => '既読';

  @override
  String get chaMessageInputHint => 'メッセージを入力';

  @override
  String get chaMessageActionUnsend => '送信取消';

  @override
  String get chaMessageActionDelete => '削除';

  @override
  String get chaUnsendConfirmTitle => '送信を取り消しますか？';

  @override
  String get chaUnsendConfirmMessage =>
      '取り消すと、自分と相手の画面からメッセージが消えます。この操作は元に戻せません。なお、内容は不正利用の調査などのため、運営者だけが確認できる場所に一定期間保管されます。';

  @override
  String get chaUnsendFailed => '送信取消に失敗しました';

  @override
  String get chaDeleteConfirmTitle => 'メッセージを削除しますか？';

  @override
  String get chaDeleteConfirmMessage => '削除すると、自分の画面からのみメッセージが消えます。相手の画面には残ります。';

  @override
  String get chaDeleteFailed => '削除に失敗しました';

  @override
  String get chaReactionFailed => 'リアクションに失敗しました';

  @override
  String get chaMessageActionCopy => 'コピー';

  @override
  String get chaMessageActionPartialCopy => '部分コピー';

  @override
  String get chaListLoadError => 'トーク一覧の取得に失敗しました';

  @override
  String get chaListEmpty => 'まだトークがありません。\n友だちを追加するとここに表示されます。';

  @override
  String get bottomNavChatTab => 'トーク';

  @override
  String get bottomNavFriendTab => '友だち';

  @override
  String get bottomNavSettingsTab => '設定';

  @override
  String get commonComingSoon => '今後リリース予定です';

  @override
  String get friListLoadError => '友だち一覧の取得に失敗しました';

  @override
  String get friListEmpty => 'まだ友だちがいません。\nアカウントIDで検索して友だちを追加しましょう。';

  @override
  String get friFilterTabLabel => '友だち';

  @override
  String get friFilterGroupsTabLabel => 'グループ';

  @override
  String get friSearchTitle => '友だちを検索';

  @override
  String get friAddMenuTitle => '友だちを追加';

  @override
  String get friAddMenuQrCode => 'QRコード';

  @override
  String friInviteMessage(String accountId, String link) {
    return 'Ortoで友だちになりませんか？\n下のリンクを開くと、友だちに追加できます。Ortoは、電話番号やLINEを相手に教えずにやりとりできるアプリです。\n$link\n\nアプリが開かないときは、ID「$accountId」で検索してください。';
  }

  @override
  String friInviteMessageNoSearch(String link) {
    return 'Ortoで友だちになりませんか？\n下のリンクを開くと、友だちに追加できます。Ortoは、電話番号やLINEを相手に教えずにやりとりできるアプリです。\n$link';
  }

  @override
  String get friInviteShareFailed => '招待の共有に失敗しました';

  @override
  String get friInviteLinkSelf => '自分の招待リンクです';

  @override
  String get friInviteLinkNotFound => '招待したアカウントが見つかりませんでした';

  @override
  String get commonUnset => '未設定';

  @override
  String get commonIdCopied => 'IDをコピーしました';

  @override
  String get commonCopied => 'コピーしました';

  @override
  String get commonMyQrCode => 'マイQRコード';

  @override
  String get proFriendAddFailed => '追加に失敗しました。再度お試しください';

  @override
  String get proNicknameDialogTitle => 'ニックネームを設定';

  @override
  String get proNicknameDialogHint => '未設定にするには空欄のまま保存';

  @override
  String get proNicknameSaveFailed => 'ニックネームの保存に失敗しました。再度お試しください';

  @override
  String get proEditImageSaveFailed => '画像の保存に失敗しました。再度お試しください';

  @override
  String get proEditNameDialogTitle => '表示名を編集';

  @override
  String get proEditNameSaveFailed => '表示名の保存に失敗しました。再度お試しください';

  @override
  String get proEditBioLabel => 'ひとこと';

  @override
  String get proEditBioDialogTitle => 'ひとことを編集';

  @override
  String get proEditBioHint => 'ひとことを入力';

  @override
  String get proEditBioSaveFailed => 'ひとことの保存に失敗しました。再度お試しください';

  @override
  String get proEditSettingsSaveFailed => '設定の保存に失敗しました。再度お試しください';

  @override
  String get proEditAppBarTitle => 'メインプロフィール';

  @override
  String get proEditAllowIdSearchTitle => 'IDによる友だち追加を許可';

  @override
  String get proEditAllowIdSearchSubtitle => 'オンにすると、ほかの人がIDで検索して友だちに追加できます。オフでも、あなたが渡したQRコード・招待リンクからは追加できます。';

  @override
  String get qrcDetectFailed => 'QRコードを検出できませんでした';

  @override
  String get qrcSegmentScan => '読み取り';

  @override
  String get qrcOverlayHint => 'QRコードを枠内に合わせてください';

  @override
  String get qrcCameraPermissionDenied => 'カメラの利用が許可されていません。端末の設定アプリからカメラへのアクセスを許可してください。';

  @override
  String get qrcCameraUnavailable => 'カメラを利用できませんでした。';

  @override
  String get qrcShareFailed => '共有に失敗しました';

  @override
  String get qrcGenerateFailed => 'QRコードの生成に失敗しました';

  @override
  String get qrcShareButton => '共有';

  @override
  String get qrcCopyIdButton => 'IDをコピー';

  @override
  String get setPasscodeTile => 'パスコードロック';

  @override
  String get passcodeEnterTitle => 'パスコードを入力';

  @override
  String get passcodeConfirmCurrentTitle => '現在のパスコードを入力';

  @override
  String get passcodeWrong => 'パスコードが違います。もう一度入力してください';

  @override
  String passcodeWaitSeconds(int seconds) {
    return '続けて間違えたため、あと$seconds秒お待ちください';
  }

  @override
  String passcodeWaitMinutes(int minutes) {
    return '続けて間違えたため、あと$minutes分お待ちください';
  }

  @override
  String get passcodeExhausted => '続けて間違えたため、入力できません。「パスコードを忘れた場合」から解除してください';

  @override
  String get passcodeExhaustedConfirm => '続けて間違えたため、入力できません。起動時の画面の「パスコードを忘れた場合」から解除してください';

  @override
  String notificationSwitchedAccount(String name) {
    return '$nameに切り替えました';
  }

  @override
  String get transferPasswordContactSupport => 'お問い合わせ';

  @override
  String get passcodeForgot => 'パスコードを忘れた場合';

  @override
  String get passcodeSetupTitle => 'パスコードを設定';

  @override
  String get passcodeSetupNewTitle => '新しいパスコードを入力';

  @override
  String get passcodeSetupConfirmTitle => 'もう一度入力';

  @override
  String get passcodeMismatch => 'パスコードが一致しません。もう一度入力してください';

  @override
  String get passcodeSaveFailed => 'パスコードを設定できませんでした。もう一度お試しください';

  @override
  String get passcodeResetFailed => 'パスコードを解除できませんでした。もう一度お試しください';

  @override
  String get passcodeKeypadDelete => '削除';

  @override
  String get setProfileTile => 'プロフィール';

  @override
  String get setAccountDeletionTile => 'アカウント削除';

  @override
  String get setBlockListTitle => 'ブロックリスト';

  @override
  String get setContactTile => 'お問い合わせ';

  @override
  String get setPrivacyPolicyTile => 'プライバシーポリシー';

  @override
  String setAppVersion(String version, String buildNumber) {
    return 'バージョン $version ($buildNumber)';
  }

  @override
  String get setTermsOfServiceTile => '利用規約';

  @override
  String get setSectionThisAccount => 'このアカウント';

  @override
  String get setSectionAllAccounts => 'すべてのアカウント';

  @override
  String get setSectionAppInfo => 'アプリ情報';

  @override
  String get setLinkOpenFailed => '開けませんでした';

  @override
  String get setBlockListEmpty => 'ブロック中のアカウントはありません';

  @override
  String get setBlockListLoadError => 'ブロックリストの取得に失敗しました';

  @override
  String get setBlockListUnblockButton => 'ブロック解除';

  @override
  String get setBlockListUnblockConfirmTitle => 'ブロックを解除しますか？';

  @override
  String get setBlockListUnblockConfirmMessage => '解除しても、以前の友だち関係は元に戻りません。あらためて友だち追加が必要です。';

  @override
  String get setBlockListUnblockFailed => '解除に失敗しました。再度お試しください';

  @override
  String chaRequestSectionTitle(int count) {
    return '未確認のトークリクエスト（$count）';
  }

  @override
  String get commonBlockButton => 'ブロック';

  @override
  String get commonBlockConfirmTitle => 'このアカウントをブロックしますか？';

  @override
  String get commonBlockConfirmMessage => 'ブロックすると、このアカウントからのメッセージを受け取らなくなり、友だち関係も解除されます。ブロックはブロックリストから解除できます。';

  @override
  String get commonBlockFailed => 'ブロックに失敗しました。再度お試しください';

  @override
  String get setPhoneNumberTile => '電話番号';

  @override
  String get setNotificationTile => '通知';

  @override
  String get setNotificationMessagesTitle => '通知';

  @override
  String get setNotificationMessagesSubtitle => 'このアカウント宛てのメッセージを通知します';

  @override
  String get setNotificationReactionsTitle => 'リアクション';

  @override
  String get setNotificationReactionsSubtitle => '自分のメッセージへのリアクションを通知し、未読としても表示します';

  @override
  String get setNotificationDeviceOff => '端末の設定で、Ortoの通知がオフになっています。通知を受け取るには、端末の設定でオンにしてください。';

  @override
  String get setNotificationOpenDeviceSettings => '端末の設定を開く';

  @override
  String get setNotificationLoadError => '通知設定の取得に失敗しました';

  @override
  String get setNotificationUpdateFailed => '変更できませんでした。再度お試しください';

  @override
  String get setLogoutTile => 'ログアウト';

  @override
  String get setLogoutConfirmTitle => 'ログアウトしますか？';

  @override
  String get setLogoutConfirmMessage => 'この端末からログアウトします。もう一度使うには、SMS認証が必要です。';

  @override
  String get setLogoutFailed => 'ログアウトできませんでした。通信環境を確認して、もう一度お試しください';

  @override
  String get setLogoutDenied => 'サーバーに拒否されたため、ログアウトできませんでした';

  @override
  String get setWithdrawalTile => '退会';

  @override
  String get withdrawalTitle => '退会';

  @override
  String get withdrawalMessage =>
      '退会すると、この電話番号のすべてのアカウントが削除されます。\n相手には「退会済みアカウント」として表示されます。送ったメッセージは、相手のトーク履歴に残ります。消してほしいメッセージがある場合は、退会の前にお問い合わせください（退会の1年後からは、本人の確認ができず、ご依頼に応じられません）。\n同じ電話番号で再度ログインしても、以前のアカウントには戻せません。\n有料プランのサブスクリプションは退会しても解約されません。契約したストア（App Store・Google Play）で解約してください。';

  @override
  String get withdrawalAcknowledge => 'すべてのアカウントが削除され、元に戻せないことを理解しました';

  @override
  String get withdrawalSlideLabel => 'スライドして退会';

  @override
  String get withdrawalSubmitButton => '退会する';

  @override
  String get withdrawalFailed => '退会できませんでした。通信環境を確認して、もう一度お試しください';

  @override
  String get phoneChangeTitle => '電話番号の変更';

  @override
  String get phoneChangeDescription => '新しい電話番号を入力してください。\nSMSで届く認証コードで確認します。\nアカウント・トーク・友だちはそのまま引き継がれます。';

  @override
  String get phoneChangeCompleted => '電話番号を変更しました';

  @override
  String get authErrorPhoneNumberInUse => 'この電話番号は、すでに別のユーザーで使われています';

  @override
  String get authErrorSamePhoneNumber => '現在と同じ電話番号です';

  @override
  String get authErrorUnsupportedRegion => 'この国・地域の電話番号には対応していません';

  @override
  String get authCountrySelectLabel => '国・地域を選択';

  @override
  String get setTransferPasswordTile => '引き継ぎパスワード';

  @override
  String get setTransferPasswordRegistered => '設定済み';

  @override
  String get setTransferPasswordNotRegistered => '未設定';

  @override
  String get transferPasswordSetupTitle => '引き継ぎパスワード';

  @override
  String get transferPasswordSetupDescription =>
      '新しい端末でログインするときに、SMSの認証コードに加えてこのパスワードの入力を求めます。\n電話番号を解約して別の人の手に渡っても、あなたのアカウントを見られないようにするためのものです。\n忘れると、新しい端末ではアカウントを引き継げません。';

  @override
  String get transferPasswordFieldLabel => 'パスワード（8〜64文字）';

  @override
  String get transferPasswordConfirmFieldLabel => 'パスワード（確認）';

  @override
  String get transferPasswordFieldHint => 'パスワードを入力';

  @override
  String get transferPasswordConfirmFieldHint => 'もう一度入力';

  @override
  String get transferPasswordMismatch => 'パスワードが一致しません';

  @override
  String get transferPasswordSaveButton => '保存する';

  @override
  String get transferPasswordPromptTitle => '引き継ぎパスワードを設定しませんか';

  @override
  String get transferPasswordPromptMessage => '電話番号が別の人に渡っても、あなたのアカウントを見られないようにできます。\n忘れると、新しい端末で引き継げません。';

  @override
  String get transferPasswordPromptSetUp => '設定する';

  @override
  String get transferPasswordPromptLater => 'あとで設定する';

  @override
  String get transferPasswordSaved => '引き継ぎパスワードを設定しました';

  @override
  String get transferPasswordEntryTitle => '引き継ぎパスワードの確認';

  @override
  String get transferPasswordEntryDescription => 'この電話番号には引き継ぎパスワードが設定されています。\n新しい端末で使うには、パスワードを入力してください。';

  @override
  String get transferPasswordEntryButton => '確認';

  @override
  String get transferPasswordForgot => 'パスワードを忘れた場合';

  @override
  String get transferPasswordForgotTitle => 'パスワードを忘れた場合';

  @override
  String get transferPasswordForgotMessage =>
      '引き継ぎパスワードは再発行できません。以前の端末でログインしている場合は、そちらの設定画面からパスワードを設定し直してください。\n以前の端末が使えない場合は、以前のデータ（すべてのアカウント）を削除して、この電話番号で始め直せます。削除は申請から7日後に行い、その間は以前の端末から取り消せます。';

  @override
  String get transferResetStart => 'データを削除して始め直す';

  @override
  String get transferResetConfirmTitle => '以前のデータを削除しますか？';

  @override
  String get transferResetConfirmMessage =>
      '申請から7日後に、この電話番号のすべてのアカウントを、退会と同じく削除します。元に戻せません。\n7日後以降にもう一度ログインすると、新しく始められます。\n以前の端末でログインしている場合は、そちらに知らせが届き、取り消せます。';

  @override
  String get transferResetConfirmButton => '申請する';

  @override
  String transferResetPending(String date) {
    return '$date以降に、以前のデータを削除します。その後、もう一度ログインすると、新しく始められます。';
  }

  @override
  String get transferResetCancel => '申請を取り消す';

  @override
  String get transferResetFailed => '申請できませんでした。通信環境を確認して、もう一度お試しください';

  @override
  String get transferResetAlertTitle => 'データの削除の申請があります';

  @override
  String transferResetAlertMessage(String date) {
    return '新しい端末から、引き継ぎパスワードを忘れたとして、この電話番号のデータの削除が申請されました。$dateに、すべてのアカウントが削除されます。\n心当たりがなければ、取り消してください。';
  }

  @override
  String get transferResetAlertCancel => '取り消す';

  @override
  String get transferResetAlertLater => '閉じる';

  @override
  String get transferResetCanceled => '申請を取り消しました';

  @override
  String get legalUpdateTitle => '利用規約とプライバシーポリシーを改定しました';

  @override
  String get legalUpdateMessage => '改定後の内容をご確認のうえ、「同意する」を押してください。';

  @override
  String get legalUpdateAgree => '同意する';

  @override
  String get legalUpdateFailed => '記録できませんでした。通信環境を確認して、もう一度お試しください';

  @override
  String get transferPasswordBackToPhoneInput => '電話番号の入力に戻る';

  @override
  String get transferPasswordErrorWrong => 'パスワードが違います';

  @override
  String get transferPasswordErrorLocked => '続けて間違えたため、しばらくしてからお試しください';

  @override
  String get transferPasswordErrorInvalid => 'パスワードは8〜64文字で入力してください';

  @override
  String get transferPasswordErrorNetwork => '通信に失敗しました。通信環境を確認して、もう一度お試しください';

  @override
  String get chaListReactionPreview => 'リアクションされました';

  @override
  String get chaImagePreviewLabel => '画像';

  @override
  String get chaImageButtonTooltip => '画像を送る';

  @override
  String get chaImageSendButton => '送信';

  @override
  String get chaImagePreparing => '画像を準備しています…';

  @override
  String get chaImageSendFailed => '画像を送信できませんでした。もう一度お試しください';

  @override
  String get chaImageTooLarge => '画像が大きすぎるため送信できません（10MBまで）';

  @override
  String get chaImageLoadFailed => '画像を読み込めませんでした';

  @override
  String get chaImageSaveTooltip => '保存';

  @override
  String get chaImageSaved => '画像を保存しました';

  @override
  String get chaImageSaveFailed => '画像を保存できませんでした';

  @override
  String get chaImageSaveDenied => '写真へのアクセスが許可されていません。端末の設定アプリから写真へのアクセスを許可してください。';

  @override
  String get chaImageMine => '自分';

  @override
  String get commonReportButton => '通報';

  @override
  String get repTitle => '通報';

  @override
  String get repDescription => '通報の理由を選んでください。\n通報したことは相手に通知されません。';

  @override
  String get repReasonLabel => '理由';

  @override
  String get repReasonSpam => 'スパム・宣伝';

  @override
  String get repReasonHarassment => '嫌がらせ・いじめ';

  @override
  String get repReasonImpersonation => 'なりすまし';

  @override
  String get repReasonInappropriate => '不適切なコンテンツ';

  @override
  String get repReasonOther => 'その他';

  @override
  String get repDetailLabel => '詳しい内容（任意）';

  @override
  String get repDetailHint => 'どのような問題があったか';

  @override
  String get repAlsoBlock => 'この相手をブロックする';

  @override
  String get repSubmitButton => '通報する';

  @override
  String get repDone => '通報しました';

  @override
  String get repDoneAndBlocked => '通報し、ブロックしました';

  @override
  String get repBlockFailed => '通報しましたが、ブロックできませんでした';

  @override
  String get repFailed => '通報できませんでした。もう一度お試しください';

  @override
  String get appUpdateTitle => 'アップデートが必要です';

  @override
  String get appUpdateMessage => '新しいバージョンのアプリをインストールしてください';

  @override
  String get appUpdateButton => 'アップデート';

  @override
  String get chaUnsupportedMessage => 'アプリを更新すると表示できます';

  @override
  String get chaSendButtonTooltip => '送信';

  @override
  String get chaStickerButtonTooltip => 'スタンプ';

  @override
  String get chaStickerPreviewLabel => 'スタンプ';

  @override
  String get chaStickerUnavailable => 'スタンプを表示できません';

  @override
  String get proMemoAdd => 'メモを追加';

  @override
  String get proMemoSheetTitle => 'メモ';

  @override
  String get proMemoHint => '自分だけに見えるメモを入力';

  @override
  String get proMemoEdit => 'メモを編集';

  @override
  String get proMemoPrivate => '自分だけに表示されます';

  @override
  String get proMemoPinned => 'ピン留め中';

  @override
  String get proMemoPin => 'トークにピン留め';

  @override
  String get proMemoSaveFailed => 'メモの保存に失敗しました。再度お試しください';

  @override
  String get planTitle => 'プラン';

  @override
  String get planNameFree => '無料';

  @override
  String get planNameGrade1 => 'グレード1';

  @override
  String get planNameGrade2 => 'グレード2';

  @override
  String get planNameAdmin => '運営者';

  @override
  String planCurrent(String plan) {
    return '現在のプラン：$plan';
  }

  @override
  String planAccountCount(int count, int limit) {
    return 'アカウント $count / $limit';
  }

  @override
  String planAccountCountUnlimited(int count) {
    return 'アカウント $count';
  }

  @override
  String planExtraAccounts(int count) {
    return '＋$countアカウント';
  }

  @override
  String planTotalAccounts(int count) {
    return '合計$countアカウントまで';
  }

  @override
  String planPricePerMonth(String price) {
    return '$price／月';
  }

  @override
  String get planBuyButton => '購入する';

  @override
  String get planChangeButton => 'このプランに変更';

  @override
  String get planCurrentBadge => '利用中';

  @override
  String get planRestoreButton => '購入を復元';

  @override
  String planManageButton(String store) {
    return '解約・プラン変更（$store）';
  }

  @override
  String planOtherStoreNotice(String store) {
    return 'このプランは$storeで契約しています。変更・解約は$storeで行ってください。';
  }

  @override
  String planAutoRenewNotice(String account, String store) {
    return '月額の自動更新のサブスクリプションです。お支払いは$accountに請求されます。期間が終わる24時間前までに解約しない限り、自動で更新されます。解約は$storeのサブスクリプションの設定からできます。解約した後、アカウント数がプランの上限を超えていると、上限を超えた分のアカウントが読み取り専用になります。';
  }

  @override
  String get planBillingAccountGoogle => 'Googleアカウント';

  @override
  String get planStoreUnavailable => '現在、この端末では購入できません。';

  @override
  String get planLoadError => 'プランを読み込めませんでした';

  @override
  String get planPurchaseApplied => 'プランを反映しました';

  @override
  String get planPurchasePending => '購入の承認を待っています';

  @override
  String get planPurchaseFailed => '購入を反映できませんでした。時間をおいて「購入を復元」をお試しください';

  @override
  String get planNothingToRestore => '復元できる購入はありません';

  @override
  String planCurrentScheduled(String plan, String date, String next) {
    return '現在のプラン：$plan（$dateから$next）';
  }

  @override
  String get planScheduledNotice => '変更日までは今のプランのまま使えます。取り消すときは「解約・プラン変更」から操作してください。';

  @override
  String get planScheduledBadge => '変更予約済み';

  @override
  String get planChangeScheduled => 'プランの変更を予約しました。次回の更新日から切り替わります';

  @override
  String get planPurchaseAlreadyOwned => 'このプランは契約中か、変更を予約済みです。別の番号で契約した場合は「購入を復元」で引き継げます';

  @override
  String get planTransferButton => '契約を引き継ぐ';

  @override
  String planTransferNotice(String account, String plan) {
    return 'この$accountに$planの契約があります。引き継ぐと、このログインで使えます。ほかのログインで使っている場合、そちらは無料プランに戻ります。';
  }

  @override
  String get planTokushohoLink => '特定商取引法に基づく表記';

  @override
  String get planReadOnlyNotice => 'プランの上限を超えた分のアカウントのため、読み取り専用です';

  @override
  String get planReadOnlyExplanation =>
      'アカウント数がプランの上限を超えているため、使い続けるアカウント以外は読み取り専用です。プランを変更するか、アカウントを削除して上限内にすると元に戻ります。';

  @override
  String get planLimitReachedUpgrade => 'アカウント数が上限に達しました。プランを変更すると増やせます。';

  @override
  String get planLimitReachedTopPlan => 'アカウント数が上限に達しました。これ以上は増やせません。';

  @override
  String get planKeptAccountsButton => '使い続けるアカウントを選ぶ';

  @override
  String get keptAccountsTitle => '使い続けるアカウント';

  @override
  String keptAccountsDescription(int limit) {
    return '使い続けるアカウントを$limit件選んでください。選ばなかったアカウントは読み取り専用になります。変更できるのは、プランが変わるごとに1回だけです。';
  }

  @override
  String get keptAccountsConfirmButton => '決定';

  @override
  String get keptAccountsConfirmTitle => 'このアカウントに決めますか？';

  @override
  String get keptAccountsConfirmMessage => '決めた後は、次にプランが変わるまで変更できません。';

  @override
  String get keptAccountsSaved => '使い続けるアカウントを決めました';

  @override
  String get keptAccountsSaveFailed => '保存できませんでした。時間をおいてお試しください';

  @override
  String get keptAccountsPromptTitle => 'アカウント数がプランの上限を超えています';

  @override
  String get keptAccountsPromptMessage => '上限の数までのアカウントは使い続けられ、ほかのアカウントは読み取り専用です。使い続けるアカウントは、1回変更できます。';

  @override
  String get keptAccountsPromptChoose => '選ぶ';

  @override
  String get planSeePlansButton => 'プランを見る';

  @override
  String get grpSelectFriendsTitle => '友だちを選択';

  @override
  String get grpNext => '次へ';

  @override
  String get grpSearchHint => '名前で検索';

  @override
  String get grpCreateAction => '作成';

  @override
  String get grpNameLabel => 'グループ名';

  @override
  String get grpNameHint => 'グループ名を入力';

  @override
  String get grpPolicyLabel => '友だちの招待の方式';

  @override
  String get grpPolicyApproval => '承認制';

  @override
  String get grpPolicyApprovalDescription => '招待された人が「参加」または「拒否」を選べます';

  @override
  String get grpPolicyAuto => '自動参加';

  @override
  String get grpPolicyAutoDescription => '友だちどうしなら招待されると自動で参加します';

  @override
  String get grpPolicyFixedNote => '方式は作成後に変更できません';

  @override
  String get grpCreateFailed => 'グループを作成できませんでした';

  @override
  String get grpListEmpty => '参加中のグループはありません';

  @override
  String grpRequestSectionTitle(int count) {
    return 'グループへの招待（$count）';
  }

  @override
  String grpRequestInvitedBy(String name) {
    return '$nameからの招待';
  }

  @override
  String get grpRequestJoin => '参加';

  @override
  String get grpRequestDecline => '拒否';

  @override
  String get grpRequestFailed => '操作に失敗しました';

  @override
  String grpTitleWithCount(String name, int count) {
    return '$name（$count）';
  }

  @override
  String grpPreviewWithSender(String name, String text) {
    return '$name: $text';
  }

  @override
  String get grpMeetupStatusLate => '遅れます';

  @override
  String get grpMeetupStatusArrived => '着きました';

  @override
  String get grpMeetupStatusNotFound => '見つかりません';

  @override
  String get grpErrorReadOnly => '読み取り専用の間はグループを利用できません';

  @override
  String get grpErrorGroupFull => 'グループの人数が上限に達しています';

  @override
  String get grpErrorJoinLimit => '参加できるグループ数の上限に達しています';

  @override
  String get grpErrorCreateLimit => '作成できるグループ数の上限に達しています';

  @override
  String get grpErrorMembersExceeded => '参加できる人数の上限を超えています';

  @override
  String get grpErrorGroupDeleted => 'このグループはなくなりました';

  @override
  String get grpErrorInviteInvalid => 'この招待リンクは無効です';

  @override
  String grpSysCreated(String actor, String group) {
    return '$actorがグループ「$group」を作成しました';
  }

  @override
  String grpSysJoined(String name) {
    return '$nameが参加しました';
  }

  @override
  String grpSysLeft(String name) {
    return '$nameが退会しました';
  }

  @override
  String grpSysRemoved(String actor, String target) {
    return '$actorが$targetを退会させました';
  }

  @override
  String grpSysRenamed(String actor, String group) {
    return '$actorがグループ名を「$group」に変更しました';
  }

  @override
  String grpSysPhotoChanged(String actor) {
    return '$actorがグループの画像を変更しました';
  }

  @override
  String grpSysInviteReissued(String actor) {
    return '$actorが招待リンクを再発行しました';
  }

  @override
  String get grpInfoTitle => 'グループ情報';

  @override
  String get grpNotifications => '通知';

  @override
  String get grpMembersLoadError => 'メンバーを取得できませんでした';

  @override
  String grpMemberMe(String name) {
    return '$name（自分）';
  }

  @override
  String get grpRemoveMember => '退会させる';

  @override
  String grpRemoveConfirmMessage(String name) {
    return '$nameをこのグループから退会させますか？';
  }

  @override
  String get grpLeave => 'グループを退会';

  @override
  String get grpLeaveAction => '退会';

  @override
  String get grpLeaveConfirmTitle => 'グループを退会しますか？';

  @override
  String get grpLeaveConfirmMessage => 'トーク履歴は読めなくなります。再参加しても読めません。';

  @override
  String get grpReportGroup => 'このグループを通報';

  @override
  String get grpLeftNotice => 'このグループから退会しました';

  @override
  String grpReadCount(int count) {
    return '既読 $count';
  }

  @override
  String get repGroupDescription => 'このグループを通報します。\n通報の理由を選んでください。';

  @override
  String get pushGroupInviteBanner => 'グループに招待されました';

  @override
  String get grpInvite => '招待';

  @override
  String get grpInviteFromFriends => '友だちから選ぶ';

  @override
  String get grpInviteQrShare => 'QRコードを共有';

  @override
  String get grpInviteLinkCopy => 'リンクをコピー';

  @override
  String get grpInviteLinkShare => '招待リンクを送る';

  @override
  String get grpInviteReissue => 'リンクとQRコードを再発行';

  @override
  String get grpInviteReissueAction => '再発行';

  @override
  String get grpInviteReissueMessage => '今のリンクとQRコードは使えなくなります';

  @override
  String get grpInviteNote => 'リンクを知っている人は誰でも参加できます';

  @override
  String grpInviteShareMessage(String groupName, String link) {
    return 'Ortoのグループ「$groupName」に招待されています。\n下のリンクを開くと、グループの内容を確かめて参加に進めます。Ortoは、電話番号やLINEを相手に教えずにやりとりできるアプリです。\n$link';
  }

  @override
  String grpInviteQrShareMessage(String groupName) {
    return 'Ortoのグループ「$groupName」の招待のQRコードです。スマートフォンのカメラで読み取ると、グループの内容を確かめて参加に進めます。';
  }

  @override
  String get grpInviteAction => '招待';

  @override
  String get grpInvited => '招待しました';

  @override
  String get grpJoinedLabel => '参加中';

  @override
  String get grpMaxMembers => '最大100人まで';

  @override
  String get grpJoinTitle => 'グループに参加';

  @override
  String grpJoinAccount(String name) {
    return '$nameで参加します';
  }

  @override
  String get albPreviewLabel => 'アルバム';

  @override
  String get albListTitle => 'アルバム';

  @override
  String get albEmpty => 'アルバムはまだありません';

  @override
  String get albLoadError => '読み込めませんでした';

  @override
  String get albCreateTitle => 'アルバムを作成';

  @override
  String get albNameHint => 'アルバム名';

  @override
  String get albCreateFailed => 'アルバムを作成できませんでした';

  @override
  String get albTooManyAlbums => 'このトークのアルバムは100件までです';

  @override
  String get albTooManyItems => '1つのアルバムに追加できるのは1000件までです';

  @override
  String get albNoItems => '画像や動画はありません';

  @override
  String get albDeleted => '削除されたアルバム';

  @override
  String get albSelect => '選択';

  @override
  String get albRenameTitle => '名前を変更';

  @override
  String get albDeleteTitle => 'アルバムを削除';

  @override
  String get albDeleteMessage => 'アルバムの中の画像と動画もすべて削除され、元に戻せません';

  @override
  String get albDeleteConfirm => '削除';

  @override
  String get albDeleteItemsTitle => '項目を削除';

  @override
  String get albDeleteOnlyMine => '削除できるのは自分が追加した項目だけです';

  @override
  String get albUpdateFailed => '操作できませんでした。もう一度お試しください';

  @override
  String get albSaved => '保存しました';

  @override
  String get albSaveFailed => '保存できませんでした';

  @override
  String get albVideoTooLong => '5分を超える動画は追加できません';

  @override
  String get albFileTooLarge => 'ファイルが大きすぎます';

  @override
  String get albUnsupported => 'この形式には対応していません';

  @override
  String get albRejected => '上限に達したか、今は追加できません';

  @override
  String get albAddFailed => '通信状況をご確認ください';

  @override
  String get albRetry => '再試行';

  @override
  String get albVideoLoadFailed => '動画を再生できませんでした';

  @override
  String albUploading(int current, int total) {
    return '追加中（$current/$total）';
  }

  @override
  String albItemCount(int count) {
    return '$count件';
  }

  @override
  String albSelectedCount(int count) {
    return '$count件を選択';
  }

  @override
  String albDeleteItemsMessage(int count) {
    return '$count件を削除します。元に戻せません';
  }

  @override
  String albDeleteMineMessage(int count) {
    return '自分が追加した$count件を削除します。他の人の項目は残ります';
  }

  @override
  String albFailedCount(int count) {
    return '$count件を追加できませんでした。';
  }

  @override
  String albNoticeCreated(int count) {
    return 'アルバムを作成し、$count件を追加しました';
  }

  @override
  String albNoticeAdded(int count) {
    return 'アルバムに$count件を追加しました';
  }

  @override
  String get authErrorAccountSuspended => 'このアカウントは利用を停止しています。お問い合わせ先にご連絡ください';

  @override
  String get accCreationBlocked => 'アカウントの削除を繰り返したため、しばらく新しいアカウントを作成できません';

  @override
  String get grpRequestMore => 'その他';

  @override
  String get grpRequestBlockInviter => '招待した人をブロック';

  @override
  String get accCreationInviterLabel => '招待してくれた人のアカウントID（任意）';

  @override
  String get accCreationInviterHint => '例：orto_friend';

  @override
  String get accCreationInviterNote => '入れると、作成の後にその人を友だち追加できます';

  @override
  String get invitePasteTitle => '招待リンクから来ましたか？';

  @override
  String get invitePasteMessage => '招待のページでコピーした招待を下のボタンで貼り付けると、ログインの後に、そのまま友だち追加やグループへの参加に進めます。';

  @override
  String get invitePasteNotInvite => '招待リンクではありませんでした';

  @override
  String get invitePasteReceivedTitle => '招待を受け取りました';

  @override
  String invitePasteReceivedFriend(String accountId) {
    return '招待したアカウントのID：$accountId\nログインとアカウントの作成の後に、友だち追加に進みます。';
  }

  @override
  String get invitePasteReceivedGroup => 'ログインとアカウントの作成の後に、グループへの参加に進みます。';

  @override
  String get invitePasteClose => '閉じる';

  @override
  String get inviteAccountTitleFriend => 'どのアカウントで友だち追加しますか？';

  @override
  String get inviteAccountTitleGroup => 'どのアカウントで参加しますか？';

  @override
  String get inviteAccountNote => '相手には、選んだアカウントだけが見えます';

  @override
  String inviteAccountId(String accountId) {
    return 'ID：$accountId';
  }

  @override
  String get inviteAccountCurrent => '使用中';

  @override
  String get inviteAccountReadOnly => '読み取り専用のため選べません';

  @override
  String inviteSwitchedAccount(String name) {
    return '$nameに切り替えました';
  }

  @override
  String proAddAs(String name) {
    return '$nameで追加します';
  }

  @override
  String grpInviteAs(String name) {
    return '$nameとして招待します';
  }

  @override
  String get friInviteAsTitle => 'このアカウントで招待します';

  @override
  String get friInviteSend => '招待文を送る';

  @override
  String get qrcMyQrAccountNote => 'このアカウントのQRコードです';

  @override
  String get grpKindTitle => 'グループの種類';

  @override
  String get grpKindStandard => '普通のグループ';

  @override
  String get grpKindStandardDescription => '友だちや仲間と話すグループです。全員が同じことをできます。';

  @override
  String get grpKindMeetup => 'オフ会グループ';

  @override
  String get grpKindMeetupDescription => 'オフ会やイベントのためのグループです。主催チームがメンバーの管理やお知らせをします。会が終わると閉じます。';

  @override
  String get grpKindFixedNote => '種類はあとから変えられません';

  @override
  String get grpMeetupBadge => 'オフ会';

  @override
  String get grpMeetupDateUndecided => '日時未定';

  @override
  String grpMeetupDaysLeft(int count) {
    return 'あと$count日';
  }

  @override
  String get grpMeetupClosed => '終了';

  @override
  String get grpMeetupClosedNotice => 'このグループは閉じました';

  @override
  String grpMeetupClosedNoticeWithDate(String date) {
    return 'このグループは閉じました。$dateに記録が消えます';
  }

  @override
  String get grpCloseDayTitle => 'グループを閉じる日';

  @override
  String get grpCloseDayNextDay => '翌日';

  @override
  String get grpCloseDay3Days => '3日後';

  @override
  String get grpCloseDayWeek => '1週間後';

  @override
  String grpCloseDayN(int count) {
    return '会の$count日後';
  }

  @override
  String get grpCloseDayNote => '会の日時から数えて閉じます。会のあとは、会の日から2週間まで延ばせます。閉じる24時間前と1時間前にメンバーに知らせます';

  @override
  String get grpErrorGroupClosed => 'このグループは閉じています';

  @override
  String get grpErrorInvalidCloseDays => '1時間より後になる日を選んでください';

  @override
  String grpSysCloseUpdated(String name) {
    return '$nameがグループを閉じる日時を変更しました';
  }

  @override
  String get grpSysClosingSoon24h => 'このグループは24時間以内に閉じます';

  @override
  String get grpSysClosingSoon1h => 'このグループは1時間以内に閉じます';

  @override
  String get grpSysClosed => 'グループは閉じました';

  @override
  String pushGroupClosing24hBanner(String name) {
    return '$nameは24時間以内に閉じます';
  }

  @override
  String pushGroupClosing1hBanner(String name) {
    return '$nameは1時間以内に閉じます';
  }

  @override
  String get grpOrganizerTeamHeading => '主催チーム';

  @override
  String get grpMembersHeading => 'メンバー';

  @override
  String get grpOrganizerBadge => '主催';

  @override
  String get grpOrganizerInvitedLabel => '主催に誘い中';

  @override
  String get grpInviteToOrganizers => '主催チームに入れる';

  @override
  String get grpRemoveFromOrganizers => '主催チームから外す';

  @override
  String grpRemoveFromOrganizersConfirm(String name) {
    return '$nameを主催チームから外しますか？';
  }

  @override
  String get grpLeaveOrganizers => '主催チームから抜ける';

  @override
  String get grpLeaveOrganizersConfirm => '主催チームから抜けますか？';

  @override
  String grpOrganizerInviteCard(String name) {
    return '$nameから、主催チームに誘われています';
  }

  @override
  String get grpOrganizerInviteAccept => '入る';

  @override
  String get grpOrganizerInviteDecline => '断る';

  @override
  String get grpErrorLastOrganizer => '主催チームがあなただけのため抜けられません。先にほかのメンバーを主催チームに入れてください。';

  @override
  String grpSysOrganizerAdded(String name) {
    return '$nameが主催チームに入りました';
  }

  @override
  String grpSysOrganizerRemoved(String name) {
    return '$nameが主催チームから外れました';
  }

  @override
  String get pushOrganizerInviteBanner => '主催チームに誘われています';

  @override
  String grpPersonName(String name) {
    return '$nameさん';
  }

  @override
  String get grpApplyJoin => '参加を申請';

  @override
  String get grpApplyNote => '主催チームが承認すると参加できます。答えは主催チームの人だけが見ます。';

  @override
  String get grpApplyAnswerHint => '答えを入力';

  @override
  String get grpApplyPending => '参加を申請しました。主催チームが承認すると、通知でお知らせします。';

  @override
  String get grpApplyWaitlisted => 'キャンセル待ちになりました。空きが出たら、申請した順に主催チームが承認します。';

  @override
  String grpApplyDeclined(String name) {
    return '$nameへの参加は承認されませんでした';
  }

  @override
  String grpApplyClosed(String name) {
    return '$nameに参加できませんでした';
  }

  @override
  String get grpApplyAgain => 'もう一度申請する';

  @override
  String get grpApplyCancel => '申請を取り消す';

  @override
  String get grpApplyCancelConfirmTitle => '申請を取り消しますか？';

  @override
  String get grpApplyCancelConfirmMessage => '取り消すと、答えも消えます。';

  @override
  String get grpApplyCancelConfirm => '取り消す';

  @override
  String grpApplicationSectionTitle(int count) {
    return '参加の申請（$count）';
  }

  @override
  String get grpApplicationPending => '承認待ち';

  @override
  String get grpApplicationWaitlisted => 'キャンセル待ち';

  @override
  String get grpApplicationDeclined => '承認されませんでした';

  @override
  String get grpApplicationClosed => '参加できませんでした';

  @override
  String grpJoinRequestBanner(int count) {
    return '参加の申請 $count件';
  }

  @override
  String get grpJoinRequestsMenu => '参加の申請';

  @override
  String get grpJoinQuestionsMenu => '参加時の質問';

  @override
  String grpJoinQuestionsCount(int count) {
    return '$count問';
  }

  @override
  String get grpJoinQuestionsNone => 'なし';

  @override
  String get grpJoinRequestsTitle => '参加の申請';

  @override
  String grpJoinRequestsPendingHeading(int count) {
    return '承認待ち（$count）';
  }

  @override
  String grpJoinRequestsWaitlistHeading(int count) {
    return 'キャンセル待ち（$count）';
  }

  @override
  String grpJoinRequestsWaitlistOrder(int order) {
    return '$order番目';
  }

  @override
  String get grpJoinRequestsEmpty => '届いている申請はありません';

  @override
  String get grpJoinRequestsNoQuestions => '質問なし';

  @override
  String get grpJoinRequestsLoadError => '申請を読み込めませんでした';

  @override
  String get grpJoinRequestApprove => '承認';

  @override
  String get grpJoinRequestDecline => '断る';

  @override
  String grpJoinRequestDeclineTitle(String name) {
    return '$nameの申請を断りますか？';
  }

  @override
  String grpJoinRequestDeclineMessage(String group) {
    return '相手には「$groupへの参加は承認されませんでした」とだけ知らせます。';
  }

  @override
  String get grpJoinRequestApproved => '承認しました';

  @override
  String get grpJoinRequestWaitlisted => '満員のため、キャンセル待ちに回しました';

  @override
  String get grpErrorApplicantUnavailable => 'この人は今は参加できません。時間をおいてお試しください';

  @override
  String get grpErrorInvalidAnswers => '質問が変わったため申請できませんでした。開き直してください';

  @override
  String get grpJoinQuestionsTitle => '参加時の質問';

  @override
  String get grpJoinQuestionsDescription => '招待リンクから参加を申請する人に答えてもらう質問です。3問まで決められます。答えは主催チームの人だけが見ます。';

  @override
  String grpJoinQuestionsLabel(int number) {
    return '質問$number';
  }

  @override
  String get grpJoinQuestionsExample => '例：Xの@IDを教えてください';

  @override
  String get grpJoinQuestionsAdd => '質問を追加';

  @override
  String get grpJoinQuestionsRemove => '質問を削除';

  @override
  String get grpJoinQuestionsNote => '質問を変えても、届いている申請の質問と答えはそのままです';

  @override
  String get grpJoinQuestionsSaved => '保存しました';

  @override
  String get grpJoinQuestionsDiscardTitle => '変更を破棄しますか？';

  @override
  String get grpJoinQuestionsDiscard => '破棄';

  @override
  String get grpInviteMeetupNote => 'リンクから来た人は、主催チームが承認すると参加できます';

  @override
  String get pushJoinRequestBanner => '参加の申請が届きました';

  @override
  String pushJoinApprovedBanner(String name) {
    return '$nameへの参加が承認されました';
  }

  @override
  String pushJoinWaitlistedBanner(String name) {
    return '$nameのキャンセル待ちになりました';
  }

  @override
  String get grpMemberJoinAnswersNote => '参加の申請のときの答え（主催チームだけが見られます）';

  @override
  String get grpMemberJoinAnswersProfile => 'プロフィールを見る';

  @override
  String get frqSendButton => '友だち申請';

  @override
  String frqSendAs(String name) {
    return '$nameで申請します';
  }

  @override
  String get frqPending => '申請中';

  @override
  String get frqAcceptButton => '承認する';

  @override
  String get frqReceivedNotice => '友だち申請が届いています';

  @override
  String get frqSent => '友だち申請を送りました';

  @override
  String frqAccepted(String name) {
    return '$nameと友だちになりました';
  }

  @override
  String get frqSendFailed => '申請に失敗しました。再度お試しください';

  @override
  String get frqNotMember => '申請できませんでした。相手がグループを抜けた可能性があります';

  @override
  String get frqRespondFailed => '操作に失敗しました。再度お試しください';

  @override
  String get frqInvalid => 'この申請は無効になっています';

  @override
  String frqSectionTitle(int count) {
    return '友だち申請 $count件';
  }

  @override
  String frqFromGroup(String groupName) {
    return '「$groupName」から';
  }

  @override
  String get frqAccept => '承認';

  @override
  String get frqDecline => '断る';

  @override
  String get frqDeclineTitle => '友だち申請を断りますか？';

  @override
  String get frqDeclineMessage => '断ったことは相手に知らされません。';

  @override
  String get frqMore => 'その他';

  @override
  String get pushFriendRequestBanner => '友だち申請が届きました';

  @override
  String grpSysAnnouncementPosted(String name) {
    return '$nameがお知らせを追加しました';
  }

  @override
  String grpSysEventUpdated(String name) {
    return '$nameが会の日時・場所を更新しました';
  }

  @override
  String get annPlaceUndecided => '場所未定';

  @override
  String annCollapsed(int count) {
    return 'お知らせ $count件';
  }

  @override
  String get annAdd => 'お知らせを追加';

  @override
  String get annEditTitle => 'お知らせを編集';

  @override
  String get annPost => '投稿';

  @override
  String get annEdit => '編集';

  @override
  String get annTextHint => '集合場所・時刻・持ち物など';

  @override
  String get annPlaceHint => '店名か住所（任意）';

  @override
  String get annPlaceNote => '入れると、押したときに地図アプリで検索して開きます';

  @override
  String get annNotifyMembers => 'メンバーに通知する';

  @override
  String annUpdatedAt(String time) {
    return '$time更新';
  }

  @override
  String get annDeleteConfirm => 'このお知らせを削除しますか？';

  @override
  String get annErrorLimit => 'お知らせは20件までです。古いお知らせを削除してから追加してください。';

  @override
  String get annErrorNotFound => 'このお知らせは削除されています';

  @override
  String get annMakeFromMessage => 'お知らせにする';

  @override
  String get annEventTitle => '会の日時と場所';

  @override
  String get annEventEdit => '会の日時と場所を編集';

  @override
  String get annEventDate => '日時';

  @override
  String get annEventDateUnset => '未定';

  @override
  String get annEventNote => '会の日時は、決めたあとは変えられますが、未定には戻せません';

  @override
  String get annErrorEventPast => '今より後の日時を選んでください';

  @override
  String get annOpenAppleMaps => 'Apple マップで開く';

  @override
  String get annOpenGoogleMaps => 'Google マップで開く';

  @override
  String get annCopyPlace => '場所をコピー';

  @override
  String get annMapOpenFailed => '地図アプリを開けませんでした';

  @override
  String get pushAnnouncementBanner => 'お知らせがあります';

  @override
  String get annDeleteConfirmMessage => 'メンバー全員の画面から消えます。';

  @override
  String get attTitle => '出欠';

  @override
  String get attYes => '参加';

  @override
  String get attNo => '不参加';

  @override
  String attSummary(int yes, int no, int unanswered) {
    return '参加 $yes・不参加 $no・未回答 $unanswered';
  }

  @override
  String attDeadlineAt(String date) {
    return '締切 $date';
  }

  @override
  String get attDeadlinePassed => '締切済み';

  @override
  String get attMyResponse => 'あなたの出欠';

  @override
  String get attDeadlineLabel => '締切';

  @override
  String get attDeadlineNone => 'なし';

  @override
  String get attDeadlineClear => '締切なしにする';

  @override
  String get attNote => '締切を過ぎても答えを変えられます。';

  @override
  String get attNoteAuto => '締切の24時間前に、未回答の人へ自動で通知します。';

  @override
  String get attRemind => '未回答の人に催促する';

  @override
  String attRemindConfirm(int count) {
    return '未回答の$count人に通知を送りますか？';
  }

  @override
  String get attRemindConfirmMessage => '6時間に1回まで送れます。';

  @override
  String get attRemindSend => '送る';

  @override
  String attReminded(int count) {
    return '$count人に通知しました';
  }

  @override
  String get attDeadlineUpdated => '締切を更新しました';

  @override
  String attSectionYes(int count) {
    return '参加（$count）';
  }

  @override
  String attSectionNo(int count) {
    return '不参加（$count）';
  }

  @override
  String attSectionUnanswered(int count) {
    return '未回答（$count）';
  }

  @override
  String get attErrorDeadline => '締切は今より後で、会の日時までにしてください';

  @override
  String get attErrorReminderTooSoon => '催促は6時間に1回までです。時間をおいてお試しください';

  @override
  String grpSysAttendanceDeadlineUpdated(String name) {
    return '$nameが出欠の締切を更新しました';
  }

  @override
  String grpSysCapacityUpdated(String name) {
    return '$nameが定員を変更しました';
  }

  @override
  String get pushAttendanceReminderBanner => '出欠の回答をお願いします';

  @override
  String pushJoinPromotedBanner(String name) {
    return '$nameのキャンセル待ちから繰り上がりました';
  }

  @override
  String get pushWaitlistPromotedBanner => 'キャンセル待ちから繰り上がった人がいます';

  @override
  String get capTitle => '定員';

  @override
  String capValue(int count) {
    return '$count人';
  }

  @override
  String get capNone => 'なし';

  @override
  String get capDescription => '主催チームを含むメンバーの数で数えます。満員のあとの申請はキャンセル待ちになり、空きが出たら申請した順に繰り上がります。';

  @override
  String capBelowMembers(int count) {
    return '今のメンバーは$count人です。誰も退会にはなりませんが、空きが出るまで新しく入れません。';
  }

  @override
  String get capClear => '定員なし';

  @override
  String get capErrorRange => '定員は2〜100人にしてください';

  @override
  String capMemberCount(String name, int count, int capacity) {
    return '$name（$count/$capacity）';
  }

  @override
  String capPreview(int count) {
    return '定員 $count人';
  }

  @override
  String get capPreviewFull => '満員のため、申請するとキャンセル待ちになります';

  @override
  String get grpJoinRequestPromoted => '繰り上がり';

  @override
  String get stlTitle => '精算';

  @override
  String stlYen(String amount) {
    return '$amount円';
  }

  @override
  String get stlYenSuffix => '円';

  @override
  String get stlRowStart => '精算を始める';

  @override
  String stlRowMine(String amount, String status) {
    return '精算：$amount・$status';
  }

  @override
  String stlRowTotal(String amount) {
    return '精算：合計 $amount';
  }

  @override
  String get stlNotStarted => '精算はまだ始まっていません。';

  @override
  String get stlNotTarget => 'あなたは精算の対象ではありません。';

  @override
  String get stlStatusUnpaid => '未払い';

  @override
  String get stlStatusReported => '確認待ち';

  @override
  String get stlStatusConfirmed => '支払い済み';

  @override
  String get stlStatusFree => '支払いなし';

  @override
  String get stlTotalLabel => '合計';

  @override
  String stlRoundingValue(int unit) {
    return '$unit円単位で切り上げ';
  }

  @override
  String get stlMyShare => 'あなたの支払い';

  @override
  String stlTierLabel(String name, int percent) {
    return '$name（$percent%）';
  }

  @override
  String get stlReportPaid => '払った';

  @override
  String get stlReportCancel => '「払った」を取り消す';

  @override
  String get stlReportedNote => '主催チームの確認を待っています。';

  @override
  String get stlConfirmedNote => '主催チームが受け取りを確かめました。';

  @override
  String get stlMethodTitle => 'どうやって払いましたか？';

  @override
  String get stlMethodLink => '送金サービス';

  @override
  String get stlMethodCash => '現金';

  @override
  String get stlMethodOther => 'そのほか';

  @override
  String get stlLinksHeading => '送金先';

  @override
  String get stlLinksEmpty => '送金先はまだありません。払い方は主催チームに確かめてください。';

  @override
  String get stlLinkPayPay => 'PayPay';

  @override
  String stlLinkPayPayId(String id) {
    return 'PayPay ID：$id';
  }

  @override
  String stlLinkAddedBy(String name) {
    return '$nameが追加';
  }

  @override
  String get stlPayPayNote => 'PayPay で送ると、あなたの表示名が相手に見えます。受け取りリンクの期限は4日です。';

  @override
  String get stlInAppNote => 'Orto の中でお金は動きません。送金は各サービスで行ってください。';

  @override
  String get stlLinkAdd => '送金先を追加';

  @override
  String get stlLinkRemove => '外す';

  @override
  String get stlLinkRemoveConfirm => 'この送金先を外しますか？';

  @override
  String get stlLinkServicePayPayUrl => 'PayPay の受け取りリンク';

  @override
  String get stlLinkServicePayPayId => 'PayPay ID';

  @override
  String get stlLinkServiceOther => 'ほかのサービスのリンク';

  @override
  String get stlLinkLabelHint => 'サービスの名前（例：楽天ペイ）';

  @override
  String get stlLinkIdHint => 'PayPay ID';

  @override
  String get stlLinkInvalid => 'PayPay のリンク（paypay.ne.jp）、PayPay ID、または https で始まるリンクを入れてください';

  @override
  String get stlLinkAddNote => '自分の PayPay で作った受け取りリンクか、PayPay ID を貼ってください。PayPay の請求リンクは、作る人・払う人とも本人確認が要ります。';

  @override
  String get stlOrganizerHeading => '全員の支払い';

  @override
  String stlCollected(String amount) {
    return '集まる額 $amount';
  }

  @override
  String stlCollectedSurplus(String amount, String surplus) {
    return '集まる額 $amount（端数の切り上げで合計より $surplus 多い）';
  }

  @override
  String stlConfirmedSum(String amount) {
    return '受け取り済み $amount';
  }

  @override
  String stlSectionReported(int count) {
    return '確認待ち（$count）';
  }

  @override
  String stlSectionUnpaid(int count) {
    return '未払い（$count）';
  }

  @override
  String stlSectionConfirmed(int count) {
    return '支払い済み（$count）';
  }

  @override
  String stlSectionFree(int count) {
    return '支払いなし（$count）';
  }

  @override
  String get stlLeft => '退会';

  @override
  String stlShareSheetTitle(String name, String amount) {
    return '$name・$amount';
  }

  @override
  String get stlConfirm => '受け取りを確定';

  @override
  String stlConfirmWith(String method) {
    return '$methodで受け取り済みにする';
  }

  @override
  String get stlRevert => '未払いに戻す';

  @override
  String get stlRemind => '未払いの人に催促する';

  @override
  String stlRemindConfirm(int count) {
    return '未払いの$count人に通知を送りますか？';
  }

  @override
  String get stlAutoNote => 'グループが閉じる前（24時間前）にも、未払いの人へ自動で通知します。';

  @override
  String get stlEdit => '精算の設定を変える';

  @override
  String get stlDelete => '精算をやめる';

  @override
  String get stlDeleteConfirm => '精算をやめますか？';

  @override
  String get stlDeleteConfirmMessage => '全員の金額と払った記録が消えます。';

  @override
  String get stlEditTitle => '精算の設定';

  @override
  String get stlTotalHint => '合計の金額';

  @override
  String get stlErrorTotal => '1円〜1,000万円で入れてください';

  @override
  String get stlRoundingTitle => '端数';

  @override
  String stlRoundingOption(int unit) {
    return '$unit円';
  }

  @override
  String get stlRoundingNote => '一人ひとりの額をこの単位に切り上げます。合計より多く集まった分は主催チームで扱ってください。';

  @override
  String get stlTiersHeading => '区分（割合）';

  @override
  String get stlTiersNote => '区分ごとの割合で合計を分けます。例：通常 100%、飲まない 70%、主催 0%（無料）';

  @override
  String get stlTierDefaultName => '通常';

  @override
  String get stlTierAdd => '区分を追加';

  @override
  String get stlTierAdded => '区分を追加しました。対象の人の区分を選んでください';

  @override
  String get stlTierEditTitle => '区分';

  @override
  String get stlTierDelete => '区分を消す';

  @override
  String get stlTierNameHint => '名前（例：飲まない）';

  @override
  String get stlTierPercentHint => '割合';

  @override
  String get stlTierPercentNote => '0〜500%。100% が基準で、0% の人は払いません。';

  @override
  String stlPercent(int percent) {
    return '$percent%';
  }

  @override
  String stlTargetsHeading(int count) {
    return '精算の対象（$count人）';
  }

  @override
  String get stlTargetsNote => '初めは出欠で「参加」と答えた人が入っています。';

  @override
  String stlResetConfirm(int count) {
    return '$count人の払った記録が未払いに戻ります';
  }

  @override
  String get stlResetConfirmMessage => '払う額が変わるため、払った記録を消して未払いに戻します。保存しますか？';

  @override
  String get stlStarted => '精算を始めました';

  @override
  String get stlSaved => '精算の設定を保存しました';

  @override
  String get stlErrorInvalid => '入力を確かめてください';

  @override
  String get stlErrorNotFound => '精算は始まっていないか、やめられました';

  @override
  String get stlErrorNotTarget => '精算の対象ではありません';

  @override
  String get stlErrorPaymentConfirmed => '主催チームが確定したため取り消せません。主催チームに知らせてください';

  @override
  String get stlErrorLinkLimit => '送金先は5件までです';

  @override
  String grpSysSettlementStarted(String name) {
    return '$nameが精算を始めました';
  }

  @override
  String grpSysSettlementUpdated(String name) {
    return '$nameが精算の設定を変えました';
  }

  @override
  String grpSysSettlementDeleted(String name) {
    return '$nameが精算をやめました';
  }

  @override
  String get pushSettlementReminderBanner => '精算の支払いをお願いします';

  @override
  String get nxtMenu => '次の回を作る';

  @override
  String get nxtCreatedLabel => '作成済み';

  @override
  String get nxtTitle => '次の回を作る';

  @override
  String get nxtNameLabel => 'グループ名';

  @override
  String get nxtDescription => '前の回のメンバーに招待を送ります。招待を承諾した人だけが次の回に入ります。';

  @override
  String get nxtCarriedNote => 'グループの画像・参加時の質問・定員・閉じる日を引き継ぎます。会の日時・場所・お知らせ・出欠は引き継ぎません。';

  @override
  String get nxtOrganizerNote => '前の回の主催チームの人は、承諾すると主催チームにも入ります。';

  @override
  String nxtInviteHeading(int count) {
    return '招待する人（$count人）';
  }

  @override
  String get nxtNoMembers => '招待できる前の回のメンバーはいません';

  @override
  String get nxtSubmit => '作って招待を送る';

  @override
  String get nxtCreated => '次の回を作りました';

  @override
  String get nxtErrorExists => '次の回はすでに作られています';

  @override
  String get nxtErrorExpired => '記録が消えたため、次の回を作れません';

  @override
  String grpRequestNextRound(String previous, String name) {
    return '「$previous」の次の回・$nameからの招待';
  }
}
