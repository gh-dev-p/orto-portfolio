import 'package:cloud_firestore/cloud_firestore.dart';

// オフ会グループの精算（機能仕様書4.7.8.12、データ設計書8.20）
// アプリの中でお金は動かさない。外の送金サービスのリンク・IDを見せ、払ったかを記録するだけ

/// 合計の金額（円）の上限
const settlementMaxTotal = 10000000;

/// 端数の単位（円）。一人ひとりの額をこの単位に切り上げる
const settlementRoundingUnits = [1, 10, 100];

/// 端数の単位の初期値
const settlementDefaultRoundingUnit = 100;

/// 区分（傾斜）の数の上限
const settlementMaxTiers = 10;

/// 区分の名前の長さの上限
const settlementTierNameMaxLength = 20;

/// 区分の割合（%）の上限
const settlementMaxPercent = 500;

/// 送金リンクの数の上限
const settlementMaxLinks = 5;

/// ほかのサービスの名前の長さの上限
const settlementLinkLabelMaxLength = 20;

/// 主催チームの催促の間隔（出欠の催促と同じ）
const settlementReminderInterval = Duration(hours: 6);

/// 区分（傾斜）。割合（%）で一人ひとりの額の重みを決める（割合で決める）
class SettlementTier {
  const SettlementTier({required this.tierId, required this.name, required this.percent});

  final String tierId;
  final String name;

  /// 割合（0〜500%）。0なら払う額は0円
  final int percent;

  SettlementTier copyWith({String? name, int? percent}) =>
      SettlementTier(tierId: tierId, name: name ?? this.name, percent: percent ?? this.percent);

  Map<String, Object> toMap() => {'tierId': tierId, 'name': name, 'percent': percent};

  static SettlementTier? fromMap(Object? value) {
    if (value is! Map) return null;
    final tierId = value['tierId'];
    final name = value['name'];
    final percent = value['percent'];
    if (tierId is! String || name is! String || percent is! num) return null;
    return SettlementTier(tierId: tierId, name: name, percent: percent.toInt());
  }

  @override
  bool operator ==(Object other) =>
      other is SettlementTier && other.tierId == tierId && other.name == name && other.percent == percent;

  @override
  int get hashCode => Object.hash(tierId, name, percent);
}

/// 送金サービス（PayPayとほかのサービス）
enum SettlementLinkService {
  paypay('paypay'),
  other('other');

  const SettlementLinkService(this.value);

  final String value;

  static SettlementLinkService? fromValue(Object? value) =>
      values.where((service) => service.value == value).firstOrNull;
}

/// 送金リンクの種類（リンクか、PayPay ID）
enum SettlementLinkKind {
  url('url'),
  paypayId('paypayId');

  const SettlementLinkKind(this.value);

  final String value;

  static SettlementLinkKind? fromValue(Object? value) => values.where((kind) => kind.value == value).firstOrNull;
}

/// 主催チームの人が貼った送金リンク・PayPay ID（`settlement.paymentLinks`の1件）
class SettlementLink {
  const SettlementLink({
    required this.linkId,
    required this.service,
    required this.kind,
    required this.value,
    this.label,
    required this.addedBy,
    this.addedAt,
  });

  final String linkId;
  final SettlementLinkService service;
  final SettlementLinkKind kind;

  /// リンク（https）かPayPay ID
  final String value;

  /// ほかのサービスの名前（PayPayはnull）
  final String? label;

  /// 貼った人のアカウントID
  final String addedBy;
  final DateTime? addedAt;

  /// 開けるリンクか（PayPay IDはコピーして使う）
  bool get isUrl => kind == SettlementLinkKind.url;

  static SettlementLink? fromMap(Object? value) {
    if (value is! Map) return null;
    final service = SettlementLinkService.fromValue(value['service']);
    final kind = SettlementLinkKind.fromValue(value['kind']);
    final linkId = value['linkId'];
    final text = value['value'];
    if (service == null || kind == null || linkId is! String || text is! String) return null;
    return SettlementLink(
      linkId: linkId,
      service: service,
      kind: kind,
      value: text,
      label: value['label'] as String?,
      addedBy: value['addedBy'] as String? ?? '',
      addedAt: (value['addedAt'] as Timestamp?)?.toDate(),
    );
  }
}

/// `chatRooms/{chatRoomId}.settlement`（精算の設定、データ設計書8.20）。メンバー全員が読める
class Settlement {
  const Settlement({
    required this.totalAmount,
    required this.roundingUnit,
    required this.tiers,
    this.paymentLinks = const [],
    this.updatedAt,
    this.updatedBy,
    this.remindedAt,
  });

  /// 合計の金額（円）
  final int totalAmount;

  /// 端数の単位（円）
  final int roundingUnit;
  final List<SettlementTier> tiers;
  final List<SettlementLink> paymentLinks;
  final DateTime? updatedAt;
  final String? updatedBy;

  /// 主催チームが最後に催促した日時
  final DateTime? remindedAt;

  SettlementTier? tierOf(String tierId) => tiers.where((tier) => tier.tierId == tierId).firstOrNull;

  /// 読めない値はnull（精算なしとして扱う）
  static Settlement? fromMap(Object? value) {
    if (value is! Map) return null;
    final total = value['totalAmount'];
    final unit = value['roundingUnit'];
    final tiers = value['tiers'];
    final links = value['paymentLinks'];
    if (total is! num || unit is! num || tiers is! List) return null;
    return Settlement(
      totalAmount: total.toInt(),
      roundingUnit: unit.toInt(),
      tiers: tiers.map(SettlementTier.fromMap).nonNulls.toList(),
      paymentLinks: links is List ? links.map(SettlementLink.fromMap).nonNulls.toList() : const [],
      updatedAt: (value['updatedAt'] as Timestamp?)?.toDate(),
      updatedBy: value['updatedBy'] as String?,
      remindedAt: (value['remindedAt'] as Timestamp?)?.toDate(),
    );
  }
}

