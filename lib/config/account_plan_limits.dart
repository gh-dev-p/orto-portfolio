/// プラン（`users/{uid}.plan`）ごとに作成できるAccount数の上限。
///
/// firestore.rulesの`isWithinAccountLimit`にも同じ対応表があり、変更時は両方を更新すること
/// （アプリ側の上限は画面表示用で、作成の拒否はルール側で保証する）。
abstract final class AccountPlanLimits {
  static const freePlan = 'free';
  static const grade1Plan = 'grade1';
  static const grade2Plan = 'grade2';

  /// 上限なしのプラン（運営者用）。
  static const adminPlan = 'admin';

  static const Map<String, int> byPlan = {freePlan: 2, grade1Plan: 3, grade2Plan: 5};

  /// [plan]の上限を返す。無制限の場合はnull。`users/{uid}`が未作成（初回アカウント作成前）や
  /// 未知のプランの場合は、無料プランの上限として扱う。
  static int? forPlan(String? plan) => plan == adminPlan ? null : byPlan[plan] ?? byPlan[freePlan]!;

  /// [plan]で無料プランより増えるAccount数（SET-07の「＋1アカウント」）。
  static int extraOverFree(String plan) => forPlan(plan)! - byPlan[freePlan]!;

  /// [accountCount]件のAccountを持つ[plan]が、上限を超えているか（機能仕様書4.2.1.3）。
  /// 判定はfirestore.rulesの`isWithinAccountLimit`と同じで、アプリ側は画面表示用。
  static bool isOverLimit(String? plan, int accountCount) {
    final limit = forPlan(plan);
    return limit != null && accountCount > limit;
  }
}
