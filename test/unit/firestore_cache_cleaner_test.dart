import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multi_id_msg/data/services/common/firestore_cache_cleaner.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _CountingFirestore implements FirebaseFirestore {
  int clearCount = 0;
  bool fails = false;

  @override
  Future<void> clearPersistence() async {
    if (fails) throw Exception('failed');
    clearCount++;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late FirestoreCacheCleaner cleaner;
  late _CountingFirestore firestore;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    cleaner = FirestoreCacheCleaner(await SharedPreferences.getInstance());
    firestore = _CountingFirestore();
  });

  test('予定が無ければ消さない', () async {
    await cleaner.clearIfRequested(firestore);
    expect(firestore.clearCount, 0);
  });

  test('予定があれば1回だけ消す', () async {
    await cleaner.request();
    await cleaner.clearIfRequested(firestore);
    await cleaner.clearIfRequested(firestore);
    expect(firestore.clearCount, 1);
  });

  test('失敗したら予定を残し、次の起動でやり直す', () async {
    await cleaner.request();
    firestore.fails = true;
    await expectLater(cleaner.clearIfRequested(firestore), throwsException);

    firestore.fails = false;
    await cleaner.clearIfRequested(firestore);
    expect(firestore.clearCount, 1);
  });
}
