import 'package:flutter_test/flutter_test.dart';
import 'package:multi_id_msg/domain/models/group.dart';
import 'package:multi_id_msg/l10n/app_localizations_ja.dart';
import 'package:multi_id_msg/ui/group/view_models/group_create_viewmodel.dart';
import 'package:multi_id_msg/ui/group/widgets/group_failure_message.dart';
import 'package:multi_id_msg/ui/group/widgets/group_system_text.dart';

void main() {
  final l10n = AppLocalizationsJa();

  test('Cloud Functionsの理由のコードを読み取る', () {
    expect(GroupFailure.fromValue('read-only'), GroupFailure.readOnly);
    expect(GroupFailure.fromValue('create-limit'), GroupFailure.createLimit);
    expect(GroupFailure.fromValue('なにか別の値'), GroupFailure.unknown);
    expect(GroupFailure.fromValue(null), GroupFailure.unknown);
  });

  test('理由ごとの文言を出し、分からない理由は既定の文言にする', () {
    expect(groupFailureMessage(l10n, GroupFailure.groupFull, fallback: '失敗'), 'グループの人数が上限に達しています');
    expect(groupFailureMessage(l10n, GroupFailure.unknown, fallback: '失敗'), '失敗');
  });

  group('groupSystemText', () {
    String text(String? type) =>
        groupSystemText(l10n, systemType: type, actorName: 'A', targetName: 'B', groupName: 'G');

    test('種類ごとの本文を作る', () {
      expect(text('member_joined'), 'Bさんが参加しました');
      expect(text('member_left'), 'Bさんが退会しました');
      expect(text('member_removed'), 'AさんがBさんを退会させました');
      expect(text('group_renamed'), 'Aさんがグループ名を「G」に変更しました');
    });

    test('知らない種類は未対応の文言にする', () {
      expect(text('future_type'), l10n.chaUnsupportedMessage);
    });
  });

  group('GroupCreateState', () {
    test('前後の空白を除いて1〜50文字なら作成できる', () {
      expect(const GroupCreateState(name: '   ').canCreate, isFalse);
      expect(const GroupCreateState(name: ' 友だち ').canCreate, isTrue);
      expect(GroupCreateState(name: 'あ' * 50).canCreate, isTrue);
      expect(GroupCreateState(name: 'あ' * 51).canCreate, isFalse);
    });

    test('方式の既定は承認制', () {
      expect(const GroupCreateState().joinPolicy, GroupJoinPolicy.approval);
    });
  });
}
