# データ設計書

**複数アカウント切替メッセージアプリ（Orto）** 

- 対象プロジェクト：Orto
- 本書の位置付け：Firestoreのコレクション構造・フィールド定義・セキュリティルールを定義する
- バックエンド：Firebase（Authentication／Firestore／Cloud Functions／Cloud Messaging／Storage）

> **2026-10-01時点の注意**：他人にuidを見せないためのデータ構造の見直し、送信取消の論理削除、画像メッセージは実装済み。

---

## 目次

1. [設計方針](#1-設計方針)
2. [コレクション構成一覧](#2-コレクション構成一覧)
3. [各コレクション定義](#3-各コレクション定義)
  - [3.1 users](#31-users)
    - [3.1.1 users/{uid}/ownedAccounts](#311-usersuidownedaccounts)
    - [3.1.2 users/{uid}/sendCounters/current](#312-usersuidsendcounterscurrent)
    - [3.1.3 users/{uid}/legalConsents/{version}](#313-usersuidlegalconsentsversion)
  - [3.2 accounts](#32-accounts)
    - [3.2.1 accounts/{accountId}/friends](#321-accountsaccountidfriends)
    - [3.2.2 accounts/{accountId}/fcmTokens](#322-accountsaccountidfcmtokens)
    - [3.2.3 accounts/{accountId}/blockedAccounts](#323-accountsaccountidblockedaccounts)
    - [3.2.4 accounts/{accountId}/chatList](#324-accountsaccountidchatlist)
    - [3.2.5 accounts/{accountId}/friendRequests](#325-accountsaccountidfriendrequests)
    - [3.2.6 accounts/{accountId}/sentFriendRequests](#326-accountsaccountidsentfriendrequests)
  - [3.3 chatRooms](#33-chatrooms)
    - [3.3.1 chatRooms/{chatRoomId}/messages](#331-chatroomschatroomidmessages)
  - [3.4 unsentMessageArchives](#34-unsentmessagearchives)
  - [3.5 userSecrets](#35-usersecrets)
  - [3.6 reports](#36-reports)
  - [3.7 appConfig](#37-appconfig)
  - [3.8 billingCustomers](#38-billingcustomers)
  - [3.9 stickerPacks](#39-stickerpacks)
4. [ID設計](#4-id設計)
5. [インデックス設計](#5-インデックス設計)
6. [Firestoreセキュリティルール](#6-firestoreセキュリティルール)
7. [Storage設計](#7-storage設計)
8. [グループチャット](#8-グループチャット)

---



## 1. 設計方針

- **User と Account の分離**：
  - `users` は Firebase Authentication の uid（電話番号認証）に対応する認証主体、`accounts` はプロフィール単位のドキュメントとして分離する（要件定義書・機能仕様書の用語定義に準拠）。
- **用語「保有ユーザ」**：あるアカウントを保有しているユーザ（uid）のこと。`users/{uid}/ownedAccounts/{accountId}`（3.1.1）が存在する`users/{uid}`のユーザを指す。1人のユーザは複数のアカウントを保有できる。アカウント本体（`accounts/{accountId}`）は最上位に置くため、Firestoreのパス上はユーザの子ではない（保有の関係は`ownedAccounts`だけで表す）。
- **アカウントID（検索用ID）をドキュメントIDに採用**：アカウントIDは作成後変更不可（LINE仕様）のため、`accounts` のドキュメントIDそのものを検索用IDとする。ID検索が単純なドキュメント取得（O(1)）で完結し、一意性もドキュメントIDの制約で保証される。
- **友だち追加は片方向**：
  - **友だち追加したとき**、`friends` サブコレクションは追加した側のAccountのみに作成する（相手側には自動生成しない）。
- **チャットルームIDは決定的に生成**：2つのaccountIdを昇順ソートし`~`で連結したIDを`chatRooms`のドキュメントIDとし、同一ペアの重複ルーム作成を防ぐ。区切り文字はaccountIdに使えない文字にする（使える文字だと別のペアが同じIDになり得るため）。
- **他人にuidを見せない**：他人が読めるドキュメント（`accounts`・`chatRooms`・`messages`）には、uidなど「ユーザ単位で共通の値」を一切置かない（ハッシュ化した値も、同じ値が出る時点で同一人物の別アカウントを結び付けられるため不可）。他人から見えるのはaccountIdと公開プロフィールまで。
  - 保有ユーザの情報は、本人だけが読める`users/{uid}/ownedAccounts/{accountId}`（3.1.1）に置く。保有ユーザの判定は「`users/{自分のuid}/ownedAccounts/{accountId}`が存在するか」で行う（6章）。
  - 「誰が（uid）」「どのアカウントとして（accountId）」の組み合わせは、`senderId`等のaccountIdが自分の`ownedAccounts`にあるかで検証する。同一ユーザ配下の別アカウントへのなりすましもこれで防げる。
- **トーク一覧はアカウントの下に置く**：Firestoreの一覧取得（list）のルールは、クエリの条件だけで安全と証明できる必要があり、クエリに渡したaccountIdの保有ユーザをルールで確かめることはできない。そのため、アカウントから見たトーク一覧を`accounts/{accountId}/chatList/{chatRoomId}`（3.2.4）として持ち、パスのaccountIdで保有ユーザを判定する。相手側の`chatList`はアプリから書けないため、Cloud Functionsが更新する。
- **最上位に置くもの・ユーザの下に置くもの**：他人がaccountIdだけで引く`accounts`と、2人で共有する`chatRooms`は最上位に置く（ユーザの下に置くと、パスにuidが必要になるか、コレクショングループクエリの結果にuidが出てしまう）。本人しか読まない保有ユーザの情報は`users/{uid}`の下に置く。
- **ドキュメントIDと同値のフィールドを必ず持つ**：すべてのコレクションで、ドキュメントIDと同じ値をフィールドとしても持つ（例：`accounts.accountId`、`friends.friendAccountId`）。食い違いを防ぐため、セキュリティルールで「フィールド＝ドキュメントID」を必ず検証する（6章）。
- **通知に必要な情報を最小化**：機能仕様書4.4.6の決定に従い、Cloud Functionsが送る通知は固定文言とし、送信者名・本文をペイロードに含めない。
- **アカウント数上限は** `users` **のカウンタで判定**：セキュリティルールではコレクション件数を集計できないため、`users/{uid}.accountCount` をAccount作成と同じバッチで+1させ、`accounts`作成ルールが「作成後のカウンタ＝作成前＋1」かつプラン（`plan`）別上限以内であることを検証する。カウンタ更新を作成と同時に強制するため、並列作成でも上限をすり抜けられない。1回のバッチで複数を作れないよう、`users/{uid}.lastCreatedAccountId`が作るアカウントのIDと一致することも検証する。アプリ側（ACC-01の「＋」ボタン）の上限チェックは表示用で、最終的な強制はルール側で行う。

---



## 2. コレクション構成一覧

```
users/{uid}                              … Firebase Authentication の uid をドキュメントIDとする（本人のみ）
  ownedAccounts/{accountId}              … 保有ユーザの情報（本人のみ）
  inviteCounters/current                 … グループの招待の回数制限のカウンター（Cloud Functionsのみ）
  sendCounters/current                   … 送信の回数制限のカウンター（本人のみ）
  legalConsents/{version}                … 利用規約とプライバシーポリシーへの同意の記録（アプリから読み書き不可）

accounts/{accountId}                     … accountId = アカウントID（検索用ID、作成後不変）
                                            公開プロフィール（ID指定の1件取得のみ誰でも可。一覧取得は不可）
  friends/{friendAccountId}              … 片方向の友達関係（保有ユーザのみ）
  fcmTokens/{token}                      … 端末ごとのFCMトークン（保有ユーザのみ）
  blockedAccounts/{blockedAccountId}     … 片方向のブロック記録（保有ユーザ＋ブロックされた本人の1件取得）
  blockedAccountDates/{blockedAccountId} … ブロックした日時（保有ユーザのみ）
  chatList/{chatRoomId}                  … このアカウントから見たトーク一覧（保有ユーザのみ）
  friendRequests/{senderAccountId}       … 届いた友だち申請（保有ユーザが読める・消せる。作るのはCloud Functionsのみ）
  sentFriendRequests/{receiverAccountId} … 送った友だち申請（保有ユーザのみ読める。書くのはCloud Functionsのみ）

chatRooms/{chatRoomId}                   … chatRoomId = 参加者2アカウントIDをソートし"~"で連結
                                            2人で共有（参加者のみ、1件取得のみ）
  messages/{messageId}                   … 自動採番ID（参加者のみ）
  albums/{albumId}                       … トークのアルバム（参加者のみ。3.13）
    items/{itemId}                       … アルバムの画像・動画（参加者のみ）

unsentMessageArchives/{chatRoomId}/messages/{messageId} … 送信取消したメッセージの本文の保管（アプリからは読み書き不可）

userSecrets/{uid}                        … 引き継ぎパスワードのハッシュ（アプリからは読み書き不可）

withdrawalRecords/{uid}                  … 退会の記録（Cloud Functions・運営者のみ）
bannedPhones/{phoneHash}                 … 再登録を止めた電話番号（Cloud Functions・運営者のみ）
moderationActions/{actionId}             … 運営者の対応の記録（Cloud Functions・運営者のみ）

friendInviteKeys/{key}                   … 友だちの招待キー（キー→アカウント。アプリからは読み書き不可、3.14）
accountInviteKeys/{accountId}            … アカウントの今の招待キー（アプリからは読み書き不可、3.14）

reports/{reportId}                       … 通報（自動採番ID。アプリからは作成のみ）

appConfig/{configId}                     … アプリ全体の設定（ログイン前でも誰でも読める。アプリからは書けない）
billingCustomers/{billingId}             … RevenueCatの顧客とuidの対応づけ（アプリからは読み書き不可）
stickerPacks/{packId}                    … スタンプのパック（ログイン済みなら読める。アプリからは書けない）
```

---



## 3. 各コレクション定義



### 3.1 users

#### 【概要・方針】

「ユーザ」のコレクション。1ドキュメント＝1ユーザ（User単位の管理用）。

- Firebase Authentication（電話番号認証）のuidをドキュメントIDとする。
- 「ユーザ」概念をUI上であまり直接表示しない。（プランと電話番号は設定画面（SET-01）に表示する）
- 最初のAccount作成時に、クライアントから`accounts/{accountId}`・`users/{uid}/ownedAccounts/{accountId}`（3.1.1）・`users/{uid}`への書き込みを同一リクエストで送る。（全部成功 or 全部失敗）
- 2つ目以降のAccount作成時は、同リクエストで`users/{uid}.accountCount`を+1する。
- 本人以外は読めない。他人から見えるデータにuidを置かないため（1章）、保有ユーザの情報もこの下（`ownedAccounts`）に置く。
- `users`ドキュメントはアプリからは削除できない（ルールで削除不可）。退会では、Cloud Functions（`withdrawUser`）が`ownedAccounts`ごと削除し、Firebase Authのユーザーも削除する（機能仕様書4.1.5）。

#### 【データ構成】

> ドキュメントID：Firebase Authentication.uid

| フィールド      | 型        | 必須 | 初期値   | 説明                                                                             |
| ------------- | --------- | --- | ---     | ------------------------------------------------------------------------------ |
| uid           | string    | ○   | uid     | ドキュメントIDと同値。                                                                    |
| phoneNumber   | string    | ○   | -       | E.164形式の電話番号。ドキュメント作成時にAuthenticationの値を保存（ルールで認証トークンの電話番号と一致を検証）。電話番号の変更後は、アプリが新しい番号に更新する（ルールで認証トークンの電話番号と一致を検証）。 |
| createdAt     | timestamp | ○   | サーバー時刻 | User作成日時（サーバータイムスタンプ。ルールで`request.time`との一致を検証）。                    |
| accountCount  | number    | ○   | 1       | アカウント数上限の判定用カウンタ。通常は保有する有効なアカウント数と一致する（下記備考）。                  |
| plan          | string    | ○   | "free"  | 課金プラン。プランごとのアカウント数上限は下表。                                         |
| keptAccountIds | array\<string\> | | - | 使い続けるアカウント（機能仕様書4.2.1.3）。上限を超えている間だけ判定に使う。Cloud Functionsのみが書く。 |
| keptAccountsChosenAt | timestamp | | - | 画面から使い続けるアカウントを選んだ日時。ある場合は変更できない。プランが変わると消す（`recomputeUserPlan`）。Cloud Functionsのみが書く。 |
| suspendedAccountIds | array\<string\> | | - | 運営者が停止したアカウント。Cloud Functionsと`tools/moderate.js`だけが書く。ある間は送信・友だち追加・リアクション・プロフィールの変更・削除・新しいアカウントの作成ができない（読むことと通報はできる）。 |
| accountDeletionCount | number | | - | `accountDeletionWindowAt`から30日の間に削除したアカウントの数。`onAccountSoftDeleted`が書く。退会では数えない。 |
| accountDeletionWindowAt | timestamp | | - | 数え始めの削除の日時。 |
| accountCreateBlockedUntil | timestamp | | - | この日時まで新しいアカウントを作れない。30日に3回目の削除で`accountDeletionWindowAt`の30日後を入れる（機能仕様書4.2.3）。 |
| billingId | string | | - | RevenueCatのApp User ID（3.8）。購入の画面を開いたときにCloud Functionsが発行する。uidとは別の値。 |
| transferResetAt | timestamp | | - | 引き継ぎパスワードの再設定の申請（3.5）で、以前のデータを削除する日時。確認済みの端末がホームで警告を出し、取り消せるようにするために置く。Cloud Functionsのみが書く。 |

#### 【補足】

> 課金プランについて
> 
> アカウント数上限は下記の通り
> 
> | プラン    | アカウント数上限 |
> | -------- | ---------- |
> | `free`   | 2          |
> | `grade1` | 3          |
> | `grade2` | 5          |
> | `admin`  | 無制限      |
> 
> 未知の値・`users`未作成の場合は`free`として扱う。

> ※アカウント上限のルールは下記2箇所に記述（※変更時は両方を要更新）
>
> - `firebase/firestore.rules`（`isWithinAccountLimit`）
> - `lib/config/account_plan_limits.dart`

> `accountCount`の更新方法について
>
> - 加算（Account作成時）：クライアントが`accounts`作成と同じリクエストで行う。
>   - `users`が無い場合：`{ uid, phoneNumber, createdAt, accountCount: 1, plan: "free", lastCreatedAccountId }`で作成
>   - `users`がある場合：+1し、`lastCreatedAccountId`に作るアカウントのIDを書く（`accounts`の作成ルールが一致を確かめるので、1回の+1で作れるのは1件だけ）
>   - ルールでは次のみを許可「作成時は上記の初期値のみ」「更新は`accountCount`の+1と`lastCreatedAccountId`、または`phoneNumber`を認証トークンの電話番号に合わせる変更のみ」
> - 減算（アカウント削除時）：`isDeleted`が`false→true`に変わった時のみ、Cloud Functions（`onAccountSoftDeleted`）が-1更新（0未満にはしない）。同じイベントで2回呼ばれても1回だけ減らすよう、`ownedAccounts/{accountId}.deletionCountedAt`に印を付ける。保有ユーザのuidは、`ownedAccounts`のコレクショングループクエリ（`accountId`で検索）で引く（3.1.1）。
>   - アカウント削除は論理削除のため、onDeleteではなくonUpdateで減算する。
> - ルールはAccount作成を伴わない単独の+1も許可している（自分の上限が減るだけのため）。そのため`accountCount`が実際の有効なアカウント数と一致することは保証されない。

> Planの変更について
>
> - `grade1`・`grade2`は、Cloud Functionsが`billingCustomers`（3.8）から決める。
> - クライアントからは変更不可（ルールで作成時は`free`のみ、更新は`accountCount`・`phoneNumber`のみ許可）。
> - 運営者用の`admin`はFirebaseコンソールで手動で付与する。Cloud Functionsは`admin`のユーザのplanを変更しない。
> - planが下がって`accountCount`が上限を超えると、`keptAccountIds`に無いアカウントが読み取り専用になる（機能仕様書4.2.1.3）。ルールの`canActAs`が、メッセージの送信・リアクション・友だち追加を拒否する。1対1のリアクションは、変更したキーが一覧の中にあるかで判定する。
> - `keptAccountIds`の既定は、`plan`・`accountCount`の変化で動くトリガー`onUserAccountStateChanged`が書く。一覧の変更は`setKeptAccounts`（callable）で、プランが変わるごとに1回だけ行える。`users/{uid}`は本人しか読めないため、他の利用者には見えない。

---



### 3.1.1 users/{uid}/ownedAccounts

#### 【概要・方針】

「ユーザが保有するアカウント」のサブコレクション。1ドキュメント＝そのユーザが保有するアカウント1つ。

- 保有するアカウントのaccountIdをドキュメントIDとする。
- 読み取りは本人のみ（1章）。自分のアカウント一覧（ACC-01等）は、ここから取得したaccountIdで`accounts`を読む。
- 保有ユーザの判定（Firestoreルール・Storageルール共通）は、`users/{自分のuid}/ownedAccounts/{accountId}`が存在するかで行う（6章・7.3）。
- アカウント作成時に、`accounts`・`users`と同一リクエストで作る（3.1）。作成後の更新は、本人がアカウントごとの通知設定（`notificationsEnabled`・`reactionNotificationsEnabled`）を書き換える場合だけ許可する。削除はしない（ルールで禁止）。
- 整合性の保ち方は3.2【補足】「`accounts`と`ownedAccounts`の整合性」を参照。

#### 【データ構成】

> ドキュメントID：accountId

| フィールド  | 型        | 必須 | 初期値      | 説明                                                                                   |
| --------- | --------- | --- | ---------- | ------------------------------------------------------------------------------------ |
| accountId | string    | ○   | accountId  | ドキュメントIDと同値。Cloud Functions（Admin SDK）がaccountIdから保有ユーザを引くときのコレクショングループクエリ用。 |
| createdAt | timestamp | ○   | サーバー時刻 | 自分のアカウント一覧の並び順（昇順）。                                                               |
| notificationsEnabled | boolean | －   | （なし）     | このアカウント宛ての通知を受け取るか。フィールドが無いときはオン（`true`）として扱う。`false`なら、Cloud Functionsがメッセージ・リアクションのどちらの通知も送らない。 |
| reactionNotificationsEnabled | boolean | －   | （なし）     | 自分のメッセージへのリアクションの通知を受け取るか。フィールドが無いときはオン。`notificationsEnabled`が`false`ならこの値に関係なく送らない。 |

#### 【補足】

> 使用場面（3パターン）
>
> | # | 場面 | 使う側 | 使い方 |
> | --- | --- | --- | --- |
> | 1 | 自分のアカウント一覧の取得 | アプリ | `users/{自分のuid}/ownedAccounts`を`createdAt`順に一覧取得し、そのaccountIdで`accounts/{accountId}`を1件ずつ読む。 |
> | 2 | 保有ユーザの判定 | Firestoreルール・Storageルール | `users/{自分のuid}/ownedAccounts/{accountId}`が存在するかで、そのアカウントとして操作してよいかを判定する（6章の`isOwnerOfAccount`、7.3）。アカウントに属するデータのほぼすべての操作で使う（`accounts`の更新、`friends`・`blockedAccounts`・`fcmTokens`・`chatList`の読み書き、`chatRooms`・`messages`の読み書き、プロフィール画像のアップロード）。作成時の`accounts`との整合性チェック（3.2【補足】）もここに含む。 |
> | 3 | accountIdから保有ユーザを引く | Cloud Functions | コレクショングループクエリで保有ユーザのuidを引く（下記）。アカウント削除時の`accountCount`の-1と、退会処理で使う。アプリからは使わない。 |
> | 4 | アカウントごとの通知設定 | アプリ・Cloud Functions | アプリ（SET-01・SET-06）は`users/{自分のuid}/ownedAccounts/{accountId}`の`notificationsEnabled`・`reactionNotificationsEnabled`を読み書きする。Cloud Functions（`onMessageCreated`・`onMessageReacted`）は、通知を送る前にコレクショングループクエリで宛先アカウントのドキュメントを引き、オフなら送らない。 |

> accountIdから保有ユーザを引く方法
>
> - クライアント・ルールでは不要（ルールは「リクエストした本人のuidの下にあるか」を確かめるだけ）。
> - Cloud Functions（`onAccountSoftDeleted`の`accountCount`減算、退会処理、通知設定の確認）では、`collectionGroup('ownedAccounts').where('accountId', '==', accountId)`で引く。結果のパスの親がuid。

---



### 3.1.2 users/{uid}/sendCounters/current

メッセージ送信の回数制限のカウンター。uid単位で1件だけ持ち、同じユーザの全アカウントの送信を合算する。

- メッセージを作るリクエストに、`count`の+1と`lastMessageKey`の更新を必ず含める。含まないメッセージの作成、1回の増加で複数のメッセージを作ることは、ルールで拒否する。
- アプリは今の値を読まずに+1だけを書く。そのため、オフライン・複数端末・同時送信でも、正規の送信が値のずれで拒否されることはない。
- 使える件数は「100件＋`baseAt`からの経過秒数÷5」で、3,000件が上限。`baseAt`が無い間は100件。
- `baseAt`が未設定または24時間以上前のとき、アプリは送信とは別のリクエストで`count`を0、`baseAt`をサーバー時刻にする。アプリが確かめるのは1時間に1回まで。
- 上限を超えた送信はルールで拒否され、アプリでは通常の送信失敗と同じ扱いになる（機能仕様書4.4.3.2）。
- 退会時は`withdrawUser`が`users/{uid}`ごと削除する。

#### 【データ構成】

> ドキュメントID：`current`（固定）

| フィールド | 型 | 必須 | デフォルト | 説明 |
|---|---|---|---|---|
| counterId | string | ○ | - | ドキュメントID（`current`）。 |
| count | number | ○ | - | `baseAt`以降に送信した件数。 |
| lastMessageKey | string | | - | 最後に送信したメッセージ（`{chatRoomId}/{messageId}`）。 |
| baseAt | timestamp | | - | 件数の起点。サーバー時刻のみ。 |

### 3.1.3 users/{uid}/legalConsents/{version}

利用規約とプライバシーポリシーへの同意の記録。AUT-02の案内を見てサインインしたときに、アプリが`recordLegalConsent`（callable）を呼び、サーバーの版と時刻を書く。

- `users/{uid}`は最初のアカウントの作成まで無いので、親のドキュメントが無い状態でも書く。
- 同じ版は最初の日時を残す。改定後の版でサインインすると、新しいドキュメントが増える。
- サインインの結果を止めないよう、失敗してもエラーにしない（アプリが3回まで試す）。そのため、記録が無い利用者がいる。
- 改定の再同意：アプリは、ホームを開いたときに、`version`がアプリの`LegalLinks.documentVersion`以上のドキュメントがあるかを読む。無ければ再同意のダイアログを出し、「同意する」で`recordLegalConsent`を呼ぶ。サーバーの`LEGAL_DOCUMENT_VERSION`とアプリの版は、規約・ポリシーの最終改定日に揃える。
- 引き継ぎパスワードの確認前のセッションからも受け付ける。
- 本人だけが読める。書くのはCloud Functionsのみ。
- 退会時は`withdrawUser`が`users/{uid}`ごと削除する。

#### 【データ構成】

> ドキュメントID：版（規約・ポリシーの最終改定日。例：`2026-11-01`）

| フィールド | 型 | 必須 | デフォルト | 説明 |
|---|---|---|---|---|
| version | string | ○ | - | ドキュメントID（版）。 |
| agreedAt | timestamp | ○ | - | 記録した時刻（サーバー時刻）。 |

---

### 3.1.3 users/{uid}/inviteCounters/current

グループの招待の回数制限のカウンター。uid単位で1件だけ持ち、同じ人の別のアカウントからの招待も合わせて数える。Cloud Functionsだけが読み書きする。

| フィールド | 型 | 必須 | 説明 |
|---|---|---|---|
| counterId | string | ○ | ドキュメントIDと同値（`current`）。 |
| count | number | ○ | `baseAt`から24時間に作った招待（`groupRequests`）の数。上限は`appConfig/groupLimits.maxInvitesPerDay`（既定30）。 |
| baseAt | timestamp | ○ | 数え始めの日時。24時間を過ぎた次の招待で数え直す。 |

---

### 3.2 accounts

#### 【概要・方針】

「アカウント」のコレクション。1ドキュメント＝1アカウント（プロフィール単位。1ユーザが複数保有する）。

- 利用者が作成時に入力したアカウントID（検索用ID）をドキュメントIDとする。作成後は変更不可。
- 他人にも公開するプロフィールのみを持つ。保有ユーザのuidは持たない（3.1.1の`ownedAccounts`に置く）。
- 作成時は、`accounts/{accountId}`・`users/{uid}/ownedAccounts/{accountId}`・`users/{uid}`の3つへの書き込みをまとめて1リクエストで送る（3.1参照）。
- 作成時は全フィールドを明示的に書き込む（未設定の任意項目も`null`で書く）。
- アカウント削除は論理削除（`isDeleted: true`）のみ。（ルールで物理削除不可）。
- サインイン済みの利用者が、ID指定で1件取得（get）のみできる。

#### 【データ構成】

> ドキュメントID：アカウントID（accountId）。半角英数字・記号（`.` `-` `_`）の4〜20文字。大文字・小文字は区別する。


| フィールド      | 型        | 必須 | 初期値      | 説明                                                                             |
| ------------- | --------- | --- | ---------- | ------------------------------------------------------------------------------ |
| accountId     | string    | ○   | accountId  | ドキュメントIDと同値。                                                                    |
| displayName   | string    | ○   | 入力値      | 表示名（前後の空白を除いて1〜20文字）。                                                     |
| photoURL      | string    | －   | `null`     | プロフィール画像のダウンロードURL（末尾に乱数の`v`クエリ付与、7.1参照）。`null`か、自分のアカウントの画像のURLだけを入れられる（7.1）。未設定時はアプリ側でデフォルト画像を表示。画像付きで作成した場合は作成直後に設定する（下記補足）。 |
| backgroundURL | string    | －   | `null`     | 背景画像のダウンロードURL（同上）。PRO-03で設定する。                                          |
| createdAt     | timestamp | －   | なし       | 使わない。誰でも読めるドキュメントなので、今のアプリとCloud Functionsは書かない。ビルド16以前のアプリが書く値と、過去の値が残る。作成順は`ownedAccounts.createdAt`（3.1.1）で分かる。 |
| updatedAt     | timestamp | －   | なし       | 同上。                                                                            |
| allowIdSearch | boolean   | ○   | `true`     | IDによる友だち追加を許可するか。PRO-03のトグルで変更（下記補足）。`false`の相手は、IDだけでは友だち追加・1対1のトークの開始ができない（6章・3.14）。 |
| bio           | string    | －   | `null`     | ひとこと（前後の空白を除いて0〜100文字）。PRO-03のボトムシートで編集。編集で空にした場合は空文字。                  |
| isDeleted     | boolean   | ○   | `false`    | アカウント削除（ACC-03、機能仕様書4.2.3）の論理削除フラグ（下記補足）。                                  |

#### 【補足】

> 画像付きで作成する場合の流れ
>
> - Accountドキュメントを作成した後にStorageへアップロードし、`photoURL`を更新する（Storageルールが`users/{uid}/ownedAccounts/{accountId}`の存在を参照するため、作成が済んでいる必要がある）。
> - アップロードに失敗しても、画像なしで作成を完了する。

> ID検索・QR読み取りでの扱い
>
> 下記の場合は、存在しない場合と同じ「見つからない」扱いにする（存在や状態を推測させないため）。
>
> | 相手の状態                | ID検索（FRI-04） | QR読み取り（QRC-01） |
> | ----------------------- | -------------- | ----------------- |
> | `allowIdSearch: false`  | 見つからない     | 表示する（追加には招待キーが要る。3.14） |
> | `isDeleted: true`       | 見つからない     | 見つからない        |
> | ブロック関係にある（3.2.3）   | 見つからない     | 見つからない        |

> `isDeleted`（論理削除）について
>
> - `true`の場合、UI上は実データに関わらず「退会済みアカウント」として表示する（ドキュメントに残っているプロフィール画像・背景画像・ひとことも、他の人の画面には表示しない）。自分のアカウント一覧・アカウント数上限のカウントからも除外する。
> - 一度`true`にしたAccountはルールで更新不可（`false`に戻すと`accountCount`が戻らず、上限をすり抜けられるため）。
> - `false→true`に変わった時に、Cloud Functions（`onAccountSoftDeleted`）が`users/{uid}.accountCount`を-1する（3.1参照）。
> - 論理削除にする理由：物理削除すると同じアカウントIDで第三者が再作成でき、削除前のIDを参照するfriends・チャット履歴が無関係な新規アカウントを指してしまう。ドキュメントを残せば、作成ルールの存在チェックがそのままID再利用の防止になる。
> - アカウント削除（ACC-03）の論理削除後も、表示名・ひとこと・画像URL等はドキュメントに残る。退会では、ドキュメントは論理削除のまま残し、表示名を空文字、ひとこと・画像URLを`null`、`allowIdSearch`を`false`にして個人情報を消す。

> ルールで検証する内容
>
> - 読み取り：サインイン済みならget（ID指定）のみ可。list（一覧・条件検索）は不可。
> - 作成：IDが未使用であること、形式が正しいこと（4章）、予約IDでないこと、同一リクエストで`users/{自分のuid}/ownedAccounts/{accountId}`も作られていること、同一リクエストで`users/{uid}.accountCount`が+1されていて上限以内であること、`isDeleted`が`false`であること、公開プロフィールのフィールド以外（`ownerUserId`等）を含まないこと、`users/{uid}.lastCreatedAccountId`がこのIDであること。
> - 更新：保有ユーザ（`ownedAccounts`にある本人）のみ。削除フラグ（`isDeleted: true`）は更新不可。
> - 表示名（1〜20文字）・ひとこと（100文字まで）・`allowIdSearch`の型は、作成時と、更新で値を変えるときに検証する。`isDeleted`は`true`にする更新だけを許す。
> - `allowIdSearch: false`でも、ID指定の取得（公開プロフィールの表示）は制限していない。友だち追加（3.2.1の作成）と1対1のルームの作成（3.3）をルールで拒む。

> `accounts`と`ownedAccounts`の整合性
>
> Firestoreに外部キーはなく、`accounts`と`ownedAccounts`（3.1.1）のつながりは同じaccountIdだけのため、ルールで整合性を保つ。
>
> - 作成：`accounts`・`ownedAccounts`・`users`を同一リクエストで書く（全部成功か全部失敗）。
> - `accounts`の作成：同リクエストで`users/{自分}/ownedAccounts/{ID}`も作られていること（`existsAfter`）。
> - `ownedAccounts`の作成：`accounts/{ID}`がまだ存在せず、同じリクエストで作られていること（既存の他人のアカウントを自分の持ち物として登録する乗っ取りを防ぐ）。2人が同時に同じIDで作成しても、`accounts`の作成が片方しか通らないため、負けた側は`ownedAccounts`ごと失敗する。
> - 変更・削除：`ownedAccounts`は作成後の削除を禁止し、更新は本人による通知設定の2項目の書き換えだけ許可する（`accountId`・`createdAt`は変えられない）。`accounts`の削除も禁止（論理削除のみ）。退会ではCloud Functions（Admin SDK）が`ownedAccounts`を削除し、`accounts`は個人情報を消した論理削除の状態で残す。
> - アプリ側：`ownedAccounts`にあるのに`accounts`が読めないものは、自分のアカウント一覧に出さない。

---



### 3.2.1 accounts/{accountId}/friends

#### 【概要・方針】

「友だち」のサブコレクション。1ドキュメント＝友だち1人（片方向）。

- 相手のaccountIdをドキュメントIDとする。
- 「追加した側」のアカウント下にのみ作成する（相手側には自動生成しない）。
- 読み取り・書き込みはアカウントの保有ユーザのみ（6章）。

#### 【データ構成】

> ドキュメントID：相手のaccountId

| フィールド        | 型        | 必須 | 初期値          | 説明                                                                             |
| --------------- | --------- | --- | -------------- | ------------------------------------------------------------------------------ |
| friendAccountId | string    | ○   | 相手のaccountId | ドキュメントIDと同値。                                                                    |
| addedAt         | timestamp | ○   | サーバー時刻     | 追加日時（サーバータイムスタンプ）。友だち一覧はこの降順。                                             |
| nickname        | string    | －   | （なし）         | 自分だけに見える、相手の表示名の上書き（機能仕様書4.3.3、前後の空白を除いて最大20文字）。未設定時はフィールド自体が存在しない（空で保存するとフィールドを削除）。未設定なら相手の`displayName`を使う。 |
| memo            | string    | －   | （なし）         | 自分だけに見えるメモ（機能仕様書4.3.7、最大500文字）。未設定時はフィールド自体が存在しない。 |
| memoPinned      | boolean   | －   | （なし）         | `memo`をトークにピン留めしているか。未設定時はフィールド自体が存在しない。 |
| inviteKey       | string    | －   | （なし）         | 相手のマイQRコード・招待リンクから追加したときの、相手の招待キー（3.14）。相手が`allowIdSearch: false`のとき、ルールが追加を許す根拠にする。作成のときだけ見る。 |

#### 【補足】

> チャットルームIDを持たない理由
>
> - 相手とのチャットルームIDは、2人のaccountIdから計算で決まる（4章）ため、フィールドとしては持たない。友だちのプロフィールからトークを開くときも、計算したIDを使う。

> `nickname`について
>
> - 追加した側の`friends`にのみ保存されるため、保有ユーザ限定のルール（6章）でそのまま保護される。相手には見えない。

> 作成のルール
>
> - ブロック関係が無く、次のどれかのときだけ作れる：相手の`allowIdSearch`が`false`でない／相手が先にこちらを友だちにしている（`accounts/{相手}/friends/{自分}`がある）／2人の1対1のルール（3.3）がある／`inviteKey`が相手の招待キー（`friendInviteKeys/{inviteKey}.accountId`が相手）である。
> - 友だち申請の承認（3.2.5）はCloud Functionsが書くため、ルールを通らない。

> 相手が削除済み・ブロックした場合
>
> - 相手が`isDeleted`になってもfriendsドキュメントは自動削除しない。クライアントが相手取得時に`isDeleted`を確認し、退会済みアカウントとして表示する。
> - ブロック時（3.2.3）は、自分側・相手側双方のfriendsドキュメントを削除する。ブロック解除しても友だち関係は復元しない。

---



### 3.2.2 accounts/{accountId}/fcmTokens

#### 【概要・方針】

「プッシュ通知用トークン」のサブコレクション。1ドキュメント＝1端末。

- FCMトークン文字列そのものをドキュメントIDとする。
- FCMトークンは「端末×アプリ」を指す通知の宛先。ユーザ・アカウントとは関係なく、同じ端末・同じアプリなら、どのアカウントを使っても同じ値になる。
- 通知の宛先はアカウント単位のため、アカウントの下に置く。1アカウントを複数端末で使う場合に備え、サブコレクションとする。1台の端末で複数のアカウントを使うと、同じトークンがそれぞれのアカウントの下に登録される。
- 標準では、自分が持つ全アカウントにこの端末のトークンを登録し、全アカウント宛ての通知をその端末に届ける（登録・削除のタイミングは【補足】）。
- 読み取り・登録（作成・更新）はアカウントの保有ユーザのみ（6章）。アプリからの削除も保有ユーザのみで、管理者のログアウトでこの端末のトークンを外すときにだけ行う。それ以外の削除はCloud Functionsが行う（【補足】）。通知の送信時はCloud Functionsが読む。

#### 【データ構成】

> ドキュメントID：FCMトークン文字列

| フィールド  | 型        | 必須 | 初期値                | 説明                                                   |
| --------- | --------- | --- | -------------------- | ---------------------------------------------------- |
| token     | string    | ○   | トークン               | FCMトークン本体（ドキュメントIDと同値）。                                |
| platform  | string    | ○   | `"ios"`／`"android"` | 端末の種類。                                               |
| language  | string    | ○   | アプリの表示言語         | `"ja"`／`"en"`。Cloud Functionsが通知文言の言語を選ぶのに使う。          |
| updatedAt | timestamp | ○   | サーバー時刻           | 最終更新日時（登録の都度上書き）。                                      |

#### 【補足】

> 登録・削除のタイミング
>
> | 場面 | 処理 |
> | --- | --- |
> | 起動時・トークン更新時・表示言語の変更時・アカウント作成時 | 自分が持つ全アカウント（削除済みを除く）に、この端末のトークンを登録する（同じトークンなら上書きし、`language`も更新）。 |
> | アカウント削除時 | そのアカウントの`fcmTokens`を全件削除する（他の端末の分も含むため、Cloud Functions（`onAccountSoftDeleted`）で行う）。 |
> | 管理者のログアウト時 | 自分が持つ全アカウントから、この端末のトークンだけを、サインアウトの前にアプリが削除する（機能仕様書4.1.7）。 |
> | 無効なトークン | Cloud Functions（`onMessageCreated`）の送信時に`messaging/registration-token-not-registered`を受けたトークンを、その場で削除する。 |

---



### 3.2.3 accounts/{accountId}/blockedAccounts

#### 【概要・方針】

「ブロック」のサブコレクション。1ドキュメント＝ブロックした相手1人（片方向）。

- ブロックした相手のaccountIdをドキュメントIDとする。
- 自分（accountId）がブロックした相手を、自分側にのみ記録する。
- 読み取り・書き込みはアカウントの保有ユーザのみ。ブロックされた側も、自分宛のドキュメント1件に限り`get`できる（6章）。相手のブロックリスト一覧は読めない。

#### 【データ構成】

> ドキュメントID：ブロックした相手のaccountId

| フィールド         | 型        | 必須 | 初期値          | 説明                                                   |
| ---------------- | --------- | --- | -------------- | ---------------------------------------------------- |
| blockedAccountId | string    | ○   | 相手のaccountId | ドキュメントIDと同値。                                           |
| blockedAt        | timestamp | －   | なし           | 以前のアプリが書いた日時。今のアプリは書かない（下記）。                               |

#### 【補足】

> ブロック・解除の処理
>
> - ブロックは1回のバッチで「ブロック記録の作成」「双方のfriendsドキュメント削除」「ルームが存在すれば自分の`chatList.unreadCount`を0にし、`chatList.blockedAt`にブロック日時を書く」を行う。
> - 解除はドキュメント削除のみ。友だち関係は復元しない（`chatList.blockedAt`も残す）。

> ブロックした日時（`blockedAccountDates`）
>
> - `accounts/{accountId}/blockedAccountDates/{blockedAccountId}`に`blockedAccountId`と`blockedAt`（サーバー時刻）を持つ。本人だけが読み書きでき、ブロック記録と同じバッチで書き、解除で消す。
> - `blockedAccounts`はブロックされた側も1件取得できるので、そこに時刻を置くと、同じ人が複数のアカウントで同じ相手をブロックした時刻から、アカウントの結び付きが分かる。
> - ブロックリスト（SET-02）は、この日時（無ければ以前の`blockedAccounts.blockedAt`）の降順に端末で並べる。

> ブロック関係にある場合の扱い
>
> - ブロック関係（どちら向きでも）にあるAccount同士は、ルールで友だち追加・ルーム作成・メッセージ送信を拒否する。
> - アプリではID検索・QR読み取りで「見つからない」扱いにし、ブロックした事実を悟らせない（3.2）。

---



### 3.2.4 accounts/{accountId}/chatList

#### 【概要・方針】

「トーク一覧」のサブコレクション（アカウント単位の非公開インデックス）。1ドキュメント＝そのアカウントから見たチャットルーム1件。

- 対応するチャットルームのchatRoomIdをドキュメントIDとする。
- トーク一覧・未読バッジは、すべてここから取得する（下記【補足】「未読バッジの集計」）。
- 読み取りはアカウントの保有ユーザのみ（一覧取得も可。パスのaccountIdで保有ユーザを判定できるため、1章の一覧取得の制約を満たす）。
- 自分の分はアプリが、相手の分はCloud Functionsが書く（相手の`chatList`へのアプリからの書き込みはルールで禁止）。

#### 【データ構成】

> ドキュメントID：chatRoomId

| フィールド      | 型        | 必須 | 初期値        | 説明                                                                                   |
| ------------- | --------- | --- | ------------ | ------------------------------------------------------------------------------------ |
| chatRoomId    | string    | ○   | chatRoomId   | ドキュメントIDと同値。                                                                    |
| peerAccountId | string    | ○   | 相手のaccountId | トーク相手。作成後不変。                                                                       |
| lastMessage   | map       | －   | `null`       | 一覧のプレビュー用。`{ messageId, type, text, senderId, createdAt }`。画像メッセージは`type: "image"`で`text`を持たず、一覧には「画像」と表示する。当日の定型連絡は`type: "meetupStatus"`で`text`の代わりに`meetupStatus`を持ち、一覧には文言（「遅れます」など）を表示する。`messageId`は送信取消・削除時に「最新メッセージが消えたか」を判定するため。 |
| lastMessageAt | timestamp | ○   | サーバー時刻   | 一覧のソートキー（降順）。作成時はルーム作成日時を入れる（`orderBy`はフィールドが無いドキュメントを除外するため、作成時から必ず持たせる）。 |
| unreadCount   | number    | ○   | 0            | このアカウントの未読件数（メッセージのみ）。アプリの既読処理は、この件数分だけ新しい側からメッセージを遡る。 |
| unreadReactions | map     | －   | （なし）       | 未読のリアクション。キーは「メッセージID~リアクションした相手のaccountId」、値は付いた日時（サーバー時刻）。自分のメッセージに相手がリアクションを付けたときにCloud Functions（`onMessageReacted`）が追加し（受け取る側のリアクションの通知がオンの場合のみ）、解除・送信取消でCloud Functionsが消す。アプリはトークを開いたとき（既読処理）・ブロックしたときにフィールドごと消すのみ（増やせない。6章）。画面の未読数は`unreadCount`と、このmapの件数の合計。最も新しい日時が`lastMessageAt`より後なら、トーク一覧のプレビューを「リアクションされました」にする。 |
| blockedAt     | timestamp | －   | なし          | このアカウントが相手を最後にブロックした日時（ブロック時に書く。解除しても消さない）。ブロック解除後、これより新しいメッセージがある場合だけトークリクエストに出す（下記「トーク一覧での区分け」）。 |
| createdAt     | timestamp | ○   | サーバー時刻   | 作成日時。                                                                                |

#### 【補足】

> 更新のタイミング
>
> | 場面 | 自分の`chatList`（アプリ） | 相手の`chatList`（Cloud Functions） |
> | --- | --- | --- |
> | 最初のメッセージ送信（ルーム作成） | `chatRooms`・メッセージと同一リクエストで作成（`lastMessage`入り） | `onMessageCreated`で作成（`unreadCount`は1） |
> | 2通目以降のメッセージ送信 | メッセージと同一リクエストで`lastMessage`・`lastMessageAt`を更新 | `onMessageCreated`で`lastMessage`・`lastMessageAt`を更新し、`unreadCount`を+1（プッシュ通知の送信と同じ関数。相手の`chatList`が無ければ作る） |
> | 送信取消（3.3.1） | － | `onMessageUnsent`で、最新メッセージだった場合に双方の`lastMessage`・`lastMessageAt`を書き直す。相手が未読なら相手の`unreadCount`を-1 |
> | 削除（自分の画面のみ、3.3.1） | 最新メッセージだった場合に、自分に見えている最新のメッセージで`lastMessage`を書き直す（メッセージの`hiddenFor`の更新と同一リクエスト） | － |
> | 既読化（下記「未読バッジの集計」）・ブロック（3.2.3） | `unreadCount`を0にする（ブロック時は`blockedAt`も書く） | － |

> ルールで検証する内容
>
> - 読み取り：アカウントの保有ユーザのみ（get・list）。
> - 作成：アカウントの保有ユーザで、同一リクエストで作る`chatRooms`（または既存のルーム）の参加者に自分のaccountIdと`peerAccountId`が含まれること。`unreadCount`は0。
> - 更新：アカウントの保有ユーザのみ。`peerAccountId`は変更不可。`unreadCount`は変更しないか0にするのみ（増やすのはCloud Functionsだけ）。
> - 削除：不可。

> 反映の遅れ：相手の`chatList`はCloud Functionsが更新するため、メッセージ作成から一瞬（数百ミリ秒程度）遅れて反映される。

> 未読バッジの集計（機能仕様書4.4.1）
>
> 機能仕様書4.4.1の未読バッジは、各アカウントの`chatList`の`unreadCount`を集計するだけで実現する。uidでは検索しない（1章）ため、複数アカウントにまたがる集計は、アカウントごとに`chatList`を取得して合計する。
>
> - CHA-01（ボトムナビのチャットタブ）：アクティブアカウントの`chatList`のうち、一覧に表示するルーム（通常＋リクエスト。ブロック等で非表示のルームは除く）の`unreadCount`を合計する。追加の読み取りは発生しない。
> - ACC-01（アカウント一覧の各行）：自分の各アカウントの`chatList`をそれぞれ取得し、アカウントごとに合計する（アカウント数分のクエリ）。ACC-01を開いたタイミングでのみ実行し、常時リスナーは張らない。
> - AppHomeHeaderアバター：アクティブアカウント以外の各アカウントの`chatList`を常時購読し、`unreadCount`を合計する（ホーム画面は常時マウントのため常時リスナーとする。アカウント数−1個のリスナー）。
> - グループへの招待（「!」のバッジ）：未読数には含めず、`groupRequests`の有無で判定する。CHA-01はアクティブアカウントの一覧の監視をそのまま使う（追加の読み取りなし）。AppHomeHeaderアバターは、アクティブアカウント以外の各アカウントの`groupRequests`を常時監視する（アカウント数−1個のリスナー）。ACC-01はこれらの監視の結果を使うため、開いても読み取りは増えない（アカウントが選ばれていない全画面のACC-01では、開いている間だけ各アカウントを監視する）。
- 既読化：CHA-02を開いている側が、自分の`chatList.unreadCount`の件数分だけ新しい側から未読メッセージを遡って`readBy`に自分を追加し、自分の`chatList.unreadCount`を0にする（クライアント側で実施。未読0件ならメッセージを読まない）。開いている間に未読数が増えた（新着が届いた）ときも同じ処理を行う。1回のバッチの書き込みは500件までのため、未読が多い場合は分けて書き、`unreadCount`は最後のバッチで0にする。
> - 表示形式：いずれも上限なしの実数で表示（「99+」に丸めない）。詳細は画面設計書5.8.1・5.2.1・5.3.1参照。

---



### 3.2.5 accounts/{accountId}/friendRequests

#### 【概要・方針】

届いた友だち申請（機能仕様書4.3.8）。1ドキュメント＝申請してきた相手1人。

- 申請してきた相手のaccountIdをドキュメントIDとする。同じ相手からの申請は1件だけ。
- 作るのはCloud Functions（`sendFriendRequest`）だけ。保有ユーザは読めるほか、ブロックのバッチで消せる（6章）。承認・断るは`respondToFriendRequest`が消す。
- 送った側の記録（3.2.6）とは別の文書にする。送った側は自分の側だけを読めるので、断られて消えたことが分からない。

#### 【データ構成】

> ドキュメントID：申請してきた相手のaccountId

| フィールド | 型 | 必須 | 説明 |
|---|---|---|---|
| senderAccountId | string | ○ | ドキュメントIDと同値。 |
| chatRoomId | string | ○ | 申請を送ったグループのチャットルームID。オフ会グループの片付けで、グループごとにまとめて消すために使う。 |
| groupName | string | ○ | 送った時点のグループ名。FRI-01に「「{グループ名}」から」と出す。グループを抜けた後・グループが無くなった後でも出せるよう、写しを持つ。 |
| groupKind | string | － | オフ会グループなら`meetup`（8.14）。普通のグループは持たない。 |
| createdAt | timestamp | ○ | 申請の日時（サーバー時刻）。FRI-01はこの降順。 |
| expiresAt | timestamp | － | 消す日時。普通のグループは`createdAt`の30日後。オフ会グループは持たない（閉じた後の片付けが、閉じた日時の30日後を入れるか、`chatRoomId`で引いて消す）。 |

#### 【補足】

> 期限での削除
>
> - `expiresAt`にFirestoreのTTLを設定する（`firestore.indexes.json`の`fieldOverrides`）。TTLの削除は期限から遅れる（目安は24時間以内）ため、アプリは`expiresAt`を過ぎた申請を表示せず、Cloud Functionsも無いものとして扱う。
> - 普通のグループの申請は、相手や自分がグループを抜けても消さない（機能仕様書4.3.8）。抜けたことが送った側の表示の変化で分からないようにするため。

> 消す場面
>
> - 承認・断る：`respondToFriendRequest`。
> - ブロック：ブロックした側が、相手から届いた申請を、ブロックの記録と同じバッチで消す。
> - アカウント削除（`onAccountSoftDeleted`）・退会（`withdrawUser`）：そのアカウントの`friendRequests`・`sentFriendRequests`を消す。相手の側に残った申請は、相手のアプリが退会済みとして表示せず、期限で消える（オフ会グループは#492の片付けで消える）。

---

### 3.2.6 accounts/{accountId}/sentFriendRequests

#### 【概要・方針】

送った友だち申請（機能仕様書4.3.8）。1ドキュメント＝申請した相手1人。PRO-01の「申請中」の判定に使う。

- 申請した相手のaccountIdをドキュメントIDとする。残っている間は、同じ相手にもう送れない（`sendFriendRequest`が断る）。
- 読めるのは保有ユーザだけ。書くのはCloud Functionsだけ（取り消しの機能は無い）。
- 相手が断っても消さない（3.2.5）。承認されたら`respondToFriendRequest`が消す。

#### 【データ構成】

> ドキュメントID：申請した相手のaccountId

| フィールド | 型 | 必須 | 説明 |
|---|---|---|---|
| receiverAccountId | string | ○ | ドキュメントIDと同値。 |
| chatRoomId | string | ○ | 3.2.5と同じ。 |
| groupKind | string | － | 3.2.5と同じ。 |
| createdAt | timestamp | ○ | 申請の日時（サーバー時刻）。 |
| expiresAt | timestamp | － | 3.2.5と同じ値。期限を過ぎたら、アプリは「申請中」を出さず、もう一度申請できる。 |

#### 【補足】

> Cloud Functions
>
> | 関数 | 種類 | 内容 |
> |---|---|---|
> | `sendFriendRequest` | callable | 引数`accountId`・`chatRoomId`・`targetAccountId`。本人のアカウントで読み取り専用でないこと、グループが削除されておらず両方が`participantIds`にいること、相手が退会済みでないこと、自分の`friends`に相手がいないこと、期限内の`sentFriendRequests`が無いことを確かめ、トランザクションで3.2.5・3.2.6を書く。相手から期限内の申請が届いていれば、承認として扱う。ブロック関係にあれば3.2.6だけを書き、成功を返す（悟らせない）。新しく届けたときだけ通知（`type: "friend_request"`、宛先の`notificationsEnabled`がオフなら送らない）。 |
> | `respondToFriendRequest` | callable | 引数`accountId`・`senderAccountId`・`accept`。断る：3.2.5を消すだけ。承認：期限内の3.2.5があること（無ければ`request-not-found`）、本人が読み取り専用でないこと（`read-only`、申請は残す）、相手が退会済みでなくブロック関係にないこと（`request-invalid`、申請は消す）を確かめ、トランザクションで双方の`friends`（無ければ作る。あればそのまま）を書き、3.2.5・相手の3.2.6を消す。 |
>
> エラーの`message`は理由のコード（`read-only`・`not-member`・`account-not-found`・`already-friend`・`request-not-found`・`request-invalid`）で、アプリが文言を出し分ける。`already-requested`は成功として返す。

---

### 3.3 chatRooms

#### 【概要・方針】

「チャットルーム」のコレクション。1ドキュメント＝1対1のトーク1つ（2人で共有）。

- 参加者2つのaccountIdを昇順ソートし`~`で連結した文字列をドキュメントIDとする。
- 最初のメッセージ送信時に作成する（友だち追加では作らない）。メッセージを1通もやり取りしていない相手とのルームは存在しない。
- 作成できるのは、どちらかが相手を友だちにしている（3.2.1）ときだけ（IDを知っているだけでは話しかけられない）。
- 2人で共有するドキュメントのため、uidは持たない（1章）。
- メッセージ（3.3.1）の置き場所としての役割のみを持つ。トーク一覧に必要な情報（最新メッセージ・未読数）は各アカウントの`chatList`（3.2.4）に持つ。
- ルーム作成時は、アプリが「ルーム・自分の`chatList`・最初のメッセージ」を同一リクエストで作る。相手の`chatList`は、メッセージ作成をきっかけにCloud Functions（`onMessageCreated`）が作る（3.2.4）。
- トーク画面（CHA-02）は、ルームがまだ無い場合はメッセージを読みに行かず、空のトークとして表示する（ルームが無いとメッセージの読み取りはルールで拒否されるため）。
- 読み取りは参加しているアカウントの保有ユーザのみで、ID指定の1件取得（get）に限る。一覧取得（list）は禁止し、トーク一覧は`chatList`から取る。
- 作成後は更新しない（ルールで更新・削除を禁止）。

#### 【データ構成】

> ドキュメントID：参加者2つのaccountIdを昇順ソートし`~`で連結（例：`alice~bob1`）

| フィールド       | 型        | 必須 | 初期値          | 説明                                                   |
| -------------- | --------- | --- | -------------- | ---------------------------------------------------- |
| chatRoomId     | string    | ○   | chatRoomId     | ドキュメントIDと同値。                                                   |
| participantIds | array     | ○   | 2人のaccountId  | 参加者2名のaccountId（昇順ソート済み、要素数2固定）。                        |
| createdAt      | timestamp | ○   | サーバー時刻     | ルーム作成日時（サーバータイムスタンプ）。                                    |

#### 【補足】

> トーク一覧での区分け（CHA-01）
>
> - 「通常のトーク」と「未確認のトークリクエスト」の区分けは、クライアント側で自分の`chatList`（`peerAccountId`・`lastMessage`・`lastMessageAt`・`blockedAt`）と`friends`・`blockedAccounts`から判定する。
>   - 相手が友だち → 通常
>   - 友だちでなく、メッセージあり → リクエスト（`blockedAt`がある場合は、`lastMessageAt`がそれより新しいときだけ。ブロック解除しただけでは出さない）
>   - 自分がブロック中 → 非表示

---



### 3.3.1 chatRooms/{chatRoomId}/messages

#### 【概要・方針】

「メッセージ」のサブコレクション。1ドキュメント＝メッセージ1通。

- Firestoreの自動採番IDをドキュメントIDとする。
- 読み取り・書き込みは、ルームに参加しているアカウントの保有ユーザのみ（6章）。送信者（`senderId`）は、自分が保有するアカウントに限る。
- 最初の送信時は、ルームと自分の`chatList`もメッセージと同一リクエストで作る（3.3）。
- 送信時は、メッセージ作成と同一リクエストで、自分の`chatList`の`lastMessage`・`lastMessageAt`を更新する（自分の一覧はすぐ変わる）。相手の`chatList`の更新と`unreadCount`の+1は、Cloud Functions（`onMessageCreated`）が行う（3.2.4）。
- 既読管理はメッセージ単位（`readBy`）。
- 送信取消は論理削除（`unsentAt`を付ける）とし、ドキュメントは物理削除しない。取り消した本文はCloud Functionsが管理者専用の`unsentMessageArchives`（3.4）に移し、メッセージからは削除する。
- 取得：CHA-02は`createdAt`降順で直近50件をリアルタイム購読し、それより過去はスクロール時に50件ずつ追加取得する。
- 知らない`type`のメッセージは、アプリを更新すれば読める案内を表示する（機能仕様書4.4.3）。
- メッセージの種類はテキスト（`text`）、画像（`image`）、スタンプ（`sticker`）、当日の定型連絡（`meetupStatus`、オフ会グループのみ。機能仕様書4.7.8.11）、アルバムの案内（`album`、3.13。機能仕様書4.4.9.2）。画像メッセージは画像1枚のみで、本文は持たない（動画はMVPスコープ外）。

#### 【データ構成】

> ドキュメントID：自動採番

| フィールド  | 型        | 必須 | 初期値            | 説明                                                                             |
| --------- | --------- | --- | ---------------- | ------------------------------------------------------------------------------ |
| messageId | string    | ○   | 自動採番ID        | ドキュメントIDと同値（作成前に採番したIDを入れる）。                                                   |
| senderId  | string    | ○   | 送信者のaccountId | 送信者のaccountId。                                                                 |
| type      | string    | ○   | `"text"`／`"image"` | メッセージの種類。旧データでフィールドが無い場合は`"text"`として扱う。 |
| text      | string    | △   | 入力値            | 本文（前後の空白を除いて1〜2000文字）。`type`が`"text"`のときのみ必須。画像メッセージには持たない。送信取消後は、Cloud Functionsが削除する（3.4へ退避）。 |
| imagePath | string    | △   | Storageのパス      | 画像のStorage上のパス（`chatRooms/{chatRoomId}/images/{messageId}.jpg`、7章）。`type`が`"image"`のときのみ必須。ダウンロードURLは保存しない（下記補足）。送信取消後は、Cloud Functionsが削除する（3.4へ退避）。 |
| imageWidth | number   | △   | 圧縮後の幅（px）    | 画像の幅。`type`が`"image"`のときのみ。読み込み前に縦横比の分かる枠を表示するため。 |
| imageHeight | number  | △   | 圧縮後の高さ（px）   | 画像の高さ。同上。 |
| stickerPackId | string | △   | 選んだパックのID    | スタンプのパックのID（1〜50文字）。`type`が`"sticker"`のときのみ必須。送信取消後は、Cloud Functionsが削除する（3.4へ退避）。 |
| stickerId | string    | △   | 選んだスタンプのID   | パックの中のスタンプのID（1〜50文字）。同上。画像はStorageの`stickers/{packId}/{stickerId}.webp`にある（3.9）。 |
| meetupStatus | string | △   | 押したボタン        | 当日の定型連絡の中身。`"late"`（遅れます）／`"arrived"`（着きました）／`"notFound"`（見つかりません）。`type`が`"meetupStatus"`のときのみ必須。文言は持たず、受け取った側の表示言語で出す。送れるのはオフ会グループ（`groupKind == "meetup"`）で`eventAt`があり、`createdAt`が`eventAt`の前後24時間以内のときだけ（6章）。送信取消後は、Cloud Functionsが削除する（3.4へ退避）。 |
| albumId   | string    | △   | アルバムのID       | アルバムの案内（`type`が`"album"`）のときのみ必須。そのアルバム（3.13）が存在すること（6章）。アルバムが消されても案内は残り、「削除されたアルバム」と表示する。 |
| albumEvent | string   | △   | 操作の種類         | `"created"`（作成）／`"added"`（追加）。同上。 |
| albumItemCount | number | △ | 追加できた件数     | 1〜50（1回の追加の上限）。同上。 |
| albumName | string    | △   | 送った時点の名前    | 1〜50文字。同上。 |
| createdAt | timestamp | ○   | サーバー時刻       | 送信日時（サーバータイムスタンプ）。                                                             |
| readBy    | array     | ○   | `[送信者]`        | 既読済みのaccountId一覧。送信時は送信者自身のみ。更新で追加できるのは、自分が保有する参加アカウント1件のみ（既存要素の削除・改ざんは不可。6章）。 |
| reactions | map       | －   | （なし）           | リアクション。accountIdをキー、絵文字を値とするmap（例：`{ "account1": "👍" }`）。1人1メッセージ1つまで（上書きで変更、キー削除で解除）。未リアクション時はフィールド自体が存在しない。 |
| hiddenFor | array     | －   | （なし）           | 「削除」（自分の画面のみ非表示）したaccountId一覧。相手側には影響しない。未削除時はフィールド自体が存在しない。                   |
| unsentAt  | timestamp | －   | （なし）           | 送信取消した日時（サーバー時刻）。取消していないメッセージにはフィールド自体が存在しない。付いたメッセージは双方の画面に表示しない。                 |

> ※必須列の「△」は、`type`によって必須かどうかが変わる項目。

#### 【補足】

> リアクション（reactionsフィールド）
>
> - キーをuidではなくaccountIdとしたのは、1uidが複数accountを持てるため（同一uidの2アカウント同士のチャットでキーが衝突する）。また、uidを他人に見せないため（1章）。
> - 絵文字は固定6種（👍❤️😂😮😢🙏）。ルールは値が16文字以下の文字列であることを検証する。1対1では、どちら向きでもブロック関係があると付け外しできない。
> - 新しく付けたときに、Cloud Functions（`onMessageReacted`）がメッセージの送信者に通知を送る（機能仕様書4.4.6.3）。付け替え・解除では送らない。

> 画像メッセージ
>
> - 送信の流れ：アプリがmessageIdを先に採番し、圧縮した画像をStorageの`chatRooms/{chatRoomId}/images/{messageId}.jpg`にアップロードしてから、`type: "image"`のメッセージを作る（最初の送信では、ルーム・自分の`chatList`も同一リクエストで作る。3.3）。
> - ダウンロードURLはFirestoreに保存しない。ダウンロードURLは、URLを知っていればStorageのルールに関係なく誰でも読めるため、保存しておくと参加者以外に漏れる経路が増える。表示時に、ルールで許可された参加者がSDK経由でURL（またはデータ）を取得する。
> - 送信取消：`onMessageUnsent`が、画像ファイルを管理者専用パスに移し、メッセージから`imagePath`を削除する（3.4）。

> 送信取消・削除
>
> - 送信取消（双方の画面から消える。プレースホルダーなし・時間制限なし）は、`unsentAt`を付ける論理削除とする（2026-09-17時点の「物理削除」から変更）。
>   - アプリは`unsentAt`（サーバー時刻）を付ける更新だけを行う。
>   - Cloud Functions（`onMessageUnsent`、`unsentAt`が付いたときに動く）が、本文等を`unsentMessageArchives/{chatRoomId}/messages/{messageId}`（3.4）にコピーし、メッセージから`text`・`imagePath`・`reactions`を削除する（画像メッセージは、画像ファイルも管理者専用のパスへ移す。7章）。
>   - 本文を残すと相手がアプリを通さずに読めてしまうため、メッセージには残さず、アプリから読めない場所に移す。
> - 削除（自分の画面のみ）は、`hiddenFor`への自分のaccountId追加による論理削除。

> 送信取消・削除のあとのトーク一覧
>
> - 送信取消：画面に痕跡を残さない方針のため、取り消したメッセージが一覧の最新メッセージだった場合は、Cloud Functions（`onMessageUnsent`）が、残っているメッセージの中で最も新しいもので双方の`chatList.lastMessage`・`lastMessageAt`を書き直す（残りが無ければ`lastMessage`を`null`）。取り消したメッセージが相手にとって未読（`readBy`に相手が無い）だった場合は、相手の`unreadCount`を1減らす（0未満にはしない）。
> - 削除（自分の画面のみ）：削除したメッセージが自分の一覧の最新メッセージだった場合は、アプリが自分の`chatList.lastMessage`を、自分に見えている最も新しいメッセージで書き直す（無ければ`null`）。相手の一覧は変わらない。

---



### 3.4 unsentMessageArchives

#### 【概要・方針】

「送信取消の保管」のコレクション。1ドキュメント＝送信取消したメッセージ1通の本文。

- パスは`unsentMessageArchives/{chatRoomId}/messages/{messageId}`。messageIdはアプリが決められ、ルームが違えば重なるので、ルームごとに分ける（重なると本文の削除の阻止や保管の差し替えに使える）。以前に取り消した分は`unsentMessageArchives/{messageId}`に残っている。
- 開示請求等に備え、送信取消したメッセージの本文・画像を運営者が保管する。画像ファイルは、Storageの管理者専用パス`unsentMessageArchives/{chatRoomId}/{messageId}.jpg`に移す（7章）。
- アプリからの読み書きはすべて禁止する（6章）。書き込むのはCloud Functions（`onMessageUnsent`）、読めるのはFirebaseコンソール・Admin SDK（運営者）のみ。
- 保管期間は、取り消した日から3年（プライバシーポリシー6.4）。`processDataRetention`（1時間ごと、`data_retention.js`）が`archivedAt`で選んで、画像ごと消す。運営者がコンソールで`legalHold: true`を足したものは消さない。

#### 【データ構成】

> ドキュメントID：取り消したメッセージのmessageId

| フィールド   | 型        | 必須 | 初期値          | 説明                                   |
| ---------- | --------- | --- | -------------- | ------------------------------------ |
| messageId  | string    | ○   | messageId      | ドキュメントIDと同値。                          |
| chatRoomId | string    | ○   | 元のルームID      | 取り消したメッセージのルーム。                       |
| senderId   | string    | ○   | 元の送信者        | 送信者のaccountId。                        |
| type       | string    | ○   | 元の種類         | `"text"`／`"image"`／`"sticker"`／`"meetupStatus"`。                        |
| meetupStatus | string  | △   | 元の中身         | 取り消した当日の定型連絡の中身（3.3.1）。当日の定型連絡のみ。 |
| text       | string    | △   | 元の本文         | 取り消したメッセージの本文（テキストメッセージのみ）。 |
| imagePath  | string    | △   | 移動先のパス      | 取り消した画像の移動先（Storageの`unsentMessageArchives/{chatRoomId}/{messageId}.jpg`、7章）。画像メッセージのみ。 |
| createdAt  | timestamp | ○   | 元の送信日時      | 元のメッセージの送信日時。                         |
| unsentAt   | timestamp | ○   | 取消日時         | 送信取消した日時。                             |
| archivedAt | timestamp | ○   | サーバー時刻       | 保管した日時。                               |


---



### 3.5 userSecrets

#### 【概要・方針】

「引き継ぎパスワード」のコレクション。1ドキュメント＝1ユーザ。

- uidをドキュメントIDとする。
- 電話番号が解約されて他人に再割り当てされても、SMS認証だけでは前の持ち主のデータにアクセスできないようにするための、引き継ぎパスワードのハッシュを置く（機能仕様書4.1.4）。
- アプリからの読み書きはすべて禁止する（6章）。読み書きするのはCloud Functions（`setTransferPassword`・`verifyTransferPassword`）のみ。退会（`withdrawUser`）で削除する。

#### 【データ構成】

> ドキュメントID：uid

| フィールド        | 型        | 必須 | 初期値      | 説明                                                   |
| --------------- | --------- | --- | ---------- | ---------------------------------------------------- |
| uid             | string    | ○   | uid        | ドキュメントIDと同値。                                           |
| passwordHash    | string    | ○   | -          | パスワードのハッシュ（scrypt、Base64）。                                |
| salt            | string    | ○   | ランダム      | ハッシュのソルト（16バイト、Base64）。登録・変更のたびに作り直す。                  |
| failedAttempts  | number    | ○   | 0          | 続けて間違えた回数。5回でロックし、0に戻す。                               |
| lockedUntil     | timestamp | －   | `null`     | ロックの期限（5回続けて間違えてから15分）。                                |
| updatedAt       | timestamp | ○   | サーバー時刻   | 登録・変更日時。                                                |
| transferResetAt | timestamp | －   | -          | パスワードを忘れた場合の再設定（機能仕様書4.1.4.3）で、以前のデータを削除する日時（申請から7日後）。過ぎると`processDataRetention`が退会と同じ処理をする。取り消すと消す。 |
| transferResetRequestedAt | timestamp | －   | -  | 再設定を申請した日時。                                               |

#### 【補足】

> 確認の状態（カスタムクレーム）
>
> - パスワードを確認できたかは、Firebase Authのカスタムクレームで表す（Firestoreには置かない）。
>   - `tp`：`true`なら引き継ぎパスワードを登録済み。
>   - `va`：パスワードを確認できたセッションのログイン時刻（IDトークンの`auth_time`、秒）の一覧（新しいもの10件まで）。
> - firestore.rules・storage.rulesは、`tp`が`true`のユーザには「今のセッションの`auth_time`が`va`にある」ことを求める（6章）。新しい端末でSMS認証すると新しい`auth_time`になるため、パスワードを確認するまで何も読み書きできない。
> - パスワードを登録・確認すると、そのセッションの`auth_time`を`va`に加える。登録した時点で、登録した端末以外のログイン中の端末は、次にIDトークンが更新されたとき（最大1時間）から未確認になり、次回の起動時にパスワードの入力を求められる。
> - SMS再認証（パスコードを忘れた場合）・電話番号の変更では`auth_time`が新しくなる。そのため、再認証の前のIDトークンをCloud Functions（`carryOverTransferVerification`）が検証し、それが確認済みのセッションなら、新しいセッションも確認済みとして引き継ぐ。
>
> 管理者（カスタムクレーム）
>
> - `admin`：`true`なら管理者。SET-01にログアウトの項目を出す（機能仕様書4.1.7）。サーバー（Admin SDK）でしか設定できず、Cloud Functionsにも設定する処理は持たせない。アプリは、ログイン状態が変わるたびと前面に戻るたびに読み直す。
> - カスタムクレームは丸ごと置き換わるため、`tp`・`va`を書き換える処理も`admin`を設定する手順も、既存のクレームを残したまま書き換える。

---

### 3.6 reports

#### 【概要・方針】

通報のコレクション（機能仕様書4.3.6）。1ドキュメント＝1件の通報。

- 自動採番IDをドキュメントIDとする。
- 通報者・通報対象はアカウントIDで持ち、uidは持たない（1章）。
- アプリからは作成のみ許可し、読み取り・更新・削除はすべて禁止する（6章）。運営者がFirebaseコンソールで確認し、対応する（利用規約第7条のアカウントの利用の制限・停止等）。
- 通報者・通報対象のアカウントの削除・退会では削除しない（対応の記録として残す）。
- 作成すると`onReportCreated`が`status`を`open`にして、`REPORT_ALERT_WEBHOOK_URL`へ通知する。通知の本文は通報のID・理由・種類だけで、アカウントIDと詳しい内容は含めない。通知に失敗したらトリガーの再試行に任せる。
- 対応は運営者がサーバー側の道具で行う。

#### 【データ構成】

> ドキュメントID：自動採番

| フィールド            | 型        | 必須 | 初期値    | 説明                                                                 |
| ------------------- | --------- | --- | -------- | ------------------------------------------------------------------ |
| reportId            | string    | ○   | 自動採番ID | ドキュメントIDと同値。                                                         |
| reporterAccountId   | string    | ○   | -        | 通報したアカウントのID（自分が保有するアカウントであること）。                                  |
| targetAccountId     | string    | ○   | -        | 通報されたアカウントのID（実在し、通報者自身でないこと）。                                    |
| reason              | string    | ○   | -        | 理由。`spam`（スパム・宣伝）／`harassment`（嫌がらせ・いじめ）／`impersonation`（なりすまし）／`inappropriate`（不適切なコンテンツ）／`other`（その他）。 |
| detail              | string    | －   | -        | 詳しい内容（任意、500文字以内）。空なら持たない。                                         |
| chatRoomId          | string    | －   | -        | メッセージから通報した場合の、通報者と相手のチャットルームのID。                                  |
| messageId           | string    | －   | -        | メッセージから通報した場合の、対象のメッセージのID（相手が送ったメッセージであること）。                     |
| albumId・albumItemId | string   | －   | -        | アルバムの項目（3.13）から通報した場合の、アルバムと項目のID。`chatRoomId`も持ち、通報者が参加するトークにある、相手が追加した項目であること。`messageId`とは同時に持たない。 |
| preservedPaths      | array     | －   | -        | アルバムの項目の通報で、運営者の確認用に複製したファイルのStorageのパス（`reportedAlbumItems/{reportId}/…`）。項目が消されても残る。Cloud Functions（`onAlbumItemReported`）のみ。 |
| createdAt           | timestamp | ○   | サーバー時刻 | 通報日時。                                                              |
| status              | string    | －   | -        | `open`／`handled`。Cloud Functions・運営者のみ。                         |
| notifiedAt          | timestamp | －   | -        | 運営者へ通知した日時。Cloud Functionsのみ。                               |
| handledAt           | timestamp | －   | -        | 対応した日時。運営者のみ。                                                |
| action              | string    | －   | -        | 対応の内容。運営者のみ。                                                  |
| legalHold           | boolean   | －   | -        | `true`なら保全中（調査中の事案・法令に基づく請求への対応中）。保管期間を過ぎても消さない。`tools/moderate.js`の`hold`・`unhold`だけが書く。 |

#### 【保管期間】

- 通報の日から3年を過ぎると、`processDataRetention`（1時間ごと、`data_retention.js`）が、`preservedPaths`のファイルごと消す（プライバシーポリシー6.4）。`legalHold`が`true`なら消さない。

### 3.10 withdrawalRecords

退会の記録。通報された人が退会しても持ち主を確かめられるよう、また退会した人からの削除の依頼で本人を確かめられるよう、退会の処理（`withdrawUid`）が削除の前に作る。ドキュメントIDはuid。保持日数は`WITHDRAWAL_RECORD_RETENTION_DAYS`（`firebase/functions/.env.*`、本番は365日。プライバシーポリシー6.2）で、未設定なら作らない。`purgeAt`を過ぎるとFirestoreのTTLが消す。

| フィールド | 型 | 必須 | 説明 |
|---|---|---|---|
| uid | string | ○ | ドキュメントIDと同値。 |
| accountIds | array\<string\> | ○ | 保有していたアカウントのID（削除済みを含む）。 |
| phoneHash | string | | 電話番号の鍵付きのハッシュ（HMAC-SHA256、16進の小文字。鍵はSecret Managerの`PHONE_HASH_KEY`）。電話番号そのものは持たない。 |
| phoneHashVersion | number | | `phoneHash`の計算の版。鍵付きのハッシュは`2`（`firebase/functions/phone_hash.js`）。`phoneHash`があるときだけ持つ。 |
| withdrawnAt | timestamp | ○ | 退会の日時。 |
| purgeAt | timestamp | ○ | 消す日時。 |

### 3.11 bannedPhones

再登録を止めた電話番号。ドキュメントIDは`phoneHash`（電話番号の鍵付きのハッシュ。計算は3.10と同じ）。ある番号ではFirebase Authのユーザーを作れず、ログインもできないので、退会して作り直せない。鍵はルールでは使えないため、照合はAuthのブロッキング関数（`beforeUserCreatedBlockBannedPhone`・`beforeUserSignedInBlockBannedPhone`）が行い、アプリには停止中として出す。`tools/moderate.js`だけが書く。フィールドは`phoneHash`・`phoneHashVersion`・`reason`・`reportId`・`bannedAt`。塩なしのSHA-256の値は、電話番号の桁数が限られて総当たりで戻せるため使わない。

### 3.12 moderationActions

運営者の対応の記録。自動採番IDで、フィールドは`actionId`・`action`・`uid`・`accountIds`・`reason`・`reportId`・`createdAt`。`tools/moderate.js`だけが書く。

---

### 3.14 friendInviteKeys・accountInviteKeys

#### 【概要・方針】

友だちの招待キー（機能仕様書4.3.1.4）。`allowIdSearch: false`のアカウントにも、本人が渡したマイQRコード・招待リンクからは友だち追加できるようにするためのもの。

- アカウントごとに1つ。32バイトの乱数のBase64URL（43文字。グループの招待トークン（8章）と同じ形式）。
- 作るのはCloud Functions（`getFriendInviteKey`）だけ。本人が呼ぶと、無ければ作って返す。アプリからの読み書きはすべて禁止（本人も読めない。ルールのget()からは読む）。
- アカウントの論理削除（退会を含む）で、Cloud Functions（`onAccountSoftDeleted`）が両方を消す。
- 作り直す操作は今は無い（キーを入れ替えるときは`accountInviteKeys`で古いキーを引いて消す）。

#### 【データ構成】

> `friendInviteKeys/{key}`（ドキュメントID：招待キー）

| フィールド   | 型        | 必須 | 説明 |
| ----------- | --------- | --- | ---- |
| key         | string    | ○   | ドキュメントIDと同値。 |
| accountId   | string    | ○   | キーの持ち主のアカウント。 |
| createdAt   | timestamp | ○   | 作成日時。 |

> `accountInviteKeys/{accountId}`（ドキュメントID：アカウントID）

| フィールド   | 型        | 必須 | 説明 |
| ----------- | --------- | --- | ---- |
| accountId   | string    | ○   | ドキュメントIDと同値。 |
| key         | string    | ○   | 今の招待キー。 |
| createdAt   | timestamp | ○   | 作成日時。 |

#### 【補足】

> 公開済みのアプリ（1.1.1以前）との違い
>
> - 1.1.1以前のマイQRコード・招待リンクにはキーが無い。`allowIdSearch: false`のアカウントのキーの無いQRコード・招待リンクからは、友だち追加できなくなる（`true`のアカウントは今までどおり）。
> - 1.1.1以前のアプリはキーを読まず、添えないため、`allowIdSearch: false`の相手をQRコード・招待リンクから追加できない。

---

### 3.7 appConfig

#### 【概要・方針】

アプリ全体の設定のコレクション。現在は`appConfig/version`の1件のみで、強制アップデート（機能仕様書4.1.6）に使う。

- ログイン前に判定するため、誰でも読める。
- 書き込みはFirebaseコンソールからのみ。古いアプリを止めるときに`minimumVersion`を上げる。
- ドキュメントが無いときは、更新不要として動く。

#### 【データ構成】

> ドキュメントID：`version`

| フィールド       | 型     | 必須 | 初期値 | 説明 |
| -------------- | ------ | --- | ---- | ---- |
| configId       | string | ○   | `version` | ドキュメントIDと同値。 |
| minimumVersion | string | ○   | - | 動かせる最低のアプリのバージョン（`1.1.0`の形式）。 |
| iosStoreUrl    | string | －   | - | App Storeのアプリのページ。 |
| androidStoreUrl | string | －  | - | Google Playのアプリのページ。 |

---



### 3.8 billingCustomers

#### 【概要・方針】

- RevenueCatの顧客と、それを使うユーザ（uid）の対応づけ。
- ドキュメントIDは`billingId`（サーバーが発行するUUID v4）。RevenueCatのApp User IDに使い、uidは社外へ渡さない。
- アプリからの読み書きはすべて禁止する（Cloud Functionsのみ）。アプリは`users/{uid}.plan`だけを見る。
- 内容は常にRevenueCatのREST APIの現在の状態で上書きする。

#### 【データ構成】

| フィールド名 | 型 | 必須 | デフォルト | 説明 |
|---|---|---|---|---|
| billingId | string | ○ | - | ドキュメントIDと同値。 |
| uid | string | ○ | - | この顧客を使うユーザ。 |
| plan | string | ○ | "free" | 今与えるプラン（`grade1`／`grade2`／切れていれば`free`）。 |
| expiresAt | timestamp | | null | 現在の期間の終わり。無料ならnull。 |
| updatedAt | timestamp | ○ | サーバー時刻 | 更新日時。 |

#### 【補足】

> `users/{uid}.plan`の決め方
>
> - `uid`が一致するドキュメントの`plan`のうち、一番高いものを`users/{uid}.plan`にする（`recomputeUserPlan`）。プランが変わると`keptAccountsChosenAt`を消す。
> - 購入が別のユーザへ移ると、TRANSFERのWebhookで移動元・移動先の両方を取り直す。
> - 退会時（`withdrawUser`）に、RevenueCatの顧客を削除し、ドキュメントも削除する。RevenueCatの削除に失敗しても退会は止めない。ストアの契約は残る。
> - 発行していないIDのWebhookは無視する（REST APIにも問い合わせない）。
> - App Review・TestFlight・Playのテストトラックの購入も、本番の購入と同じように受け付ける。

---

### 3.9 stickerPacks

#### 【概要・方針】

運営者が配信するスタンプのパックの一覧（機能仕様書4.4.8）。メッセージにはIDだけを載せ、画像はStorageの`stickers/{packId}/{stickerId}.webp`から取得する。

- ログイン済みなら読める。書き込みはサーバー側からのみ（手順は`firebase/stickers/README.md`）。
- パックはドキュメントIDの順に並べる。ドキュメントが無いときは、スタンプボタンを出さない。
- 画像は512x512pxの透過WebP（1枚512KB未満）。表示はトークの画像と同じくダウンロードURLを`Image.network`で読むため、ディスクには残らない。
- 送信済みのメッセージがIDで画像を指すため、公開後のIDは変えない。

#### 【データ構成】

> ドキュメントID：`packId`（英数字・`_`・`-`の1〜50文字）

| フィールド   | 型       | 必須 | 初期値 | 説明 |
| ---------- | -------- | --- | ---- | ---- |
| packId     | string   | ○   | - | ドキュメントIDと同値。 |
| stickerIds | string[] | ○   | - | スタンプのID（形式は`packId`と同じ）。選択シートにはこの順に並べる。 |

### 3.13 chatRooms/{chatRoomId}/albums（トークのアルバム）

#### 【概要・方針】

トークのアルバム（機能仕様書4.4.9）。1ドキュメント＝アルバム1つ。その下の`items`が画像・動画1件ずつ。1対1・普通のグループ・オフ会グループのすべてのルームの下に置く。

- 読み取りは参加者のみ。グループでも参加前に作られたアルバムを読める（メッセージと違い`joinedAt`で絞らない）。
- 作成・名前の変更・項目の追加は、参加者が自分の保有するアカウントの名義で行う。読み取り専用（4.2.1.3）・1対1のブロック関係・閉じたオフ会グループ（8.17）では拒む（6章、`firebase/firestore.rules`）。
- 削除は、アルバムは作成者（グループで作成者が抜けていれば残った参加者）、項目は追加した本人。読み取り専用・ブロック中でもできるが、閉じたオフ会グループではできない（読むだけ）。
- 件数・使用量・カバーは、アプリが書けない集計値で、Cloud Functions（`firebase/functions/albums.js`）が書く。集計はStorageの実際の大きさで行い、アプリの申告値（`sizeBytes`）は使わない。上限（1トーク100アルバム・1アルバム1000件・1トーク合計10GB）はルールがこの集計値で判定する。
- 項目・アルバムを消すと、Cloud Functions（`onChatAlbumItemDeleted`・`onChatAlbumDeleted`）がStorageのファイルを消し、集計から除く。
- 1対1の最初のトークでアルバムを作るときは、ルーム（3.3）を同じリクエストで作る。
- 期限で消えるのはオフ会グループだけ。閉じてから30日（`purgeAt`、8.17）で、`processMeetupLifecycle`がアルバム・項目・Storageの`chatRooms/{chatRoomId}/albums/`の下をまとめて消す（通報があっても消す。通報された項目は`reportedAlbumItems`に複製済み）。普通のグループ・1対1は期限で消えない。最後の参加者が退会したグループは、ほかの記録と同じく消す（8.9。通報があれば残す）。

#### 【データ構成】

`chatRooms/{chatRoomId}/albums/{albumId}`（自動採番ID）

| フィールド | 型 | 必須 | 説明 |
|---|---|---|---|
| albumId | string | ○ | ドキュメントIDと同値。 |
| name | string | ○ | アルバムの名前（1〜50文字）。参加者が変えられる。 |
| createdByAccountId | string | ○ | 作ったアカウント。 |
| createdAt | timestamp | ○ | 作った日時（サーバー時刻）。 |
| updatedAt | timestamp | ○ | 作成・項目の追加と削除の日時（サーバー時刻）。一覧はこの降順。項目の分はCloud Functionsが書く。 |
| updatedByAccountId | string | － | 名前を最後に変えたアカウント（ルールで操作した人を確かめるため）。 |
| itemCount | number | － | 項目の数。Cloud Functionsのみ。 |
| usageBytes | number | － | 項目のファイルの大きさの合計（バイト）。Cloud Functionsのみ。 |
| coverThumbnailPath | string | － | カバーにするサムネイルのStorageのパス（最も新しく数えた項目）。項目が無ければ持たない。Cloud Functionsのみ。 |

`chatRooms/{chatRoomId}/albums/{albumId}/items/{itemId}`（自動採番ID。作成後は変えない）

| フィールド | 型 | 必須 | 説明 |
|---|---|---|---|
| itemId | string | ○ | ドキュメントIDと同値。 |
| albumId | string | ○ | 親のアルバムのID。 |
| type | string | ○ | `"image"`／`"video"`。 |
| path | string | ○ | 本体のStorageのパス。画像は`chatRooms/{chatRoomId}/albums/{albumId}/{itemId}.jpg`、動画は`….mp4`（7章。ルールがこの形と一致することを確かめる）。 |
| thumbnailPath | string | ○ | サムネイルのパス（`…/{itemId}_thumb.jpg`）。 |
| width・height | number | ○ | 変換後の大きさ（px）。 |
| durationMs | number | △ | 動画の長さ（ミリ秒）。動画のときだけ持つ。 |
| sizeBytes | number | ○ | 本体とサムネイルの大きさの合計。アプリの申告値で作り、Cloud Functionsが実際の大きさで書き直す。 |
| counted | boolean | － | 集計に入れた印（二重に数えないため）。Cloud Functionsのみ。 |
| uploaderAccountId | string | ○ | 追加したアカウント。 |
| createdAt | timestamp | ○ | 追加した日時（サーバー時刻）。 |

ルーム（3.3・8.2）には、Cloud Functionsだけが書く集計値`albumCount`（アルバムの数）・`albumUsageBytes`（すべてのアルバムのファイルの合計）を足す。

トークの案内は通常のメッセージ（3.3.1の`type: "album"`）として送る。

---


## 4. ID設計


| 対象                                 | 生成規則                                                                                                                             |
| ---------------------------------- | -------------------------------------------------------------------------------------------------------------------------------- |
| users/{uid}                        | Firebase Authenticationが発行するuidをそのまま使用。                                                                                          |
| accounts/{accountId}               | アカウント作成時に利用者が入力する。半角英数字（大文字可）と`.` `-` `_`のみ、4〜20文字（`^[a-zA-Z0-9._-]{4,20}$`）。予約IDは不可（下記）。事前チェックの後、作成時のルール（存在チェック）が最終的な一意性保証となる。 |
| friends/{friendAccountId}          | 相手のaccountIdをそのままドキュメントIDとする。                                                                                                    |
| fcmTokens/{token}                  | FCMトークン文字列をそのままドキュメントIDとする。                                                                                                      |
| blockedAccounts/{blockedAccountId} | ブロックした相手のaccountIdをそのままドキュメントIDとする。                                                                                              |
| blockedAccountDates/{blockedAccountId} | ブロックした相手のaccountIdをそのままドキュメントIDとする。 |
| ownedAccounts/{accountId}          | 保有するアカウントのaccountIdをそのままドキュメントIDとする。                                                                                             |
| chatList/{chatRoomId}              | 対応するチャットルームのchatRoomIdをそのままドキュメントIDとする。                                                                                           |
| chatRooms/{chatRoomId}             | 参加者2アカウントIDを昇順ソートし`~`で連結（例：`alice~bob1`）。                                                                                        |
| messages/{messageId}               | Firestoreの自動採番IDを使用。                                                                                                             |
| unsentMessageArchives/{chatRoomId}/messages/{messageId}  | 取り消したメッセージのmessageIdをそのままドキュメントIDとする。                                                                                         |


**予約ID**：運営者へのなりすまし（「support」を名乗る詐欺等）防止のため、以下はアカウントIDに使えない。大文字小文字・記号（`.` `-` `_`）の違いで回避されないよう、小文字化して記号を除いた形で照合する（例：`Sup.port`も不可）。リストは`firebase/firestore.rules`（`isReservedAccountId`）と`lib/config/reserved_account_ids.dart`の2箇所にあり、変更時は両方を更新する。

- 汎用語：admin, administrator, official, support, help, helpdesk, staff, system, root, security, info, contact, moderator, operator, unei
- アプリ名と派生：orto, ortoapp, ortoofficial, officialorto, ortosupport, ortoteam, ortostaff, ortoadmin



### 4.1 QRコードのエンコード形式（友だち追加用、QRC-01）

**フォーマット**：

```
https://{招待リンクのドメイン}/invite/{accountId}
```

- 友だちの招待リンク（機能仕様書4.3.5）と同じURLをエンコードする。本番は`https://orto.example.com/invite/{accountId}`。iPhoneの標準のカメラで読んでも、Universal Links（AndroidはApp Links）でアプリが開き（入っていなければ案内ページ）、アプリの外から届いた招待としてアカウントを選んでから友だち追加に進む（機能仕様書4.3.5.2）。
- 以前は`orto://friend/{accountId}`をエンコードしていた。`orto://`はOSのURLスキームとして登録していないため、標準のカメラでは開けなかった。配った・保存した古いQRコードを読めるよう、アプリのスキャナー（QRC-01）は古い形も受け付ける。
- 読み取り側（QRC-01）は、その環境の招待リンク（2つのドメインのどちらでも）の`/invite/{accountId}`か、`orto://friend/{accountId}`の場合だけ、accountIdでFirestoreを検索する。それ以外は「見つからない」扱いとし、検索クエリ自体を発生させない（accountIdの生文字列だけのQRや、他アプリのQRを、友だち候補として誤って解決しないため）。
- アプリのスキャナーで読んだ招待は、アプリの中の操作として、QRC-01を開いたアクティブアカウントで固定する（アカウントを選ぶシートは出さない。基本原則）。
- 自分自身のID・ブロック関係にある相手・退会済みの相手は、読み取りエラー（自分自身／見つからない）とする。

---



## 5. インデックス設計


| コレクション          | クエリ内容                                       | インデックス              |
| --------------- | ------------------------------------------- | ------------------- |
| ownedAccounts   | createdAt昇順（自分のアカウント一覧）                      | 単一フィールドインデックス（自動作成） |
| ownedAccounts   | コレクショングループでaccountId等価（Cloud Functionsのみ）       | コレクショングループ範囲の単一フィールドインデックスを明示的に有効化 |
| chatList        | lastMessageAt降順（トーク一覧・未読集計）                      | 単一フィールドインデックス（自動作成） |
| messages        | createdAt降順 + limit／startAfter              | 単一フィールドインデックス（自動作成） |
| friends         | addedAt降順                                   | 単一フィールドインデックス（自動作成） |
| friendRequests  | createdAt降順（FRI-01の友だち申請）                  | 単一フィールドインデックス（自動作成） |
| friendRequests・sentFriendRequests | コレクショングループでchatRoomId等価（Cloud Functionsのみ。オフ会グループの片付け） | コレクショングループ範囲の単一フィールドインデックスを明示的に有効化 |
| friendRequests・sentFriendRequests | expiresAt（TTL） | TTLの設定（インデックスは作らない） |
| chatRooms | closeState等価 + closesAt昇順（Cloud Functionsのみ。期限の前の知らせ・閉じる、8.17） | 複合インデックス |
| chatRooms | closeState等価 + purgeAt昇順（Cloud Functionsのみ。30日後の片付け、8.17） | 複合インデックス |
| chatRooms | attendanceReminderAt ≦ 今（Cloud Functionsのみ。出欠の自動の催促、8.18） | 単一フィールドインデックス（自動作成） |


※Firestoreでは、インデックスがない検索は”失敗”する。

複合インデックス・コレクショングループ範囲のインデックスは`firebase/firestore.indexes.json`にて明示的に定義し、リポジトリで管理する。

---



## 6. Firestoreセキュリティルール

保有ユーザの判定を`users/{uid}/ownedAccounts`（3.1.1）の存在で行い、他人が読めるドキュメントにuidを置かずにアクセス制御する（1章）。

- 保有ユーザの判定：`isOwnerOfAccount(accountId)`＝「`users/{自分のuid}/ownedAccounts/{accountId}`が存在し、そのアカウントが削除済みでないか」。削除すると`accountCount`が減るので、削除済みを動かせると上限と読み取り専用を回避できる。
- 一覧取得（list）を許すのは、パスのaccountId・uidで保有ユーザを判定できる自分配下のコレクション（`ownedAccounts`・`friends`・`blockedAccounts`・`blockedAccountDates`・`fcmTokens`・`chatList`・`friendRequests`・`sentFriendRequests`）のみ。`accounts`・`chatRooms`は1件取得（get）のみとする。
- メッセージの送信者のなりすまし防止：`senderId`が自分の`ownedAccounts`にあり、かつルームの参加者であること（同一ユーザ配下の別アカウントへのなりすましもこれで防げる）。
- `accounts`の`photoURL`・`backgroundURL`は、`null`か、このプロジェクトのバケットにある自分のアカウントの画像のURLだけを受け付ける（7.1）。更新では、値を変えるときだけ検証する（古い値が残っていても、ほかの項目の編集を止めない）。
- `chatRooms`の存在しないドキュメントの取得は、1対1のIDなら当事者だけに許す（第三者に、拒否と成功の差からルームの有無が分からないようにする）。`~`を含まないIDは推測できない乱数のグループなので、存在しない場合の判定をしない。
- `accounts`作成時は、同一リクエストでの`ownedAccounts`の作成、IDの形式、予約IDでないこと、`users.accountCount`の+1・`lastCreatedAccountId`の一致とプラン別の上限（3.1）以内であることを検証する。`ownedAccounts`は、まだ存在しないアカウントIDに限り、`accounts`と同一リクエストでのみ作成できる（3.2【補足】）。
- 送信取消は`unsentAt`の付与（論理削除）のみ許可し、メッセージの物理削除は禁止する。取消済みのメッセージはアプリから更新できない。`unsentMessageArchives`はアプリからの読み書きをすべて禁止する（3.3.1・3.4）。
- 相手の`chatList`はアプリから書けない（Cloud Functionsが更新する）。自分の`chatList`の`unreadCount`は、アプリからは0にする更新のみ許可する。
- ブロック関係にあるAccount同士の友だち追加・ルーム作成・メッセージ送信・1対1のリアクションは拒否する（3.2.3）。
- 友だち申請（3.2.5・3.2.6）：`friendRequests`は保有ユーザが読め、ブロックのバッチで消せる（そのバッチで申請してきた相手の`blockedAccounts`を作っていること）。`sentFriendRequests`は保有ユーザが読めるだけ。どちらもアプリから作成・更新はできない（Cloud Functionsのみ）。
- 既読（`readBy`）・リアクション（`reactions`）・削除（`hiddenFor`）の更新は、自分が保有する参加アカウントの分だけを変更できる（`readBy`・`hiddenFor`は自分のaccountIdの追加のみ。相手の既読を消す・相手を既読にする等はできない）。
- メッセージの作成時は、同じリクエストで`sendCounters/current`（3.1.2）を+1し、上限以内であることを検証する。
- メッセージの作成時は、`type`に応じた項目の組み合わせを検証する（`text`は本文のみ、`image`は`imagePath`・`imageWidth`・`imageHeight`のみで、`imagePath`が`chatRooms/{chatRoomId}/images/{messageId}.jpg`と一致すること）。本文は10,000文字まで（入力の上限は2,000文字で、絵文字の結合による数え方の差を見込む）、画像の大きさは1〜100,000の整数。
- 1対1のメッセージの作成時も、項目を`messageId`・`senderId`・種類ごとの項目・`createdAt`・`readBy`に限り、`createdAt`はサーバー時刻、`readBy`は送信者だけとする（`isValidDirectMessage`）。受信者の`chatList`に写る値を縛るため。
- アプリの解析（`Message`・`ChatListEntry`・`Account`）は型の違う値を無いものとして読み、それでも読めない項目は飛ばす。1件の不正な値で一覧やトークの全体を止めないため。
- すべてのコレクションで、ドキュメントIDと同値のフィールドがドキュメントIDと一致することを、作成・更新時に検証する（1章）。
- `appConfig`（3.7）は誰でも読めるが、アプリからは書けない。
- `stickerPacks`（3.9）はログイン済みなら読めるが、アプリからは書けない。
- `reports`（3.6）は、自分が保有するアカウントを通報者とする作成のみ許可する（実在する他のアカウントが対象であること、理由が決められた値であること、メッセージから通報した場合はそのメッセージが通報者と相手のルームにあり相手が送ったものであることを検証する）。読み取り・更新・削除は禁止する。
- 引き継ぎパスワードを登録済みのユーザは、パスワードを確認できたセッションからのみ読み書きできる（すべてのルールの前提となる`isSignedIn()`で判定。3.5）。`userSecrets`はアプリからの読み書きをすべて禁止する。
- グループ（`type: "group"`のルーム）の判定：
  - 参加の判定は`users/{自分のuid}/groupMemberships/{chatRoomId}`の存在で行う（8.3）。`type`が`"group"`でないルームは1対1の判定のまま。
  - `chatRooms`の読み取りは参加者のみ。作成・変更・削除はアプリから不可（Cloud Functionsのみ）。
  - `messages`の読み取りは`createdAt`が`groupMemberships.joinedAt`以降のものだけ。一覧はアプリが同じ条件の`where`を付けて取得し、付けないクエリは拒否される。
  - `messages`の作成では、ブロックの判定をしない（機能仕様書4.7.6）。`createdAt`はサーバー時刻に限り（参加前の履歴の境界にするため）、使える項目を内容の項目に絞る（`system`の項目・`readBy`を書けない）。
  - `messages`の更新では、`system`は更新不可、`readBy`の更新は不可、参加前のメッセージは更新不可。リアクションは`reactedBy`を同時に書き、`reactedBy`が参加者かつ自分のアカウントで、変更したキーが`reactedBy`だけであること。`hiddenFor`は末尾に自分のアカウントを1件足すのみ（`isOwnSlotOnlyChange`は使えない。ルールの`Set`は要素を取り出せないため）。
  - `members`の読み取りは参加者のみ。更新は本人の`lastReadAt`を`request.time`にするのみ。作成・削除は不可。
  - `groupMemberships`は本人、`groupRequests`は保有ユーザのみ読める。どちらも書き込み不可。`groupInvites`は読み書きとも不可。
  - オフ会グループの`joinRequests`（参加の申請と答え）は主催チームの人だけが読める（`organizerIds`と本人の`groupMemberships.accountIds`の重なりで判定。8.16）。`joinApplications`は保有ユーザのみ読める。どちらも書き込み不可。
  - `chatList`のグループの行はアプリから作れず、`type`・`name`・`photoURL`・`memberCount`も変えられない。
  - `reports`は、メッセージの通報なら通報者が参加者で送信者が通報対象であること、グループの通報（`targetChatRoomId`）なら通報者が参加者であることを検証する。
- ルール内の`get()`・`exists()`は1リクエストあたりの上限（単体の書き込み10回、バッチ20回）があるため、判定は必要最小限にする。

ルールの正は`firebase/firestore.rules`とし、本書にはルールのコードを載せない。ルールのテストは`firebase/rules-test`にあり、`npm test`でエミュレータを起動して実行する（デモ用のプロジェクトで動き、実際の環境には接続しない）。



---



## 7. Storage設計


| パス                                  | 用途       | アクセス制御                                                  |
| ----------------------------------- | -------- | ------------------------------------------------------- |
| accounts/{accountId}/profile.jpg    | プロフィール画像 | 読み取り：サインイン済み全員。書き込み：当該アカウントの保有ユーザのみ（5MB未満・画像のみ）。削除：不可。 |
| accounts/{accountId}/background.jpg | 背景画像（JPEGまたはGIF。種類は`contentType`で区別し、ファイル名は固定） | 同上。                                                     |
| chatRooms/{chatRoomId}/images/{messageId}.jpg | トークの画像 | 読み取り：そのルームの参加者（1対1はルームIDに含まれる2つのアカウントのどちらかの保有ユーザ、グループは`groupMemberships`のある利用者。グループは1件取得のみ）のみ。書き込み：同じく参加者のみ、新規作成のみ（上書き不可）、10MB未満・画像のみ。削除：不可。 |
| chatRooms/{chatRoomId}/photo/{fileName} | グループの画像 | 読み取り：参加者のみ。書き込み：参加者のみ、新規作成のみ（上書き不可。`updateGroupProfile`を通らない差し替えを防ぐ）、5MB未満、画像のみ。ダウンロードURLを`photoURL`に保存し、招待された人にも表示する。古いファイルは`updateGroupProfile`が消す。削除：アプリからは不可。 |
| unsentMessageArchives/{chatRoomId}/{messageId}.jpg | 送信取消した画像の保管 | アプリからの読み書きはすべて不可（Cloud Functions・Firebaseコンソールのみ）。 |
| chatRooms/{chatRoomId}/albums/{albumId}/{itemId}.jpg・.mp4・_thumb.jpg | トークのアルバムの画像・動画・サムネイル（3.13） | 読み取り：参加者のみ、1件取得のみ（一覧不可。参加前のアルバムも読める）。書き込み：参加者のみ、新規作成のみ、画像（`image/jpeg`）10MB未満・動画（`video/mp4`）100MB未満・サムネイル（`image/jpeg`）512KB未満。閉じたオフ会グループ（8.17）では書き込めない。削除：アプリからは不可（Cloud Functionsが消す）。 |
| reportedAlbumItems/{reportId}/{fileName} | 通報されたアルバムの項目の複製（3.6） | アプリからの読み書きはすべて不可。 |


- パスは固定名とし、変更のたびに同一パスを上書きする（`contentType: image/jpeg`）。
- 画像は選択時にクライアント側で縮小・圧縮する（最大幅1080px、JPEG品質85）。
- 端末側の選択肢は「カメラ」「ギャラリー」の両方を提供する。
- トークの画像（`chatRooms/{chatRoomId}/images/`）は、メッセージごとに別のファイル（messageId）とし、上書きしない。選択時に長辺1920px以下・JPEG品質85に縮小・圧縮する。ダウンロードURLはFirestoreに保存しない（3.3.1）。
- トークの画像の読み書きの判定は、ルームのドキュメントではなく、パスのルームID（2つのaccountIdを`~`で連結したもの）を分解して行う。最初のメッセージ（ルームが未作成）の画像もアップロードできるようにするため。



### 7.1 キャッシュ対策

固定パスに上書き保存するとダウンロードURLが変わらず、画像変更が反映されないため、URLに乱数を`v={16進数16文字}`クエリとして付与してFirestoreに保存する。URLは誰でも読めるので、端末の時計が分かる時刻は入れない。ビルド16以前のアプリが保存した`updatedAt={ミリ秒}`のURLも、そのまま表示できる。

ほかのサーバーのURLを読み込むと、画像を出しただけで端末のIPがそのサーバーに分かる。バケットを所有していればCloud Storageのログからも分かるため、URLはホストだけでなくバケットまで限る。

- `accounts.photoURL`・`backgroundURL`：`https://firebasestorage.googleapis.com/v0/b/{dev・本番のバケット}/o/accounts%2F{accountId}%2F{fileName}`で始まるURLだけを受け付ける。判定はルール（`isOwnImageUrl`）とアプリ（`lib/utils/storage_image_url.dart`）の両方にあり、バケットの一覧は両方を揃えて更新する。
- アプリは`Account`を読むときに、そのアカウントの画像でないURLを無いものとして扱う。`AppAvatar`・`BackgroundImage`は、このアプリのアカウントかグループの画像でないURLを読み込まない。

### 7.2 アップロード処理フロー

1. 画像を選択し圧縮する（`requestFullMetadata: false`）。
2. メタデータを消す（下記）。消せなければ、元のファイルを上げずに選択の失敗として知らせる。
3. 5MB以上の場合はアップロードせず失敗とする（Storageのルールが5MB未満のみ受け付けるため）。
4. 固定パスへアップロード。
5. 取得したURLに乱数を付与してFirestoreを更新する。
6. 失敗時（サイズ超過・ネットワークエラー等）はスナックバーで保存失敗を通知する。アカウント作成時の画像アップロード失敗は、画像なしで作成を完了する。

トークの画像、プロフィール画像、背景画像、グループの画像は、選択の直後に端末でメタデータ（位置、機種、撮影時刻など）を消す（`lib/utils/image_metadata.dart`）。アルバムの画像とサムネイルは、変換（`AlbumMediaService`）の中でJPEGに書き直したあとに同じ処理（`stripJpegMetadata`）でExifなどを除く。アルバムの動画は、iOSでは変換（`VideoProcessingChannel.swift`、AVAssetWriter）でメタデータを書かない。

- JPEGに再エンコードして画素だけを残し、向きは画素に反映する。透過はなくなる。エンコーダが足す項目も、APP0（JFIF）・APP2（色のプロファイル）・APP14（Adobeの色の指定）を除いて、再エンコードの後に取り除く。
- GIFは再エンコードすると動かなくなるため、ブロックを読んで、画像、表示の制御、繰り返しの指定だけを残す。コメント、XMPなどのアプリケーション拡張、テキスト、終端より後のデータは除く。形式を読めないGIFは上げない。



### 7.3 Storageセキュリティルール

- プロフィール画像・背景画像（`accounts/{accountId}/{fileName}`）
  - 読み取り：サインイン済みなら誰でも可。
  - 書き込み：アカウントの保有ユーザのみ（`users/{自分のuid}/ownedAccounts/{accountId}`が存在するか。3.1.1）。5MB未満、画像（`image/*`）のみ。
  - 削除：不可。
- トークの画像（`chatRooms/{chatRoomId}/images/{messageId}.jpg`）
  - 読み取り・書き込み：ルームIDを`~`で分解した2つのアカウントのどちらかについて、`users/{自分のuid}/ownedAccounts/{accountId}`が存在すること。ルームIDに`~`が無ければグループとして、`users/{自分のuid}/groupMemberships/{chatRoomId}`が存在すること。
  - グループの読み取りは1件取得だけを許す（一覧を許すと参加前の画像のパスが分かるため）。
  - 書き込みは新規作成のみ（既存ファイルの上書き不可）。10MB未満、画像（`image/*`）のみ。
  - 削除：不可（送信取消の移動はCloud Functionsが行う）。
- グループの画像（`chatRooms/{chatRoomId}/photo/{fileName}`）
  - 読み取り・書き込み：`users/{自分のuid}/groupMemberships/{chatRoomId}`が存在すること。5MB未満、画像（`image/*`）のみ。
  - 削除：不可（古いファイルはCloud Functionsが消す）。
- スタンプの画像（`stickers/{packId}/{stickerId}.webp`、3.9）：サインイン済みなら1件取得できる。一覧取得と書き込みは不可。
- 送信取消した画像の保管（`unsentMessageArchives/{chatRoomId}/{messageId}.jpg`）：アプリからの読み書きはすべて不可。
- トークのアルバム（`chatRooms/{chatRoomId}/albums/{albumId}/{fileName}`、3.13）
  - 読み取り：トークの画像と同じ判定（1対1はルームIDのどちらかのアカウントの保有ユーザ、グループは`groupMemberships`）。1件取得のみ。
  - 書き込み：同じく参加者のみ、新規作成のみ。ファイル名と種類と大きさの組み合わせ（`{itemId}.jpg`は`image/jpeg`の10MB未満、`{itemId}.mp4`は`video/mp4`の100MB未満、`{itemId}_thumb.jpg`は`image/jpeg`の512KB未満）。閉じたオフ会グループ（`closedAt`があるか`closesAt`を過ぎた）では不可。読み取り専用・ブロック・上限は、Firestoreの項目の作成で止める。
  - 削除：不可（Cloud Functionsが消す）。
- 通報された項目の複製（`reportedAlbumItems/{reportId}/{fileName}`）：アプリからの読み書きはすべて不可。

ルールの正は`firebase/storage.rules`とし、本書にはルールのコードを載せない。

---



## 8. グループチャット

> 7章までの本文は1対1の動作を書いている。グループのデータは本章にまとめる。機能は機能仕様書4.7、画面は画面設計書5.10を参照する。

### 8.1 方針

- **既存の1対1のデータは移行しない**：1対1のルームは`~`入りのIDのまま、`type`フィールドの無いドキュメントを1対1として扱う。グループはFirestoreの自動採番ID（`~`を含まない）とする。1対1のルール判定は変えない。
- **参加者の増減はすべてCloud Functions（callable）で行う**：人数の上限、ルーム・メンバー・`chatList`・システムメッセージの同時更新、ブロックの判定を、アプリからの書き込みに任せない。`chatRooms`の作成ルール（1対1のみ）は変えない。
- **uidはルームの下に置かない**：1章の「他人にuidを見せない」「本人しか読まない情報は`users/{uid}`の下に置く」に合わせる（8.3）。
- **既読は参加者ごとの時刻で持つ**：メッセージの`readBy`はグループでは使わない（8.6）。

### 8.2 データ構成

```
users/{uid}
  groupMemberships/{chatRoomId}          … 参加中のグループ（本人のみ読める。書くのはCloud Functionsのみ）

accounts/{accountId}
  chatList/{chatRoomId}                  … グループの行も同じコレクションに置く（type: "group"）
  groupRequests/{chatRoomId}             … 届いている招待（保有ユーザのみ読める。書くのはCloud Functionsのみ）
  joinApplications/{chatRoomId}          … 出した参加の申請（オフ会グループ、8.16。保有ユーザのみ読める。書くのはCloud Functionsのみ）

chatRooms/{chatRoomId}                   … グループはtype: "group"、IDは自動採番
  members/{accountId}                    … 参加者ごとの情報（参加者が読める）
  joinRequests/{accountId}               … 参加の申請と答え（オフ会グループ、8.16。主催チームだけが読める）
  messages/{messageId}                   … 1対1と同じ。type: "system"を追加
  announcements/{announcementId}         … オフ会グループのお知らせ（参加者が読める。書くのはCloud Functionsのみ、8.15）

groupInvites/{token}                     … 招待リンクのトークン（アプリから読み書き不可）
```

#### chatRooms/{chatRoomId}（グループ）

| フィールド | 型 | 必須 | 説明 |
| --- | --- | --- | --- |
| chatRoomId | string | ○ | ドキュメントIDと同値。 |
| type | string | ○ | `"group"`。1対1にはフィールドが無い。 |
| name | string | ○ | グループ名（1〜50文字）。 |
| photoURL | string | － | 画像のダウンロードURL（`accounts.photoURL`と同じ形）。 |
| photoPath | string | － | 画像のStorageのパス。画像を変えたときに古いファイルを消すために持つ。 |
| joinPolicy | string | ○ | 友だち選択の招待の方式。`"auto"`／`"approval"`。作成後不変。 |
| groupKind | string | － | グループの種類。`"meetup"`＝オフ会グループ。無ければ普通のグループ。作成後不変（8.14）。 |
| organizerIds | array | － | 主催チームのaccountId。オフ会グループだけが持ち、参加者がいる間は1件以上で、`participantIds`に含まれる値だけ（8.14）。 |
| eventAt | timestamp | － | 会の日時。オフ会グループで、主催チームが決めたときだけ持つ。一度決めたら消さない（期限・期限の前の知らせ・出欠がここから数える、8.15）。 |
| eventPlace | string | － | 会の場所（店名か住所、1〜100文字）。未定なら持たない（8.15）。 |
| eventUpdatedAt | timestamp | － | 会の日時・場所を最後に変えた日時。 |
| eventUpdatedBy | string | － | 会の日時・場所を最後に変えたaccountId。 |
| closeAfterDays | number | － | グループを閉じる日。会の日時の何日後に閉じるか（1〜14の整数）。無ければ3（初期値）。主催チームが選ぶ（8.17）。 |
| closesAt | timestamp | － | 閉じる日時＝`eventAt`＋`closeAfterDays`×24時間（8.17）。会の日時が決まったら持つ。この時刻を過ぎたら、firestore.rules・Cloud Functionsが書き込みを拒む。 |
| closeState | string | － | 閉じる処理の状態（8.17）。`"scheduled"`（期限あり・開いている）／`"closed"`（閉じた）／`"purged"`（片付けた）。定時の処理のクエリに使う。会の日時が決まるまでは持たない。 |
| closedAt | timestamp | － | 閉じる処理をした日時（8.17）。 |
| purgeAt | timestamp | － | 記録を消す日時＝`closesAt`の30日後（8.17）。閉じたときに書く。 |
| closeNotice24hFor・closeNotice1hFor | timestamp | － | 24時間前・1時間前の知らせを送ったときの`closesAt`（8.17）。今の`closesAt`と違えば、新しい期限の知らせがまだ。 |
| joinQuestions | array | － | 参加時の質問の文。オフ会グループだけ。0〜3件、各1〜100文字。無ければ質問なし（8.16）。 |
| capacity | number | － | 定員。オフ会グループで主催チームが決めたときだけ持つ。2〜100の整数。無ければ人数の上限（100人）（8.19）。 |
| attendanceDeadline | timestamp | － | 出欠の締切。オフ会グループで主催チームが決めたときだけ持つ（8.18）。 |
| attendanceReminderAt | timestamp | － | 出欠の自動の催促を送る日時（締切の24時間前）。送ったら消す。締切まで24時間を切って決めたときは持たない（8.18）。 |
| attendanceRemindedAt | timestamp | － | 主催チームが最後に催促した日時（6時間に1回までの判定、8.18）。 |
| settlement | map | － | 精算の設定。オフ会グループで主催チームが精算を始めたときだけ持つ。中身は8.20。 |
| previousChatRoomId | string | － | 次の回として作ったオフ会グループが持つ、前の回のchatRoomId（8.21）。作成後不変。 |
| nextChatRoomId | string | － | 閉じたオフ会グループが持つ、この回から作った次の回のchatRoomId（8.21）。 |
| nextRoundCreatedBy・nextRoundCreatedAt | string・timestamp | － | 次の回を作ったaccountIdと日時（8.21）。 |
| participantIds | array | ○ | 参加中のaccountId（最大100件）。1対1と同じ名前のフィールドで、順序に意味は無い。 |
| createdBy | string | ○ | 作成したaccountId。権限には使わない（オフ会グループの権限は`organizerIds`）。 |
| createdAt | timestamp | ○ | 作成日時。 |
| deletedAt | timestamp | － | 削除の開始日時。通報があって残す場合はこのまま残る（8.9）。 |
| retentionCheckAt | timestamp | － | 削除中のルームを、定期の処理がもう一度確かめる日時（8.9）。Cloud Functionsのみ。 |

- `memberCount`は持たない。人数は`participantIds`の件数で分かる。配信のたびに`members`を100件読まずに済むよう、ルームのドキュメント1件に参加者を持つ。

#### chatRooms/{chatRoomId}/members/{accountId}

| フィールド | 型 | 必須 | 説明 |
| --- | --- | --- | --- |
| accountId | string | ○ | ドキュメントIDと同値。 |
| joinedAt | timestamp | ○ | 参加日時。アプリはこれより後のメッセージだけを取得する。 |
| joinedVia | string | ○ | `"create"`／`"friend"`／`"link"`／`"next_round"`（次の回の招待で参加、8.21）。 |
| invitedBy | string | － | 招待したaccountId（友だち選択のみ）。 |
| lastReadAt | timestamp | － | 未読があるトークを最後に開いた時刻（8.6）。 |
| organizerInvitedBy | string | － | 主催チームに誘ったaccountId（オフ会グループのみ、8.14）。誘いが無ければ持たない。 |
| organizerInvitedAt | timestamp | － | 主催チームに誘われた日時。`organizerInvitedBy`と一緒に書き、一緒に消す。 |
| approvedBy | string | － | オフ会グループで、参加の申請を承認した主催チームのaccountId（8.16）。招待リンクから承認で参加した人だけ。 |

#### chatRooms/{chatRoomId}/announcements/{announcementId}

オフ会グループのお知らせ（8.15）。IDは自動採番。1グループに20件まで。

| フィールド | 型 | 必須 | 説明 |
| --- | --- | --- | --- |
| announcementId | string | ○ | ドキュメントIDと同値。 |
| text | string | ○ | 本文（前後の空白を除いて1〜1000文字）。 |
| place | string | － | 場所（店名か住所、1〜100文字）。無ければ持たない。 |
| createdBy | string | ○ | 出したaccountId。 |
| createdAt | timestamp | ○ | 出した日時。並び順（新しい順）に使う。 |
| updatedBy | string | ○ | 最後に直したaccountId（出したときは`createdBy`と同じ）。 |
| updatedAt | timestamp | ○ | 最後に直した日時（出したときは`createdAt`と同じ）。 |

#### users/{uid}/groupMemberships/{chatRoomId}

| フィールド | 型 | 必須 | 説明 |
| --- | --- | --- | --- |
| chatRoomId | string | ○ | ドキュメントIDと同値。 |
| accountIds | array | ○ | この利用者が参加させているaccountId（通常は1件）。 |
| joinedAt | timestamp | ○ | `accountIds`のうち最も早い参加日時。ルールの履歴の判定に使う（6章）。 |

#### accounts/{accountId}/groupRequests/{chatRoomId}

| フィールド | 型 | 必須 | 説明 |
| --- | --- | --- | --- |
| chatRoomId | string | ○ | ドキュメントIDと同値。 |
| invitedBy | string | ○ | 招待したaccountId。 |
| name・photoURL・memberCount | － | － | 招待した時点のグループの情報（招待された側はルームを読めないため）。 |
| createdAt | timestamp | ○ | 招待日時。 |
| previousChatRoomId | string | － | 次の回の招待（8.21）のときだけ、前の回のchatRoomId。普通の招待は持たない。 |
| previousName | string | － | 次の回の招待のときだけ、前の回のグループ名（招待の行に出す）。 |
| asOrganizer | boolean | － | 前の回の主催チームの人への次の回の招待なら`true`。承諾すると主催チームにも入る。 |

- グループの削除時に消すため、`chatRoomId`のコレクショングループ範囲のインデックスを有効にする。

#### groupInvites/{token}

| フィールド | 型 | 必須 | 説明 |
| --- | --- | --- | --- |
| token | string | ○ | ドキュメントIDと同値。32バイトの乱数のBase64URL。 |
| chatRoomId | string | ○ | 対象のグループ。 |
| createdBy | string | ○ | 発行したaccountId。 |
| createdAt | timestamp | ○ | 発行日時。 |

- トークンはルームに持たせない。再発行で古いトークンを無効にしても、ルームを読める元の参加者の端末に残らないよう、`getGroupInviteLink`が参加を確かめてから返す。

#### 既存のドキュメントへの追加

| 場所 | フィールド | 説明 |
| --- | --- | --- |
| `chatList` | `type` | `"group"`。無ければ1対1。 |
| `chatList` | `groupKind` | `chatRooms.groupKind`の複製（作成後不変のため書き直さない）。一覧の印「オフ会」に使う。アプリから変更不可。 |
| `chatList` | `closesAt`・`closedAt` | オフ会グループの閉じる日時と閉じた日時（`chatRooms`の複製、8.17）。一覧の残り日数・「終了」と、CHA-02の消える日付に使う。アプリから変更不可。 |
| `chatList` | `name`・`photoURL`・`memberCount` | 一覧に出すグループの情報。一覧の行ごとにルームを読まないよう複製し、変更時に`updateGroupProfile`・参加退会の処理が書き直す。 |
| `chatList` | `peerAccountId` | グループの行には持たない。 |
| `chatList.lastMessage` | `systemType`・`targetAccountIds` | システムメッセージのプレビュー用。 |
| `messages` | `type: "system"`・`systemType`・`targetAccountIds`・`groupName` | システムメッセージ。`senderId`は操作した人。`systemType`は`group_created`／`member_joined`／`member_left`／`member_removed`／`group_renamed`／`group_photo_changed`／`invite_reissued`／`organizer_added`（主催チームに入った。`senderId`は入った本人、自動で入ったときも同じ）／`organizer_removed`（主催チームから外れた。`senderId`は外した人）／`announcement_posted`（お知らせを出した、8.15）／`event_updated`（会の日時・場所を決めた・変えた、8.15）／`close_updated`（グループを閉じる日を変えた。`senderId`は変えた人、8.17）／`closing_soon`（閉じる前の知らせ。`hoursLeft`に24か1、`senderId`は最後に会の日時か閉じる日を変えた人、8.17）／`group_closed`（閉じた、`senderId`は同じ、8.17）／`attendance_deadline_updated`（出欠の締切を決めた・変えた・消した、8.18）／`capacity_updated`（定員を変えた、8.19）／`settlement_started`・`settlement_updated`・`settlement_deleted`（精算を始めた・設定を変えた・やめた、8.20）。`readBy`は空配列。作るのはCloud Functionsのみ。 |
| `messages` | `reactedBy` | グループでリアクションを変更した本人のaccountId（6章）。 |
| `users` | `adultDeclaredAt` | 廃止。1.1.0のアプリだけが`declareAdult`で書く。1.1.0の利用者がいなくなったら、`declareAdult`とともに消す。 |
| `users/{uid}/ownedAccounts` | `mutedGroupIds` | 通知をオフにしたグループのchatRoomIdの配列（8.8）。本人だけが読み書きできる。 |
| `users/{uid}/ownedAccounts` | `groupCreatedCount`・`groupJoinedCount` | 作成して現在も残っているグループ数・参加中のグループ数（8.12）。書くのはCloud Functionsのみ。 |
| `users/{uid}/ownedAccounts` | `groupCreatedWindowAt`・`groupCreatedInWindow` | 24時間の作成回数の起点と回数（8.12）。書くのはCloud Functionsのみ。 |
| `reports` | `targetChatRoomId` | グループを対象にした通報。このとき`targetAccountId`は持たない。 |

### 8.3 `memberUids`を置かない理由

メッセージの一覧取得のリクエストには、どのアカウントとして読むかの情報が無い。100人の参加者を順に調べることもルールではできないため、リクエストした本人のuidから1回で判定できる場所が必要になる。

ルームの下に`memberUids/{uid}`を置く形でも判定はできるが、他人が読めるツリーの中にuidが並ぶことになり、ルールの誤りが1つあるだけでuidが漏れる。そこで`users/{uid}/groupMemberships/{chatRoomId}`に置く。判定に必要な読み取りは同じ1件で、`ownedAccounts`と同じ考え方でそろい、退会の`recursiveDelete(users/{uid})`で一緒に消える。

### 8.5 Cloud Functions

| 関数 | 種類 | 内容 |
| --- | --- | --- |
| `createGroup` | callable | 上限（8.12）を確かめ、ルーム・自分の`members`・`groupMemberships`・`chatList`・`group_created`を1つのトランザクションで書く。招待は続けて`inviteToGroup`と同じ処理を行う。 |
| `inviteToGroup` | callable | 宛先ごとに参加または招待を行う（8.7）。オフ会グループでは操作する人が主催チームであること（違えば`not-organizer`、8.16）。 |
| `respondToGroupRequest` | callable | 招待への参加・拒否。 |
| `declareAdult` | callable | 廃止。1.1.0のアプリが申告の画面から先へ進めるよう、`users/{uid}.adultDeclaredAt`を書いて成功を返す。新しいアプリからは呼ばない。 |
| `getGroupInviteLink`・`reissueGroupInviteLink` | callable | 参加を確かめて、トークンを返す・作り直す。 |
| `previewGroupInvite`・`joinGroupByLink` | callable | トークンを確かめて、グループの表示内容を返す・参加する。 |
| `groupInvitePage` | HTTP（公開） | 招待ページ（Web）に出すグループの中身と画像を返す。サインイン・App Checkは求めない（8.11）。 |
| `leaveGroup`・`removeGroupMember` | callable | 退会（8.9）。オフ会グループでは、`removeGroupMember`は主催チームだけ、`leaveGroup`は最後の主催の1人を拒む（8.14）。 |
| `inviteToOrganizers`・`respondToOrganizerInvite`・`removeFromOrganizers` | callable | 主催チームに誘う・誘いに答える・主催チームから外す（抜ける）（8.14）。 |
| `postAnnouncement`・`updateAnnouncement`・`deleteAnnouncement`・`updateMeetupEvent` | callable | お知らせを出す・直す・消す、会の日時と場所を決める（8.15）。 |
| `applyToJoinGroup`・`cancelJoinApplication`・`respondToJoinRequest`・`updateJoinQuestions` | callable | オフ会グループの参加の申請・取り消し（結果の消去）・承認と断る・参加時の質問の変更（8.16）。 |
| `processMeetupLifecycle` | 定時（5分ごと） | オフ会グループの期限の前の知らせ・閉じる・30日後の片付け（8.17）。 |
| `updateGroupProfile` | callable | 名前・画像の変更、`chatList`の書き直し、システムメッセージ。画像はアプリが`chatRooms/{chatRoomId}/photo/`へ上げたファイル名を受け取り、URLはサーバーが作る（他の参加者の端末に外部のURLを読み込ませないため）。 |
| `onMessageCreated`・`onMessageReacted`・`onMessageUnsent` | トリガー | グループの場合の処理を足す（8.6・8.8）。 |
| `withdrawUser`・`onAccountSoftDeleted` | callable・トリガー | グループの退会を足す（8.9）。 |

- callableは操作するaccountIdを受け取り、`users/{uid}/ownedAccounts/{accountId}`で本人のものか確かめる。応答にuidを含めない。
- `updateGroupProfile`の`isInitialPhoto`：グループの作成の続きで画像を付けるときに渡し、システムメッセージを出さない。作成者が、作成から10分以内に、まだ画像の無いグループへ付けるときだけ有効で、それ以外は通常の変更と同じ。
- 読み取り専用（機能仕様書4.2.1.3）は、`createGroup`・`inviteToGroup`・参加の処理（トランザクションの中）で`users/{uid}`の`plan`・`accountCount`・`keptAccountIds`から、操作するアカウントごとに判定する。
- エラーの`message`は理由のコード（`read-only`・`group-full`・`join-limit`・`create-limit`・`members-exceeded`・`group-deleted`・`request-not-found`・`invite-invalid`・`not-member`・`not-organizer`・`last-organizer`・`organizer-invite-not-found`・`announcement-limit`・`announcement-not-found`・`invalid-event-at`・`invalid-close-days`・`group-closed`・`approval-required`・`join-request-not-found`・`applicant-unavailable`・`invalid-answers`・`invalid-questions`など）で、アプリが文言を出し分ける。
- 招待の通知のデータは`type: "group_invite"`・`accountId`・`chatRoomId`。主催チームへの誘いの通知は`type: "organizer_invite"`・`accountId`・`chatRoomId`（タップでそのグループのトークを開く）。お知らせの通知は`type: "announcement"`・`accountId`・`chatRoomId`（同じくトークを開く、8.15）。参加の申請と結果の通知は8.16。
- 関数の本体は`firebase/functions/groups.js`。テストは`firebase/functions/test-emulator`で、`npm run test:emulator`でエミュレータを起動して実行する。
- 参加の処理は、ルームのトランザクションの中で`participantIds`の件数が100未満であること、`deletedAt`が無いことを確かめる。参加者が同時に増えても上限を超えない。

### 8.6 未読・既読

- **未読数**：`chatList.unreadCount`を1対1と同じく使う。未読があるトークを開いたら、アプリが自分の`chatList.unreadCount`を0にし、`members/{自分}.lastReadAt`を更新する（同じバッチ）。未読が無ければ何も書かない（参加者が読める値なので、開いただけの時刻を残さない）。
- **既読数**：`members`を1回取得し、各メッセージの`createdAt`以降の`lastReadAt`を持つ人数を数える（自分を除く）。取得はトークを開いたときと、自分の送信時（30秒に1回まで）とする。
- `readBy`を使わない理由：メッセージの更新は`onMessageReacted`・`onMessageUnsent`を毎回起動し、トークを開いている全員の監視にも届く。100人のグループで1通につき最大99回の更新になる。
- `members`を監視しない理由：1通ごとに最大99件の`lastReadAt`の更新が、開いている全員に届く。開いている人数×99回の読み取りになり、1対1と同じリアルタイムさの価値に合わない。

### 8.7 招待の判定

`inviteToGroup`は宛先ごとに次の順で判定する。

1. 招待した人と宛先のどちらかの`blockedAccounts`に相手がある　→　何もしない（結果は成功として返す）。
2. 宛先が30日以内にこのグループの招待を拒否した（`accounts/{accountId}/groupRequestDeclines/{chatRoomId}`。フィールドは`chatRoomId`・`declinedAt`）　→　何もしない。
3. `joinPolicy`が`"auto"`で、宛先の`friends`に招待した人があり、宛先が参加の上限に達していない　→　参加させる。
4. それ以外　→　`groupRequests`を作る。新しい招待は、招待した人の`inviteCounters`（3.1.3）の枠を1件使い、枠が無ければ何もしない。

判定の結果は招待した人に返さない。上限の判定は、参加と招待の合計ではなく、宛先の人数と現在の人数で行い、超えるときは全体を失敗にする。実際の参加は`respondToGroupRequest`で改めて上限を確かめる。

### 8.8 配信

`onMessageCreated`は、ルームの`type`が`"group"`なら次のように処理する。

1. ルームを1件読み、`participantIds`から送信者を除く（最大99人）。
2. `BulkWriter`で各`chatList`を`update`する（`lastMessage`・`lastMessageAt`、システムメッセージ以外は`unreadCount`を+1）。システムメッセージは操作した本人の行にも出すため、送信者を除かない。`set`にしないのは、退会の直後に行を作り直さないため。行が無ければその1件だけ失敗し、他には影響しない。
3. システムメッセージなら終わり。
4. `ownedAccounts`のコレクショングループクエリを`accountId in [...]`で30件ずつ（4回）読み、通知がオンで、`mutedGroupIds`にこのグループが無い宛先に絞る。
5. 宛先の`fcmTokens`を読み、`sendEach`（1回500通）へまとめる。通知のデータ（開くアカウント）が宛先ごとに違うため、`sendEachForMulticast`は使えない。無効なトークンを消す処理は今と同じ。

- 1対1のように行を読むトランザクションで二重加算を防ぐことはしない。99件のトランザクションは遅く、競合するため。Cloud Functionsが同じイベントで2回呼ばれたときは未読数が1多くなることがあるが、開けば0に戻るため許容する。
- `onMessageUnsent`は、1対1の`readBy`の代わりに`members.lastReadAt`で未読かどうかを判定し、同じ処理を全参加者の`chatList`に行う（参加者全員を読むのは送信取消のときだけ）。プレビューを書き直す先のメッセージが参加前なら、`lastMessage`をnullにする。
- `onMessageReacted`の宛先はメッセージの送信者1人のままとし、送信者の`mutedGroupIds`にこのグループがあれば送らない。
- **グループごとの通知オフ**：`members`・`chatList`ではなく`ownedAccounts.mutedGroupIds`に持つ。`members`は他の参加者に見え、`chatList`は宛先ごとに行を読むため1通あたり最大99件の読み取りが増える。`ownedAccounts`は配信で必ず読むので、読み取りは増えない。件数は参加の上限（100個）までに収まる。退会の処理が同じトランザクションで該当のIDを消す。
- 関数はメモリ512MiB、タイムアウト120秒を目安にする。

**費用の見積もり**（Firestoreは東京の概算単価：読み取り$0.038、書き込み$0.115／10万件。公式の無料枠：読み取り5万件、書き込み2万件／日。1ドル150円、FCMは無料）

| 操作（100人のグループ） | 読み取り | 書き込み | 費用の目安 |
| --- | --- | --- | --- |
| 1通の配信（1人1端末） | 約199件 | 99件 | 約$0.00019（0.03円） |
| トークを1回開く | 約100件（`members`） | 2件 | 約$0.00004 |

| 想定 | 1日の読み取り | 1日の書き込み | 1か月の費用 |
| --- | --- | --- | --- |
| 10人のグループ20個、計2,000通／日 | 約4万件 | 約2万件 | ほぼ無料枠内 |
| 100人のグループ1個、1,000通／日、1人10回開く | 約34万件 | 約10万件 | 約900〜1,100円 |
| 30人のグループ100個、計2万通／日 | 約130万件 | 約60万件 | 約5,000円 |

Cloud Functionsの費用は1回の配信で約$0.00002で、Firestoreより小さい。100人のグループ1つの1,000通／日で、小さな予算アラートに届く水準になる。

### 8.9 退会・削除

- `leaveGroup`・`removeGroupMember`は1つのトランザクションで、`participantIds`・`members`・`groupMemberships`（`accountIds`が空なら削除。残れば`joinedAt`を残りの最も早い値へ）・`chatList`の行を消し、システムメッセージを作る。
- 最後の1人なら、トランザクションで`deletedAt`を付けたあと、残っている参加の申請を閉じ（8.16の`closeJoinRequests`）、`messages`・`announcements`・`members`・`joinRequests`・`groupInvites`・`groupRequests`・Storageの`chatRooms/{chatRoomId}/`以下を削除し、ルームも削除する。ただし`reports`に`chatRoomId`または`targetChatRoomId`が一致するものがあれば、メッセージとStorageを消さず、`deletedAt`の付いたルームを残す（アプリからは読めない）。
- **退会（`withdrawUser`）**：`recursiveDelete(users/{uid})`の前に、`groupMemberships`の各グループで全アカウントを退会させる。消した後ではどのグループに居たか分からなくなるため。`accounts`の下の削除対象に`groupRequests`を足す。再実行しても続きから処理できるようにする。
- **アカウント削除（`onAccountSoftDeleted`）**：保有ユーザを引いたあと、`groupMemberships`の`accountIds`にそのアカウントが含まれるグループから退会させ、退会と同じく公開プロフィールと自分だけのデータを消す（`withdrawal.js`の`scrubAccount`）。退会の処理から動いたときは保有ユーザが引けないが、`withdrawUser`が先に処理している。
- **両方のアカウントが削除された1対1のルーム**：`onAccountSoftDeleted`が、そのアカウントが当事者の1対1のルームのうち、相手のアカウントも削除済み（`isDeleted`）のものに`deletedAt`を付け、グループと同じ削除（`deleteGroupData`）をする。通報があれば残す。
- **削除中のルームの拾い直しと、通報で残したルームの削除**：`deletedAt`を付けるときに`retentionCheckAt`（1日後）も書く。`deleteGroupData`が通報で残すときは、`retentionCheckAt`を最後の通報の日から3年後（保全中の通報があれば30日後）に書き直す。`processDataRetention`（1時間ごと）が、`retentionCheckAt`を過ぎた削除中のルームを、もう一度`deleteGroupData`に渡す。通報は3年で消えるので、その後のルームは消える。
- 退会させないと、残った行へ配信し続け、削除したアカウントが人数の枠を占め、最後の1人の判定もできなくなる。

### 8.11 招待リンク・QRコード

- 招待リンク：`https://{ドメイン}/group/{token}`（本番は`orto.example.com`）。`apple-app-site-association`・AndroidのApp Links・案内ページは、運営者のWebサイト（Cloudflare）に置く。
- QRコード：招待リンクと同じ`https://{招待リンクのドメイン}/group/{token}`。4.1の友だち用と同じく、標準のカメラで読んでもアプリ（入っていなければ案内ページ）が開く。アプリのスキャナーは、以前の`orto://group/{token}`も受け付ける。
- カスタムURLスキーム：`orto://group/{token}`・`orto://invite/{accountId}`（開発版は`orto-dev://`）。案内ページの「アプリをお持ちの方はこちら」ボタン用で、アプリはhttpsの招待リンクと同じ処理で受け付ける。iOSは`Info.plist`の`CFBundleURLTypes`（`ios/Flutter/*.xcconfig`の`APP_URL_SCHEME`）、Androidは`autoVerify`なしの別のintent-filter（`build.gradle.kts`の`appUrlScheme`）に登録する。以前のQRコードの`orto://group/`・`orto://friend/`も、標準のカメラで読むとアプリが開く。
- 案内ページはトークンを`noindex`のページの中でだけ扱い、外部に送らない。送り先は、中身を読むためのこのプロジェクトのCloud Functions（`groupInvitePage`）だけ。

**招待ページの公開の口（`groupInvitePage`）**

アプリを入れる前の人に、App Storeへ進む前にグループの中身を見せるための口。`previewGroupInvite`はサインインが要るため、別に置く。本体は`firebase/functions/invite_page.js`。

- 種類：HTTPの関数（`onRequest`、`invoker: "public"`）。サインインもApp Checkも求めない。CORSは`https://orto.example.com`・`https://open.example.com`だけを許す。
- 受け取り：`POST`で、本文のJSONに`token`。トークンをURLに入れるとリクエストのログにそのまま残るため、本文で受け取る。`GET`などは405。
- 中身を返す（`{token}`）：`kind`（`"meetup"`か`"standard"`）・`name`・`memberCount`・`hasPhoto`・`eventAt`（オフ会グループで決まっていればISO 8601の文字列、ほかは`null`）・`organizers`（主催チームの先頭3人の`displayName`と`hasPhoto`。削除済みのアカウントは除く）・`otherOrganizerCount`（4人目からの人数）。普通のグループは`organizers`が空。
- 画像を返す（`{token, image: "group"}`・`{token, image: "organizer", index: 0〜2}`）：Storageから読んだ画像の中身（`Content-Type`は保存時のもの）。画像のURLはパスにルームID・アカウントIDを含むため返さない。読むのは、URLがこのプロジェクトのバケットの`chatRooms/{そのルーム}/photo/`か`accounts/{その主催の人}/`を指すときだけ。
- 返さないもの：uid・アカウントID・ルームID・画像のURL、会の場所（`eventPlace`）、メンバーの一覧、お知らせ、参加時の質問、定員。
- 無効なとき：形式違い・トークンが無い（再発行済み）・グループが無いか削除済み・閉じた（8.17）は、どれも同じ404（`{"error":"invalid"}`）。どれに当たったかはログ（トークンは先頭4文字と長さだけ）で見る。
- 総当たりへの備え：トークンは32バイトの乱数（2^256通り）で、当てずっぽうで当たることは無い。そのうえで、インスタンス数の上限（3）で、大量に呼ばれたときの費用を抑える。応答の`Cache-Control`は、中身・画像が`private, max-age=300`、無効は`no-store`。
- 書き込みはしない。Firestoreのルールは変わらない（Cloud Functionsが管理者の権限で読む）。

### 8.12 グループ数の上限

- 上限は`appConfig/groupLimits`（`maxCreatedPerAccount`・`maxJoinedPerAccount`）に持ち、Firebaseコンソールで変えられる。無いときはCloud Functionsの既定値（作成20、参加100）を使う。アプリは読まず、Cloud Functionsのエラーで判断する。
- 判定は`ownedAccounts`の`groupCreatedCount`・`groupJoinedCount`で行い、参加・作成のトランザクションの中で確かめる。件数のクエリにしないのは、同時に参加しても上限を超えないようにするため。
- `groupJoinedCount`は参加で+1、退会で-1する。`groupCreatedCount`は作成で+1し、グループの削除で作成者（`createdBy`）の分を-1する。作成者のアカウントが削除済みなら何もしない。自分が抜けただけでは減らさない（作成と退会を繰り返して上限を避けられないように）。
- 作成数はグループの削除で減るため、別に24時間の作成回数を`groupCreatedWindowAt`・`groupCreatedInWindow`で数える。上限は`maxCreatedPerDay`（既定20）で、超えたときの理由は作成数の上限と同じ`create-limit`。
- 招待（`groupRequests`）の受信は上限に数えない。自動参加の判定（8.7）では、宛先の`groupJoinedCount`が上限に達していれば招待にする。

### 8.13 公開済みのアプリとの互換

公開済みのv1の利用者はいない前提とし、v1向けの保護は設けない。強制アップデートの判定はv1.1で初めて入るため、`minimumVersion`で止められるのはv1.1より後の古いバージョンからで、v1.0.0は止められない。

**公開の順番**

1. ルール・Cloud Functionsをデプロイする。
2. v1.1をストアで公開する。
3. v1.1以降のアプリを止める必要が出たときに、`appConfig/version`の`minimumVersion`を上げる。グループの公開自体には必要ない。

### 8.14 オフ会グループと主催チーム

機能は機能仕様書4.7.8、画面は画面設計書5.10を参照する。

**種類**

- `chatRooms.groupKind`が`"meetup"`ならオフ会グループ。`type`は普通のグループと同じ`"group"`のままにし、参加・配信・既読・退会などの今の処理と判定をそのまま使う。普通のグループは`groupKind`を持たないので、今あるグループのデータは移さない。
- `createGroup`が`groupKind`（`"standard"`または`"meetup"`。省略は`"standard"`）を受け取り、`"meetup"`のときだけ`groupKind`と`organizerIds: [作成者]`を書く。種類を変える関数は無い（作成後不変）。
- 一覧の印のため、`chatList`の行にも`groupKind`を複製する。行は作成・参加のときに作るので、そのときに書けばよい。
- 閉じるまでの残り日数は、会の日時が決まったら`chatRooms`と`chatList`の`closesAt`から数える（8.17）。それまでアプリは「日時未定」を出す。

**主催チームを`chatRooms.organizerIds`に持つ理由**（`members/{accountId}`に役割を持たせる案と比べた）

- 0人にしない決まりを1つの文書で守れる：参加者（`participantIds`）と同じ文書にあるので、退会・強制退会・主催チームの増減のトランザクションで、ルーム1件を読むだけで「主催チームが空にならないか」「主催チームが参加者に含まれるか」を確かめられる。`members`に持つと、主催チームの人数を数えるクエリが毎回要る。
- ルールの判定が1回の読み取りで済む：後から足す、アプリが直接書くデータ（お知らせ・出欠の設定など）のルールは、`get(chatRoomPath(chatRoomId)).data.get('organizerIds', []).hasAny([操作するaccountId])`と、本人がそのaccountIdを保有しているか（`isOwnerOfAccount`）で判定できる。ルームの文書はオフ会グループかの判定（`groupKind`）にも読むので、読み取りは増えない。
- 人数は参加者の上限（100人）までで、文書の大きさに問題は無い。
- 参加者は今もルームの文書を読める（`isGroupMember`）。他人のuidは入らない。
- 主催チームへの誘いは、誘われた人の`members/{accountId}`の`organizerInvitedBy`・`organizerInvitedAt`に持つ。誘われた人は自分の`members`の1件を監視するだけでカードを出せ、GRP-03の一覧は今の`members`の取得で「主催に誘い中」を出せる。グループを抜けると`members`ごと消えるので、誘いも一緒に消える。

**関数**

| 関数 | 確かめること | 書くもの |
| --- | --- | --- |
| `inviteToOrganizers` | 操作する人が主催チーム。相手が参加者で、主催チームでない | 相手の`members`に`organizerInvitedBy`・`organizerInvitedAt`（誘い中ならそのまま）。初めての誘いなら通知（`type: "organizer_invite"`） |
| `respondToOrganizerInvite` | 本人の`members`に誘いがある（無ければ`organizer-invite-not-found`）。入るときは本人が読み取り専用でない（読み取り専用なら`read-only`で、誘いは残す） | 入る：`organizerIds`に足し、誘いを消し、`organizer_added`。断る：誘いを消すだけ（システムメッセージ・通知は出さない） |
| `removeFromOrganizers` | 操作する人が主催チーム。相手が主催チーム（自分でもよい）。外した後に1人以上残る（残らなければ`last-organizer`） | `organizerIds`から外し、`organizer_removed` |
| `removeGroupMember` | オフ会グループでは操作する人が主催チーム（違えば`not-organizer`） | 今の退会に加え、相手が主催チームなら`organizerIds`からも外す |
| `leaveGroup` | オフ会グループで、本人が主催チームの最後の1人かつほかに参加者がいる　→　`last-organizer` | 今の退会に加え、`organizerIds`から外す |
| `withdrawUser`・`onAccountSoftDeleted`（`leaveAllGroups`） | 止めない | 主催チームが0人になり参加者が残るときは、残りの`members`の`joinedAt`が早い順に、読み取り専用でない最初の人（全員が読み取り専用なら最も早い人）を`organizerIds`に入れ、`organizer_added`を書く（同じトランザクション） |

- いずれもルームのトランザクションの中で`organizerIds`・`participantIds`を読み直してから書く。同時に2人が抜けても0人にならない。
- 読み取り専用のアカウントは主催チームに入れない（`organizerIds`はアプリから書けないので、関数で拒めば足りる）。誘うときに相手が読み取り専用かを確かめないのは、誘った人に相手の状態が分からないようにするため（8.7の招待と同じ）。
- 主催チームでない人からの操作は、アプリの画面に出さないうえで、関数が`permission-denied`（`not-organizer`）で拒む。
- `chatRooms`・`members`の`organizerInvitedBy`・`organizerInvitedAt`・`chatList.groupKind`は、アプリから書けない（firestore.rules）。`chatRooms`はもともとアプリから更新できず、`members`はアプリが`lastReadAt`だけを書ける。

### 8.15 お知らせと会の日時

機能は機能仕様書4.7.8.4、画面は画面設計書5.10.7・5.10.8・5.10.11（CHA-02）を参照する。

**会の日時は`chatRooms`の項目として持つ**

比べた案：(A) お知らせの1件（`announcements`の特別な種類）として持つ、(B) `chatRooms`の`eventAt`・`eventPlace`として持ち、お知らせの画面（CHA-02の上の枠・GRP-08）から入れる。(B)にした理由：

- 期限を同じ書き込みで決められる：`updateMeetupEvent`のトランザクションの中で、ルームの`eventAt`と、そこから数えた期限を一緒に書ける。会の日時が変わったら期限もずれる、を1つのトランザクションで守れる。(A)だとお知らせの書き込みとルームの期限の書き込みが別の文書になり、ずれる時間ができる。
- 閉じたかの判定が1回の読み取りで済む：「閉じたら送れない」のルールは、メッセージの書き込みのたびに`get(chatRoomPath(chatRoomId))`でルームを読む。期限も会の日時もルームにあれば、読み取りは増えない。
- 定時の処理が1つのクエリで探せる：期限の前の知らせは、`chatRooms`を期限の範囲で引くだけで、知らせる相手のグループが分かる。(A)だと`announcements`のコレクショングループクエリを引いてからルームを読むことになる。
- 出欠・招待ページ・トーク一覧の残り日数も、ルーム（とその複製の`chatList`）を読めば会の日時が分かる。
- 会の日時と場所は1組だけで、増えない。お知らせ（件数が増え、並べ替えて見せる）とは持ち方を分けたほうが、それぞれの決まり（日時は未定に戻せない、お知らせは20件まで）を守りやすい。

画面では、会の日時と場所をお知らせの枠のいちばん上にいつも出すので、メンバーから見ると「お知らせの1つ」に見える。

**会の日時が決まったことを後から使う方法**

- `chatRooms.eventAt`があれば会の日時が決まっている。無ければ未定で、期限も知らせも動かさない。
- 一度決めたら消さない（`updateMeetupEvent`は`eventAt`を消す指定を受け付けない）ので、「決まった後に未定に戻る」場合を考えなくてよい。
- 閉じる処理は、`updateMeetupEvent`のトランザクションの中で期限（`closesAt`）を計算して同じルームに書き、`chatList`への複製も同じ関数で書く（8.17）。閉じたあと（`closesAt`を過ぎた・`closedAt`がある）は、この節の関数すべてで`group-closed`で拒む。
- 期限の前の知らせは、`closesAt`を見て知らせる（8.17）。

**お知らせを`chatRooms/{chatRoomId}/announcements`に置く理由**

- ルームの下に置くので、グループの削除（8.9）と、閉じたあとの30日の片付けで、メッセージと一緒に消せる。閉じたあとも、トークと同じく参加者が読める（読み取りの判定はメッセージと同じ`isGroupMember`）。
- ルームの文書に配列で持たないのは、お知らせ1件ごとに本文（最大1000文字）があり、20件で文書が大きくなり、ルームを監視している全員の端末にお知らせの変更のたびに全体が届くため。

**書き込みをCloud Functionsだけにする理由**

- 主催チームかの確かめ、読み取り専用の確かめ（4.2.1.3。`users/{uid}`の`plan`などから判定するので、ルールでは判定できない）、20件の上限、システムメッセージ、通知を、1つのトランザクションでまとめて行うため。アプリから直接書けると、通知とシステムメッセージを後からトリガーで出すことになり、通知するかの選択をデータに残す必要が出る。
- firestore.rulesでは、`announcements`は参加者の読み取りだけを許し、書き込みはすべて拒む。`chatRooms`の`eventAt`などは、もともと`chatRooms`の更新を拒んでいるので足す決まりは無い。

### 8.16 参加の承認と参加時の質問

機能は機能仕様書4.7.8.5、画面は画面設計書5.10（GRP-05・GRP-09・GRP-10）を参照する。オフ会グループの招待リンク・QRコードからの参加だけが対象で、友だち選択の招待（8.7）は変えない。

**データ**

`chatRooms/{chatRoomId}/joinRequests/{accountId}`（申請と答え。主催チームだけが読める）

| フィールド | 型 | 必須 | 説明 |
| --- | --- | --- | --- |
| accountId | string | ○ | ドキュメントIDと同値。申請したアカウント。 |
| status | string | ○ | `"pending"`（承認待ち）／`"waitlisted"`（キャンセル待ち）／`"approved"`（承認して参加した）／`"declined"`（断った）／`"closed"`（グループが閉じて終わった）。 |
| answers | array | ○ | `{question, answer}`の配列。申請した時点の質問の文と答え（質問を後から変えても、届いている申請の表示が変わらないように文を持つ）。質問なしなら空。 |
| createdAt | timestamp | ○ | 申請日時。キャンセル待ちの順番（申請した順）にも使う。 |
| respondedBy | string | － | 承認・断るをした主催チームのaccountId（主催チームの中の記録。申請した人には見せない）。 |
| respondedAt | timestamp | － | 承認・断る・閉じた日時。 |

`accounts/{accountId}/joinApplications/{chatRoomId}`（出した申請。本人だけが読める）

| フィールド | 型 | 必須 | 説明 |
| --- | --- | --- | --- |
| chatRoomId | string | ○ | ドキュメントIDと同値。 |
| status | string | ○ | `"pending"`／`"waitlisted"`／`"declined"`／`"closed"`。承認されて参加したら消す。 |
| name・photoURL | － | － | 申請した時点のグループの情報（申請した人はルームを読めないため。`groupRequests`と同じ）。 |
| createdAt | timestamp | ○ | 申請日時。 |
| updatedAt | timestamp | ○ | 状態が変わった日時。CHA-01の並び順に使う。 |

- 答えを申請した人の側に置かないのは、主催チームの記録として閉じたあと30日まで残すため（申請した人が消しても主催チームの記録は残る。ただし取り消し・アカウント削除では両方を消す）。申請した人の側に答えを複製しないのは、残す場所を1つにして消し忘れを防ぐため。
- 申請した人は`joinRequests`を読めない（主催チームのメモの`respondedBy`を見せないため）。状態は`joinApplications`で知る。

**firestore.rules**

- `joinRequests`：読めるのは主催チームの人だけ。`get(chatRoomPath(chatRoomId)).data.get('organizerIds', []).hasAny(get(groupMembershipPath(request.auth.uid, chatRoomId)).data.accountIds)`で判定する（本人のuidの下の`groupMemberships`に、そのグループに参加させている自分のアカウントがあるため、読み取り2件で済む。8.3）。書き込みはすべて禁止（Cloud Functionsのみ）。
- `joinApplications`：本人（`isOwnerOfAccount`）だけが読める。書き込みはすべて禁止。
- `chatRooms.joinQuestions`：ルーム全体がアプリから書けないため、そのままで書けない。

**関数**

| 関数 | 確かめること | 書くもの |
| --- | --- | --- |
| `postAnnouncement` | 操作する人がオフ会グループの主催チームで、読み取り専用でない。本文1〜1000文字、場所0〜100文字。20件未満（多ければ`announcement-limit`） | `announcements`に1件、`announcement_posted`。`notify`がtrueなら通知 |
| `updateAnnouncement` | 同じ。お知らせがある（無ければ`announcement-not-found`） | 本文・場所（空なら消す）・`updatedBy`・`updatedAt`。システムメッセージは出さない。`notify`がtrueなら通知 |
| `deleteAnnouncement` | 主催チームで、読み取り専用でない。無ければ何もしない | お知らせを消す。システムメッセージ・通知は出さない |
| `updateMeetupEvent` | 主催チームで、読み取り専用でない。閉じていない（閉じていれば`group-closed`）。`eventAt`は必須。今の値と違うときは、今より後（端末の時計のずれとして10分前まで許す）から366日後までであること（違えば`invalid-event-at`。同じ値なら、会が始まったあとでも場所だけ直せる）。`closeAfterDays`（任意、1〜14の整数）。期限が変わるときは、新しい`closesAt`が今から1時間より後であること（違えば`invalid-close-days`、8.17） | `eventAt`・`eventPlace`（空なら消す）・`eventUpdatedAt`・`eventUpdatedBy`・`closeAfterDays`・`closesAt`・`closeState: "scheduled"`。日時・場所が変われば`event_updated`、閉じる日が変われば`close_updated`。参加者の`chatList.closesAt`。`notify`がtrueなら通知。何も変わらなければ何もしない |

- 件数の上限（20件）は、トランザクションの中で`announcements`を数えてから書く。同時に出しても上限を超えない。
- 通知は、操作した人を除く参加者のうち、8.8と同じく通知を受け取る宛先（アカウントの通知がオンで、このグループの通知をオフにしていない）に、固定文言「お知らせがあります」で送る（`type: "announcement"`）。
| `applyToJoinGroup` | トークンが有効、オフ会グループ、本人が未参加・読み取り専用でない・参加の上限に達していない、答えの数が質問の数と同じで各1〜100文字（違えば`invalid-answers`）。承認待ち・キャンセル待ちの申請があれば何も書かず、その状態を返す | `joinRequests`と`joinApplications`を同じトランザクションで作る（前の申請は置き換える）。満員なら`waitlisted`、そうでなければ`pending`。主催チームの全員に通知（`type: "join_request"`） |
| `cancelJoinApplication` | 本人のアカウント | 承認待ち・キャンセル待ちなら`joinRequests`と`joinApplications`を消す。断られた・閉じた結果なら`joinApplications`だけを消す（結果を見終えた） |
| `respondToJoinRequest` | 操作する人が主催チームで読み取り専用でない。申請が承認待ちかキャンセル待ち（無ければ`join-request-not-found`） | 断る：`joinRequests`を`declined`、`joinApplications`を`declined`にし、申請した人に通知。承認：満員でなければ参加の処理（8.5）と同じトランザクションで`joinRequests`を`approved`にし、`joinApplications`を消し、通知。満員なら、承認待ちは`waitlisted`にして通知し`{result: "waitlisted"}`を返す。キャンセル待ちのままなら`group-full`。申請した人が読み取り専用・参加の上限なら`applicant-unavailable`（申請は残す） |
| `updateJoinQuestions` | 操作する人が主催チーム。0〜3件、各1〜100文字（前後の空白を除く。違えば`invalid-questions`） | `chatRooms.joinQuestions`（空なら消す） |
| `inviteToGroup` | オフ会グループでは、操作する人が主催チーム（違えば`not-organizer`）。招待の後の流れ（8.7）は普通のグループと同じで、主催チームの承認（`joinRequests`）は通らない | － |
| `joinGroupByLink` | オフ会グループなら`approval-required`で拒む（申請を通さない参加をさせないため。古いアプリもここで止まる） | － |
| `previewGroupInvite` | － | 今の結果に`isMeetup`・`joinQuestions`・`applicationStatus`（本人の`joinApplications`の状態。無ければnull）を足す |

- 満員の判定は`participantIds`の件数が定員以上であること。定員は`capacityOf(room)`で、`room.capacity`（8.19）があればその値、無ければ人数の上限（100人）。承認の判定は参加の処理のトランザクションの中で行うので、同時に承認しても定員を超えない。
- キャンセル待ちの繰り上げと知らせは8.19。順番は`createdAt`の昇順。
- 承認で参加した人の`members`の`joinedVia`は`"link"`、`approvedBy`に承認した人のaccountIdを持つ。システムメッセージは今の`member_joined`（`senderId`は参加した本人）。
- 主催チームがメンバーの答えを見るときは、`joinRequests/{そのメンバーのaccountId}`を1件読み（ルールで主催チームだけに許す）、`status`が`approved`で`answers`が空でなければ出す。
- 申請した人が参加の処理（招待への参加など、別の経路）で参加したときも、参加の処理が`joinApplications`を消し、承認待ち・キャンセル待ちの`joinRequests`を`approved`にする。

**閉じたとき・削除したときの口**

- `closeJoinRequests(db, chatRoomId)`（`groups.js`から公開）：承認待ち・キャンセル待ちの`joinRequests`を`closed`に、`joinApplications`を`closed`にし、申請した人に通知（「{グループ名}に参加できませんでした」）。グループを閉じる処理（8.17）がこれを呼ぶ。グループの削除（8.9、最後の1人の退会）でも、`joinRequests`を消す前に呼ぶ。
- 閉じたあとの片付けは、`joinRequests`を`recursiveDelete`する（答えを消す）。`joinApplications`の`closed`・`declined`は、本人が「閉じる」で消すまで残る。
- アカウント削除（`onAccountSoftDeleted`）・退会（`withdrawUser`）：`joinApplications`の各グループの`joinRequests/{accountId}`を消してから、`joinApplications`を消す。

**通知**

| 宛先 | `type` | 本文（日本語） | タップで開く |
| --- | --- | --- | --- |
| 主催チームの全員 | `join_request` | 参加の申請が届きました（固定文言） | トーク（CHA-02）とGRP-09 |
| 申請した人 | `join_result`（`status: "approved"`） | {グループ名}への参加が承認されました | トーク |
| 申請した人 | `join_result`（`status: "waitlisted"`） | {グループ名}のキャンセル待ちになりました | CHA-01の「参加の申請」 |
| 申請した人 | `join_result`（`status: "declined"`） | {グループ名}への参加は承認されませんでした | CHA-01の「参加の申請」 |
| 申請した人 | `join_result`（`status: "closed"`） | {グループ名}に参加できませんでした | CHA-01の「参加の申請」 |

- 申請した人への通知は、本人がまだグループを読めず、どのグループか分からないと意味が無いため、グループ名を入れる。データには`groupName`も入れ、アプリ内バナーも同じ文言にする。
- いずれもアカウントの通知設定（`messages`）に従う。グループの通知オフ（`mutedGroupIds`）では止めない（申請した人はまだ参加しておらず、主催チームは答えるまで残るため）。

### 8.17 期限・期限の前の知らせ・閉じたあとの片付け

機能は機能仕様書4.7.8.6〜4.7.8.8、画面は画面設計書5.10.8（GRP-08）・5.10.11（CHA-01・CHA-02）を参照する。

**期限の持ち方**

- ルームに`closeAfterDays`（会の日時の何日後か）と、そこから計算した`closesAt`を持つ。`closesAt`だけでなく日数を持つのは、会の日時が変わったときに「会の{N}日後」のNを変えずに期限をずらすため。
- `closesAt`は`updateMeetupEvent`だけが、`eventAt`と同じトランザクションで書く。`eventAt`が無い間は`closesAt`・`closeState`を持たない（期限も知らせも動かない）。
- 延長の上限（会の日から14日）は、`closeAfterDays`の範囲（1〜14）で守る。回数の上限は付けない。
- 閉じたかは「`closedAt`がある、または今が`closesAt`以後」で決める（firestore.rulesの`isRoomClosed`、Cloud Functionsの`isRoomClosed`）。定時の処理が遅れても、期限の時刻から書き込みを拒める。閉じたあとは`updateMeetupEvent`も拒むので、開き直すことは無い。

**閉じたあとに拒む書き込み**

| 場所 | 拒むもの |
| --- | --- |
| firestore.rules | グループのメッセージの作成、リアクション（`reactions`・`reactedBy`）、送信取消（`unsentAt`）。自分の画面からの削除（`hiddenFor`）と`members.lastReadAt`は許す |
| storage.rules | トークの画像（`chatRooms/{id}/images/`）とグループの画像（`chatRooms/{id}/photo/`）の作成 |
| Cloud Functions（`group-closed`） | お知らせ・会の日時（8.15）、招待・招待への参加・招待リンクの取得と再発行・招待リンクのプレビューと参加、参加の申請・承認と断る・参加時の質問（8.16）、主催チームに誘う・答える・外す（8.14）、退会させる、名前・画像の変更、友だち申請を送る（3.2.5）、出欠に答える・締切・催促（8.18）、定員の変更（8.19） |

- 自分で抜ける（`leaveGroup`）は閉じたあとも許し、主催チームの最後の1人の判定（`last-organizer`）もしない。閉じたあとは運営の操作が無いため。
- 届いた友だち申請の承認・拒否（`respondToFriendRequest`）はグループを見ないので、閉じたあとも30日はできる。
- 出欠・定員・定型連絡など、あとから足す書き込みも、`isRoomClosed`で拒む。

**定時の処理`processMeetupLifecycle`**（5分ごと。`meetup_lifecycle.js`）

1. `closeState == "scheduled"`かつ`closesAt <= 今+24時間`のルームを引く（1回200件まで）。それぞれルームのトランザクションで読み直し、次のどれか1つをする。
   - `closesAt <= 今`　→　閉じる（下記）。
   - `closesAt - 今 <= 1時間`で、`closeNotice1hFor`が今の`closesAt`でない　→　1時間前の知らせ。`closeNotice1hFor`と`closeNotice24hFor`に今の`closesAt`を書く（24時間前の知らせは飛ばす）。
   - `closeNotice24hFor`が今の`closesAt`でない　→　24時間前の知らせ。`closeNotice24hFor`に今の`closesAt`を書く。
   - 知らせは、システムメッセージ`closing_soon`（`hoursLeft`）をトランザクションの中で書き、通知はトランザクションの後に送る。同じ期限で2回送らないよう、送った印をトランザクションで先に書く（通知が失敗しても送り直さない。トークのシステムメッセージは残る）。
2. 閉じる：トランザクションで`closeState: "closed"`・`closedAt`・`purgeAt`（`closesAt`の30日後）と`group_closed`を書く。続けて、参加者の`chatList.closedAt`、`closeJoinRequests`（8.16）、`groupInvites`と`groupRequests`の削除をする。
3. `closeState == "closed"`かつ`purgeAt <= 今`のルームを引き（1回20件まで）、片付ける（下記）。

- 通知：`type: "group_closing"`・`accountId`・`chatRoomId`・`hoursLeft`。文言は「{グループ名}は24時間以内に閉じます」「{グループ名}は1時間以内に閉じます」。アカウントの通知設定（`messages`）に従い、グループの通知オフ（`mutedGroupIds`）では止めない。
- 1回で終わらなかった分は、次の回（5分後）に続きから処理する。各段階はルームの状態を読み直すので、2回動いても同じ結果になる。

**片付け`purgeClosedGroup`**

1. 参加者ごとに、トランザクションで`chatList`の行・`members`・`groupMemberships`の該当のaccountIdを消し、`ownedAccounts`の`groupJoinedCount`を1減らし、`mutedGroupIds`からこのグループを外す（システムメッセージは出さない）。
2. 作成者の`groupCreatedCount`を1減らし、ルームの`participantIds`を空にして`deletedAt`と`closeState: "purged"`を付ける（通報でルームが残っても、もう引かれない）。
3. このグループから送った友だち申請を消す（`deleteFriendRequestsOfRoom`、3.2.5）。
4. グループの削除（8.9の`deleteGroupData`）で、`joinRequests`（答え）・`groupInvites`・`groupRequests`・`messages`・`announcements`・`albums`・Storageの`chatRooms/{chatRoomId}/`以下・ルームを消す。通報があれば、8.9と同じくメッセージとStorageを残す。
5. アルバム（3.13）は、通報があっても`albums`・`items`とStorageの`chatRooms/{chatRoomId}/albums/`以下を消す（`albums.js`の`deleteRoomAlbums`。通報された項目は`reportedAlbumItems`に複製済み）。精算の記録は、`meetup_lifecycle.js`の`CLOSED_GROUP_CLEANUPS`に消す処理を足す（`CLOSED_GROUP_CLEANUPS`は1〜4の前に、グループごとに順に呼ばれる。今は3とアルバム）。

- 再実行しても続きから処理できる（消えている行・アカウントは飛ばす）。
- `joinApplications`の`closed`は、本人が「閉じる」で消すまで残す（8.16）。

### 8.18 出欠と締切・催促

機能は機能仕様書4.7.8.9、画面は画面設計書5.10（CHA-02・GRP-11）を参照する。オフ会グループだけが対象。

**データ**

`chatRooms/{chatRoomId}/attendance/{accountId}`（メンバーの出欠。メンバー全員が読める）

| フィールド | 型 | 必須 | 説明 |
| --- | --- | --- | --- |
| accountId | string | ○ | ドキュメントIDと同値。答えたメンバー。 |
| response | string | ○ | `"yes"`（参加）／`"no"`（不参加）。未回答はドキュメントが無い。 |
| updatedAt | timestamp | ○ | 最後に答えた日時。 |

- 締切（`attendanceDeadline`）・自動の催促の日時（`attendanceReminderAt`）・主催チームが最後に催促した日時（`attendanceRemindedAt`）は、ルーム（`chatRooms/{chatRoomId}`）に持つ（8.2）。
- 答えを1人1件のドキュメントにするのは、同時に答えてもぶつからないようにするため。100人でも監視して読める件数に収まる。
- 未回答は「`participantIds`にいて`attendance`にいない人」。グループを抜けた人の答えは、退会の処理（`removeFromGroup`）が同じトランザクションで消す。
- 精算は、`attendance`のうち`response == "yes"`のaccountIdを対象の初期値にする（`attendance.js`の`attendingAccountIds(db, chatRoomId)`）。
- コメントは持たない。

**firestore.rules**

- `attendance`：読めるのはメンバー（`isGroupMember`）。書き込みはすべて禁止（Cloud Functionsのみ。参加中・読み取り専用でないこと・閉じたあとの確かめを1か所で行うため）。
- ルームの`attendanceDeadline`などは、ルーム全体がアプリから書けないため、そのままで書けない。

**関数**（`attendance.js`）

| 関数 | 確かめること | 書くもの |
| --- | --- | --- |
| `setAttendance` | 操作する人がオフ会グループのメンバーで、閉じていない（閉じていれば`group-closed`、8.17）、読み取り専用でない。`response`が`"yes"`か`"no"`（違えば`invalid-response`） | `attendance/{accountId}`（`response`・`updatedAt`）。同じ答えなら何もしない。システムメッセージ・通知は出さない |
| `updateAttendanceDeadline` | 主催チームで、閉じていない、読み取り専用でない。`deadline`はミリ秒かnull（nullで締切なし）。今の値と違うときは、今より後（10分前まで許す）から366日後まで、`eventAt`があればそれ以下（違えば`invalid-deadline`） | `attendanceDeadline`（nullなら消す）。締切の24時間前が今より後なら`attendanceReminderAt`にその日時、そうでなければ消す。`attendance_deadline_updated`。同じ値なら何もしない |
| `remindAttendance` | 主催チームで、閉じていない、読み取り専用でない。`attendanceRemindedAt`から6時間たっている（違えば`reminder-too-soon`）。未回答の人がいる（いなければ何もせず`{count: 0}`） | `attendanceRemindedAt`。未回答の人に通知（`type: "attendance_reminder"`）。`{count}`を返す |
| `sendAttendanceReminders`（30分ごと） | `attendanceReminderAt`が今以前のルーム。削除済み（`deletedAt`）・閉じた（`closesAt`を過ぎた・`closedAt`がある、8.17）ルームは送らずに`attendanceReminderAt`だけ消す | トランザクションで`attendanceReminderAt`を消してから（2回送らないため）、未回答の人に通知 |

- 通知は、アカウントの通知設定（`messages`）がオンの未回答の人に、固定文言「出欠の回答をお願いします」で送る（`type: "attendance_reminder"`、タップでトーク）。グループの通知オフ（`mutedGroupIds`）では止めない。
- グループの削除（8.9）は`attendance`も消す。閉じたあとの片付けも`attendance`を`recursiveDelete`する。

### 8.19 定員とキャンセル待ち

機能は機能仕様書4.7.8.10、画面は画面設計書5.10（GRP-03・GRP-05・GRP-09）を参照する。申請と答えのデータは8.16のまま。

**データ**

- 定員は`chatRooms.capacity`（2〜100の整数。無ければ100人、8.2）。`capacityOf(room)`が読む。
- 繰り上がった申請は、`joinRequests`の`status`を`"waitlisted"`から`"pending"`に戻し、`promotedAt`（繰り上がった日時）を足す。`joinApplications`の`status`も`"pending"`に戻す。`createdAt`は変えない（GRP-09の並びは申請した順のまま）。

| フィールド（`joinRequests`に追加） | 型 | 必須 | 説明 |
| --- | --- | --- | --- |
| promotedAt | timestamp | － | キャンセル待ちから繰り上がった日時。繰り上がったことのある申請だけ持つ。 |

**キャンセル待ちに入る判定**（`applyToJoinGroup`）

- 満員（`participantIds`の件数 ≧ 定員）か、キャンセル待ち（`waitlisted`）の申請が1件でもあれば`waitlisted`、そうでなければ`pending`。キャンセル待ちの有無は、トランザクションの中で`joinRequests`を`status == "waitlisted"`で1件だけ読んで確かめる。

**繰り上げ**（`groups.js`の`promoteWaitlist(db, chatRoomId)`）

1. トランザクションで、ルームと、`joinRequests`の`status in ["pending", "waitlisted"]`を読む。閉じたルーム（8.17）では繰り上げない（残った申請は閉じる処理が終わらせる）。
2. 空き＝定員 − `participantIds`の件数 − `pending`の件数。空きが1以上なら、`waitlisted`を`createdAt`の昇順に並べ、先頭から空きの数だけ`pending`にし、`promotedAt`を書く（`joinApplications`も`pending`に）。並べ替えはメモリで行う（複合インデックスを作らない。1グループの申請は多くて数百件）。
3. トランザクションのあと、繰り上がった人に`join_result`（`status: "pending"`、本文「{グループ名}のキャンセル待ちから繰り上がりました」、タップでCHA-01の「参加の申請」）、主催チームの全員に`join_request`（`promoted: "true"`、本文「キャンセル待ちから繰り上がった人がいます」、タップでトークとGRP-09）を送る。

呼ぶところ：`removeFromGroup`（グループが残るとき）、`updateGroupCapacity`、`respondToJoinRequest`（断ったとき）、`cancelJoinApplication`（承認待ちを取り消したとき）。いずれも処理の本体が終わったあとに呼び、繰り上げの失敗では元の処理を失敗にしない（ログに残し、次のきっかけでやり直す）。再実行しても、空きの分しか繰り上げない。

**関数**

| 関数 | 確かめること | 書くもの |
| --- | --- | --- |
| `updateGroupCapacity` | 主催チームで、閉じていない（閉じていれば`group-closed`、8.17）、読み取り専用でない。`capacity`は2〜100の整数かnull（nullで定員なし。違えば`invalid-capacity`） | `chatRooms.capacity`（nullなら消す）、`capacity_updated`。同じ値なら何もしない。そのあと繰り上げ |
| `previewGroupInvite` | － | 今の結果に`capacity`（無ければnull）と`isFull`（満員か、キャンセル待ちがある）を足す |

- 今のメンバーの数より小さい定員も受け付ける（誰も退会させない）。
- 友だちを選んだ招待（8.7）は、キャンセル待ちの列を通らない。満員なら今のまま`group-full`。

**firestore.rules**

- 変更なし（`capacity`はルームのフィールドで、アプリから書けない。`joinRequests`は主催チームだけが読める）。

### 8.20 精算

機能は機能仕様書4.7.8.12、画面は画面設計書5.10（CHA-02・GRP-12・GRP-13）を参照する。オフ会グループだけが対象。アプリの中でお金は動かさない（送金リンクを見せ、払ったかを記録するだけ）。

**データ**

`chatRooms/{chatRoomId}.settlement`（精算の設定。ルームのフィールドなので、メンバー全員が読める。精算が無ければ持たない）

| フィールド | 型 | 必須 | 説明 |
| --- | --- | --- | --- |
| totalAmount | number | ○ | 合計の金額（円、1〜10,000,000の整数）。 |
| roundingUnit | number | ○ | 端数の単位（円）。`1`・`10`・`100`のどれか。一人ひとりの額をこの単位に切り上げる。 |
| tiers | array | ○ | 区分（1〜10件）。各要素は`{tierId, name, percent}`。`tierId`は端末で作る英数字と`_`・`-`の1〜32文字で、精算の中で重ならない。`name`は1〜20文字。`percent`は0〜500の整数。 |
| paymentLinks | array | ○ | 送金先（0〜5件）。各要素は`{linkId, service, kind, value, label, addedBy, addedAt}`。`service`は`"paypay"`／`"other"`、`kind`は`"url"`／`"paypayId"`（`"paypayId"`は`service`が`"paypay"`のときだけ）。`value`はリンク（https、PayPayは`paypay.ne.jp`かそのサブドメイン、500文字まで）かPayPay ID（英数字と`_`・`.`・`-`の3〜40文字）。`label`は`service`が`"other"`のときだけ持つサービスの名前（1〜20文字）。`addedBy`は貼ったaccountId。 |
| startedAt | timestamp | ○ | 精算を始めた日時。 |
| updatedAt | timestamp | ○ | 最後に設定を保存した日時。 |
| updatedBy | string | ○ | 最後に設定を保存したaccountId。 |
| remindedAt | timestamp | － | 主催チームが最後に催促した日時（6時間に1回までの判定）。 |
| autoRemindedFor | timestamp | － | 閉じる前の自動の催促を送ったときの`closesAt`。今の`closesAt`と違えば、新しい期限の自動の催促がまだ。 |

`chatRooms/{chatRoomId}/settlementShares/{accountId}`（一人ひとりの額と払った記録。主催チームの人は全員の分を、そのほかのメンバーは自分の分だけを読める）

| フィールド | 型 | 必須 | 説明 |
| --- | --- | --- | --- |
| accountId | string | ○ | ドキュメントIDと同値。精算の対象の人。 |
| tierId | string | ○ | その人の区分（`settlement.tiers`の`tierId`）。 |
| amount | number | ○ | 払う額（円）。保存のたびにサーバーが計算する。0なら払う額なし。 |
| status | string | ○ | `"unpaid"`（未払い）／`"reported"`（本人が払ったを付けた。確認待ち）／`"confirmed"`（主催チームが確定した）。 |
| method | string | － | 払い方。`"link"`（送金サービス）／`"cash"`（現金）／`"other"`（そのほか）。`unpaid`では持たない。 |
| reportedAt | timestamp | － | 本人が払ったを付けた日時。 |
| confirmedAt | timestamp | － | 主催チームが確定した日時。 |
| confirmedBy | string | － | 確定した主催チームのaccountId。 |
| updatedAt | timestamp | ○ | 最後に変わった日時。 |

- 一人ひとりの額と払った記録を、ルームではなく1人1件のドキュメントにするのは、ほかのメンバーに見せない（rulesで本人と主催チームだけに絞る）ため。
- 抜けた人のドキュメントは消さない（払った記録を残すため。`removeFromGroup`は触らない）。催促は`participantIds`にいる人だけに送る。
- 精算の対象の初期値（出欠で「参加」の人）は、アプリが`attendance`（8.18）から作ってGRP-13に入れる。

**計算**（`settlement.js`の`computeAmounts`。アプリの`computeSettlementAmounts`も同じ）

- 対象の人の割合の合計をSとすると、一人ひとりの額＝ceil(合計 × 割合 ÷ (S × 単位)) × 単位。割合0の人とS＝0のときは0。
- 整数の掛け算と割り算だけで計算する（割り算の誤差で1単位ずれないよう、商を掛け戻して確かめる）。

**firestore.rules**

- `settlementShares`：読めるのは主催チームの人（`isGroupOrganizer`）と、本人（`isOwnerOfAccount`）でメンバー（`isGroupMember`）の人。書き込みはすべて禁止（Cloud Functionsのみ）。
- ルームの`settlement`は、ルーム全体がアプリから書けないため、そのままで書けない。

**関数**（`settlement.js`）。どれも、操作する人がオフ会グループのメンバーで、閉じていない（閉じていれば`group-closed`、8.17）、読み取り専用でないことを確かめる。

| 関数 | 確かめること | 書くもの |
| --- | --- | --- |
| `saveSettlement` | 主催チーム。`totalAmount`・`roundingUnit`・`tiers`・`shares`（`{accountId, tierId}`の1〜100件、重ならない、`tierId`は`tiers`にある）が決まりに合う（違えば`invalid-settlement`）。`shares`の人は今のメンバーか、すでに記録のある人（抜けた人） | 一人ひとりの額を計算し、`settlementShares`を作る・直す・消す（`shares`にいない人の記録は消す）。額が変わった人で`status`が`unpaid`でない人は、`unpaid`に戻して`method`・`reportedAt`・`confirmedAt`・`confirmedBy`を消す。ルームの`settlement`（初めてなら`paymentLinks: []`と`startedAt`も）。`settlement_started`（初めて）か`settlement_updated`。未払いに戻した人数`{resetCount}`を返す |
| `deleteSettlement` | 主催チーム。精算が無ければ何もしない | `settlementShares`を全部消し、ルームの`settlement`を消す。`settlement_deleted` |
| `addSettlementLink` | 主催チーム。精算がある（無ければ`settlement-not-found`）。リンクが決まりに合う（違えば`invalid-link`）。5件未満（違えば`link-limit`） | `settlement.paymentLinks`の最後に足す（`linkId`はサーバーが作る） |
| `removeSettlementLink` | 主催チーム。精算がある | `settlement.paymentLinks`から`linkId`のものを外す。無ければ何もしない |
| `reportSettlementPayment` | 本人の記録があり、額が0より大きい（違えば`not-settlement-target`）。`paid`が真偽値で、真なら`method`が3つのどれか（違えば`invalid-payment`）。`confirmed`なら`payment-confirmed` | `paid`が真で`unpaid`なら`reported`・`method`・`reportedAt`。偽で`reported`なら`unpaid`に戻す。ほかは何もしない |
| `confirmSettlementPayment` | 主催チーム。相手の記録があり、額が0より大きい。`method`はnullか3つのどれか | `confirmed`が真なら`confirmed`・`confirmedAt`・`confirmedBy`、`method`は今の値か受け取った値（無ければ`"other"`）。偽なら`unpaid`に戻す |
| `remindSettlement` | 主催チーム。`settlement.remindedAt`から6時間たっている（違えば`reminder-too-soon`）。未払いの人がいる（いなければ何もせず`{count: 0}`） | `settlement.remindedAt`。未払いの人に通知（`type: "settlement_reminder"`）。`{count}`を返す |

- 閉じる前の自動の催促（`remindUnpaidBeforeClose`）：`processMeetupLifecycle`（8.17）が閉じる前の知らせを出したあとに呼ぶ。トランザクションで、ルームが閉じておらず、`settlement`があり、`settlement.autoRemindedFor`が今の`closesAt`と違うときだけ、`autoRemindedFor`に今の`closesAt`を書いてから未払いの人に通知する（2回送らないため）。
- 未払いの人＝`settlementShares`のうち、`participantIds`にいて、`amount`が0より大きく、`status`が`"unpaid"`の人。
- 通知は、アカウントの通知設定（`messages`）がオンの人に、固定文言「精算の支払いをお願いします」で送る（`type: "settlement_reminder"`、タップでトーク）。グループの通知オフ（`mutedGroupIds`）では止めない。
- 索引：どのクエリもルームの下のコレクションの全件か1件を読むだけなので、新しい索引は要らない。

**片付け**

- グループの削除（8.9。`deleteGroupData`）は`settlementShares`を`recursiveDelete`する。通報でルームを残すときも、ルームの`settlement`を消す。
- 閉じてから30日後の片付け（8.17）は`deleteGroupData`を呼ぶので、精算の記録も一緒に消える。

### 8.21 次の回のオフ会グループ

機能は機能仕様書4.7.8.13、画面は画面設計書5.10.15（GRP-14）を参照する。

**callable `createNextRound`**（`next_round.js`）

- 入力：`accountId`・`chatRoomId`（前の回）・`inviteAccountIds`（招待する前の回のメンバー）・`name`（省略すると前の回の名前）。出力：`chatRoomId`（次の回）。
- 確かめること：操作する人の有効なアカウントで、読み取り専用でない。前の回が削除されていないオフ会グループで、操作する人がメンバーかつ主催チーム（`organizerIds`）。前の回が閉じている（`isRoomClosed`、8.17）。今が`purgeAt`（無ければ`closesAt`の30日後）より前（過ぎていれば`group-deleted`）。前の回の`nextChatRoomId`が無いか、その次の回が削除済み（あれば`next-round-exists`）。
- 1つのトランザクションで、次の回のルーム・作った人の`members`（`joinedVia: "create"`）・`groupMemberships`・作成数と参加数・システムメッセージ`group_created`・`chatList`を書き（`createGroup`と同じ`writeNewGroup`。作成数・参加数の上限も同じ）、前の回に`nextChatRoomId`・`nextRoundCreatedBy`・`nextRoundCreatedAt`を書く。
- 次の回のルーム：`groupKind: "meetup"`、`organizerIds`・`participantIds`は作った人だけ、`previousChatRoomId`。前の回から`joinPolicy`・`joinQuestions`・`capacity`・`closeAfterDays`を写す。`eventAt`・`eventPlace`・`closesAt`・出欠の締切は持たない。
- 前の回に画像（`photoPath`）があれば、Storageで`chatRooms/{次の回}/photo/{同じファイル名}`へ写し、`photoURL`・`photoPath`と作った人の`chatList.photoURL`を書く。写せなければ画像なしで続ける（前の回の片付けで、写した画像は消えない）。
- 招待：`inviteAccountIds`のうち、前の回の`participantIds`（閉じたときのメンバー）にいる人（作った人を除く）ごとに、退会済み・どちらかのブロックを飛ばして、`accounts/{相手}/groupRequests/{次の回}`を書き、招待の通知（`type: "group_invite"`）を送る。`previousChatRoomId`・`previousName`を持ち、前の回の`organizerIds`の人には`asOrganizer: true`を付ける。友だちかどうか・`inviteCounters`（3.1.3）・拒否の記録（`groupRequestDeclines`）は見ない。判定の結果は返さない。

**承諾**（`respondToGroupRequest`）

- 普通の招待と同じ`joinGroup`で入る（定員・参加数の上限・読み取り専用・閉じたあとの判定も同じ）。招待に`previousChatRoomId`があれば、`members.joinedVia`を`"next_round"`にする。`asOrganizer`なら、同じトランザクションで`organizerIds`にも足し、システムメッセージ`organizer_added`を書く。
- 招待は、次の回が閉じたとき（8.17の2）・削除したとき（8.9）に、ほかの`groupRequests`と一緒に消える。前の回の片付け（8.17）では消えない（`chatRoomId`が次の回のため）。

**firestore.rules**

- 変更なし。`chatRooms`（`nextChatRoomId`ほか）・`groupRequests`（`previousChatRoomId`ほか）は、今のままアプリから書けない。
