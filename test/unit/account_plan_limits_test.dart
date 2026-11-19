import 'package:flutter_test/flutter_test.dart';
import 'package:multi_id_msg/config/account_plan_limits.dart';

void main() {
  test('プランごとの上限', () {
    expect(AccountPlanLimits.forPlan('free'), 2);
    expect(AccountPlanLimits.forPlan('grade1'), 3);
    expect(AccountPlanLimits.forPlan('grade2'), 5);
  });

  test('adminは無制限（null）', () {
    expect(AccountPlanLimits.forPlan('admin'), isNull);
  });

  test('users/{uid}が未作成・未知のプランは無料プランの上限として扱う', () {
    expect(AccountPlanLimits.forPlan(null), 2);
    expect(AccountPlanLimits.forPlan('unknown'), 2);
  });

  test('無料プランより増える数', () {
    expect(AccountPlanLimits.extraOverFree('grade1'), 1);
    expect(AccountPlanLimits.extraOverFree('grade2'), 3);
  });

  test('上限を超えていれば読み取り専用。上限ちょうどは対象外', () {
    expect(AccountPlanLimits.isOverLimit('free', 2), isFalse);
    expect(AccountPlanLimits.isOverLimit('free', 3), isTrue);
    expect(AccountPlanLimits.isOverLimit('grade1', 4), isTrue);
    expect(AccountPlanLimits.isOverLimit('grade2', 5), isFalse);
    expect(AccountPlanLimits.isOverLimit(null, 3), isTrue);
    expect(AccountPlanLimits.isOverLimit('admin', 100), isFalse);
  });
}
