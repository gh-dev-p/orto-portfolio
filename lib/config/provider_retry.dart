/// Providerの自動再試行（Riverpod 3の既定）を行わない設定。[ProviderScope]・[ProviderContainer]の`retry`に渡す。
///
/// Riverpod 3は、失敗したProviderを既定で最大10回、間隔を空けて作り直す。その間は`AsyncError`ではなく
/// エラーを持った`AsyncLoading`になるため、エラー表示（再試行ボタン等）が出ずに読み込み中のままになる。
/// また、Firestoreの監視がエラーになるたびに監視を張り直す。エラーはそのまま画面へ出し、再試行は
/// ユーザーの操作（再試行ボタン・画面の開き直し）で行うこれまでの挙動に揃える。
Duration? noProviderRetry(int retryCount, Object error) => null;
