import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multi_id_msg/domain/models/account.dart';
import 'package:multi_id_msg/ui/account/view_models/account_providers.dart';

class _FakeAccount implements Account {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<ProviderContainer> _container({required String plan, required List<String> kept, bool chosen = false}) async {
  final container = ProviderContainer(
    overrides: [
      userPlanProvider.overrideWith((ref) => Stream.value(plan)),
      accountsProvider.overrideWith((ref) => Stream.value([_FakeAccount(), _FakeAccount(), _FakeAccount()])),
      keptAccountsProvider.overrideWith((ref) => Stream.value((ids: kept, chosen: chosen))),
    ],
  );
  addTearDown(container.dispose);
  container.listen(userPlanProvider, (_, _) {});
  container.listen(accountsProvider, (_, _) {});
  container.listen(keptAccountsProvider, (_, _) {});
  await container.read(userPlanProvider.future);
  await container.read(accountsProvider.future);
  await container.read(keptAccountsProvider.future);
  return container;
}

void main() {
  test('上限を超えると、使い続けるアカウント以外だけ読み取り専用になる', () async {
    final container = await _container(plan: 'free', kept: ['a', 'b']);

    expect(container.read(isReadOnlyProvider('a')), isFalse);
    expect(container.read(isReadOnlyProvider('c')), isTrue);
    expect(container.read(canChooseKeptAccountsProvider), isTrue);
  });

  test('上限内なら一覧に無くても読み取り専用にならない', () async {
    final container = await _container(plan: 'grade1', kept: ['a']);

    expect(container.read(isReadOnlyProvider('c')), isFalse);
    expect(container.read(canChooseKeptAccountsProvider), isFalse);
  });

  test('選び終えていれば選べない', () async {
    final container = await _container(plan: 'free', kept: ['a', 'b'], chosen: true);

    expect(container.read(canChooseKeptAccountsProvider), isFalse);
  });
}
