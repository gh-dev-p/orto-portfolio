import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multi_id_msg/config/provider_retry.dart';
import 'package:multi_id_msg/config/service_providers.dart';
import 'package:multi_id_msg/data/repositories/block/block_repository.dart';
import 'package:multi_id_msg/data/repositories/report/report_repository.dart';
import 'package:multi_id_msg/domain/models/report_reason.dart';
import 'package:multi_id_msg/ui/report/view_models/report_viewmodel.dart';

class _FakeReportRepository implements ReportRepository {
  final reports = <Map<String, Object?>>[];
  bool fail = false;

  @override
  Future<void> report({
    required String reporterAccountId,
    required String? targetAccountId,
    required ReportReason reason,
    String? detail,
    String? messageId,
    String? chatRoomId,
    String? albumId,
    String? albumItemId,
  }) async {
    if (fail) throw Exception('report failed');
    reports.add({
      'reporter': reporterAccountId,
      'target': targetAccountId,
      'reason': reason,
      'detail': detail,
      'messageId': messageId,
    });
  }
}

class _FakeBlockRepository implements BlockRepository {
  final blocked = <String>[];
  bool fail = false;

  @override
  Future<void> blockAccount({required String accountId, required String targetAccountId}) async {
    if (fail) throw Exception('block failed');
    blocked.add('$accountId>$targetAccountId');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _FakeReportRepository reports;
  late _FakeBlockRepository blocks;
  late ProviderContainer container;
  const args = (
    myAccountId: 'alice',
    targetAccountId: 'bob',
    messageId: 'm1',
    chatRoomId: null,
    albumId: null,
    albumItemId: null,
  );

  setUp(() {
    reports = _FakeReportRepository();
    blocks = _FakeBlockRepository();
    container = ProviderContainer(
      retry: noProviderRetry,
      overrides: [
        reportRepositoryProvider.overrideWithValue(reports),
        blockRepositoryProvider.overrideWithValue(blocks),
      ],
    );
    container.listen(reportViewModelProvider(args), (_, _) {});
  });

  tearDown(() => container.dispose());

  ReportViewModel viewModel() => container.read(reportViewModelProvider(args).notifier);
  ReportState state() => container.read(reportViewModelProvider(args));

  group('通報（REP-01）', () {
    test('理由を選ぶまでは送信できない', () async {
      expect(state().canSubmit, isFalse);
      expect(await viewModel().submit(), isNull);
      expect(reports.reports, isEmpty);

      viewModel().selectReason(ReportReason.spam);
      expect(state().canSubmit, isTrue);
    });

    test('理由・詳しい内容（前後の空白は除く）・メッセージを記録し、ブロックはしない', () async {
      viewModel()
        ..selectReason(ReportReason.harassment)
        ..updateDetail('  しつこい  ');

      expect(await viewModel().submit(), ReportOutcome.reported);
      expect(reports.reports.single, {
        'reporter': 'alice',
        'target': 'bob',
        'reason': ReportReason.harassment,
        'detail': 'しつこい',
        'messageId': 'm1',
      });
      expect(blocks.blocked, isEmpty);
    });

    test('ブロックも選んでいれば、通報の後にブロックする', () async {
      viewModel()
        ..selectReason(ReportReason.spam)
        ..setAlsoBlock(true);

      expect(await viewModel().submit(), ReportOutcome.reportedAndBlocked);
      expect(reports.reports, hasLength(1));
      expect(blocks.blocked, ['alice>bob']);
    });

    test('通報に失敗したら、ブロックもせず、もう一度送れる状態に戻る', () async {
      reports.fail = true;
      viewModel()
        ..selectReason(ReportReason.spam)
        ..setAlsoBlock(true);

      expect(await viewModel().submit(), ReportOutcome.failed);
      expect(blocks.blocked, isEmpty);
      expect(state().submitting, isFalse);
      expect(state().canSubmit, isTrue);
    });

    test('通報できてブロックに失敗したら、それを返す', () async {
      blocks.fail = true;
      viewModel()
        ..selectReason(ReportReason.other)
        ..setAlsoBlock(true);

      expect(await viewModel().submit(), ReportOutcome.blockFailed);
      expect(reports.reports, hasLength(1));
    });
  });
}