/// 払った記録の状態（本人が付け、主催チームが確かめて確定する）
enum PaymentStatus {
  /// 未払い
  unpaid('unpaid'),

  /// 本人が「払った」を付けた（主催チームの確認待ち）
  reported('reported'),

  /// 主催チームが確定した
  confirmed('confirmed');

  const PaymentStatus(this.value);

  final String value;

  static PaymentStatus fromValue(Object? value) =>
      values.where((status) => status.value == value).firstOrNull ?? unpaid;
}

/// 払い方（送金リンク・現金・そのほか）
enum PaymentMethod {
  link('link'),
  cash('cash'),
  other('other');

  const PaymentMethod(this.value);

  final String value;

  static PaymentMethod? fromValue(Object? value) => values.where((method) => method.value == value).firstOrNull;
}

/// `chatRooms/{chatRoomId}/settlementShares/{accountId}`（一人ひとりの額と払った記録、データ設計書8.20）
/// 主催チームの人は全員の分を、そのほかのメンバーは自分の分だけを読める。書くのはCloud Functionsのみ
class SettlementShare {
  const SettlementShare({
    required this.accountId,
    required this.tierId,
    required this.amount,
    this.status = PaymentStatus.unpaid,
    this.method,
    this.reportedAt,
    this.confirmedAt,
    this.confirmedBy,
  });

  final String accountId;
  final String tierId;

  /// 払う額（円）
  final int amount;
  final PaymentStatus status;
  final PaymentMethod? method;
  final DateTime? reportedAt;
  final DateTime? confirmedAt;
  final String? confirmedBy;

  /// 払う額が無い（割合0%）
  bool get isFree => amount <= 0;

  static SettlementShare? fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final amount = data?['amount'];
    if (data == null || amount is! num) return null;
    return SettlementShare(
      accountId: doc.id,
      tierId: data['tierId'] as String? ?? '',
      amount: amount.toInt(),
      status: PaymentStatus.fromValue(data['status']),
      method: PaymentMethod.fromValue(data['method']),
      reportedAt: (data['reportedAt'] as Timestamp?)?.toDate(),
      confirmedAt: (data['confirmedAt'] as Timestamp?)?.toDate(),
      confirmedBy: data['confirmedBy'] as String?,
    );
  }
}

/// 一人ひとりの払う額（データ設計書8.20「計算」。Cloud Functionsの`computeAmounts`と同じ）
/// 合計[total]を割合で分け、[unit]円に切り上げる。割合が0の人は0円。全員が0なら全員0円
Map<String, int> computeSettlementAmounts(int total, int unit, List<({String accountId, int percent})> entries) {
  final sum = entries.fold<int>(0, (acc, entry) => acc + entry.percent);
  return {
    for (final entry in entries)
      entry.accountId: sum == 0 || entry.percent == 0 ? 0 : _ceilDiv(total * entry.percent, sum * unit) * unit,
  };
}

int _ceilDiv(int numerator, int denominator) => (numerator + denominator - 1) ~/ denominator;

/// GRP-12の主催チームの一覧（機能仕様書4.7.8.12）
/// 確認待ち・未払い・確定・払う額なしに分け、それぞれ自分を先頭にする。[participantIds]にいない人は抜けた人
class SettlementSections {
  const SettlementSections({
    required this.reported,
    required this.unpaid,
    required this.confirmed,
    required this.free,
    required this.collected,
    required this.confirmedAmount,
  });

  final List<SettlementShare> reported;
  final List<SettlementShare> unpaid;
  final List<SettlementShare> confirmed;
  final List<SettlementShare> free;

  /// 全員が払うと集まる額
  final int collected;

  /// 確定した額の合計
  final int confirmedAmount;

  factory SettlementSections.of(List<SettlementShare> shares, {required String myAccountId}) {
    int meFirst(SettlementShare a, SettlementShare b) =>
        a.accountId == myAccountId ? -1 : (b.accountId == myAccountId ? 1 : 0);
    List<SettlementShare> pick(bool Function(SettlementShare share) test) => shares.where(test).toList()..sort(meFirst);
    return SettlementSections(
      reported: pick((share) => !share.isFree && share.status == PaymentStatus.reported),
      unpaid: pick((share) => !share.isFree && share.status == PaymentStatus.unpaid),
      confirmed: pick((share) => !share.isFree && share.status == PaymentStatus.confirmed),
      free: pick((share) => share.isFree),
      collected: shares.fold(0, (acc, share) => acc + share.amount),
      confirmedAmount: shares
          .where((share) => share.status == PaymentStatus.confirmed)
          .fold(0, (acc, share) => acc + share.amount),
    );
  }
}

/// 送金リンクの入力を確かめる（Cloud Functionsの`parseLink`と同じ決まり）。正しければ整えた値、正しくなければnull
String? normalizeSettlementLink(SettlementLinkService service, SettlementLinkKind kind, String input) {
  final value = input.trim();
  if (service == SettlementLinkService.paypay && kind == SettlementLinkKind.paypayId) {
    return RegExp(r'^[A-Za-z0-9_.-]{3,40}$').hasMatch(value) ? value : null;
  }
  if (kind != SettlementLinkKind.url || value.length > 500) return null;
  final uri = Uri.tryParse(value);
  if (uri == null || uri.scheme != 'https' || uri.host.isEmpty || uri.userInfo.isNotEmpty) return null;
  if (service == SettlementLinkService.paypay) {
    final host = uri.host.toLowerCase();
    if (host != 'paypay.ne.jp' && !host.endsWith('.paypay.ne.jp')) return null;
  }
  return value;
}
