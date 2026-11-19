import 'message.dart';

/// CHA-02に表示するメッセージ履歴（古い順）と、さらに過去のメッセージが残っているか。
class MessageHistory {
  const MessageHistory({required this.messages, required this.hasMore});

  final List<Message> messages;
  final bool hasMore;
}

/// 「直近N件のライブ購読」と「スクロールで遡って追加取得した過去分」を1つの履歴に合成する。
///
/// - ライブ側：`createdAt`降順の`limit(N)`クエリの購読結果。既読・リアクション・送信取消などの
///   変更がリアルタイムに反映される。新着が届くと窓が新しい側へずれ、最も古い側のメッセージが
///   購読結果から押し出される（削除ではない）ため、押し出された分は[_older]へ退避して表示を保つ。
/// - 過去分：`startAfter`で追加取得した静的なページ。取得後の変更（相手の送信取消等）は、
///   画面を開き直すまで反映されない。
///
/// Firestore・Riverpodに依存しない純粋なクラス（テスト容易性のため）。ページ境界のカーソルは
/// 呼び出し側が任意のオブジェクト（実際にはFirestoreのDocumentSnapshot）として渡す。
class MessageHistoryAccumulator {
  MessageHistoryAccumulator({required this.pageSize});

  final int pageSize;

  /// ライブ購読の窓から外れた／追加取得した、静的な過去メッセージ。
  final _older = <String, Message>{};

  /// 最新のライブ購読結果（古い順）。
  List<Message> _live = const [];

  /// 直近の「サーバー確定の」ライブ購読結果。押し出し判定の基準に使う。キャッシュ由来の
  /// 結果は窓の中身が不完全なことがあるため、基準にしない。
  List<Message>? _serverLive;

  Object? _cursor;
  bool _hasMore = false;
  bool _boundaryFromServer = false;
  bool _paged = false;

  /// 次のページを取得する際の`startAfter`に使う、これまでに把握している最も古い側のカーソル。
  Object? get cursor => _cursor;

  bool get hasMore => _hasMore && _cursor != null;

  MessageHistory get history => MessageHistory(messages: messages, hasMore: hasMore);

  /// 表示用のメッセージ一覧（古い順）。ライブ側と重複する過去分は除く。
  List<Message> get messages {
    final liveIds = {for (final m in _live) m.id};
    final older = [
      for (final m in _older.values)
        if (!liveIds.contains(m.id)) m,
    ]..sort(_compareByTime);
    return [...older, ..._live];
  }

  /// ライブ購読の新しい結果（[live]は古い順）を反映する。[cursor]は[live]の最も古いドキュメント。
  void applyLive(List<Message> live, {required Object? cursor, required bool fromCache}) {
    final windowFull = live.length >= pageSize;

    final previous = _serverLive;
    if (windowFull && previous != null && live.isNotEmpty) {
      // 窓が満杯のとき、前回あって今回ない分のうち窓の先頭より古いものは「押し出されただけ」。
      // 窓の内側にあるのに消えている分は、送信取消による本当の削除なので退避しない。
      final liveIds = {for (final m in live) m.id};
      final windowStart = live.first.createdAt;
      for (final m in previous) {
        if (!liveIds.contains(m.id) && _isBefore(m.createdAt, windowStart)) {
          _older[m.id] = m;
        }
      }
    }
    for (final m in live) {
      _older.remove(m.id);
    }
    _live = live;
    if (!fromCache) _serverLive = live;

    // ページ境界は、まだ追加取得しておらず、サーバー確定の結果を受け取るまでの間だけ更新する。
    // 以後は窓が新しい側へずれても、最初の境界を保つ（押し出された分は_olderに退避済みで、
    // 境界より新しい分を取り直さずに済む）。
    if (!_paged && !_boundaryFromServer) {
      _cursor = cursor;
      _hasMore = windowFull;
      _boundaryFromServer = !fromCache;
    }
  }

  /// 追加取得した過去のページ（[page]は古い順）を反映する。[cursor]は[page]の最も古いドキュメント。
  void addOlder(List<Message> page, {required Object? cursor}) {
    for (final m in page) {
      _older.putIfAbsent(m.id, () => m);
    }
    _paged = true;
    if (cursor != null) _cursor = cursor;
    _hasMore = page.length >= pageSize;
  }

  /// 送信直後でサーバー時刻が未確定（`createdAt`がnull）のメッセージは、最も新しいものとして扱う。
  static bool _isBefore(DateTime? a, DateTime? b) => a != null && b != null && a.isBefore(b);

  static int _compareByTime(Message a, Message b) {
    final at = a.createdAt;
    final bt = b.createdAt;
    if (at == null && bt == null) return a.id.compareTo(b.id);
    if (at == null) return 1;
    if (bt == null) return -1;
    final byTime = at.compareTo(bt);
    return byTime != 0 ? byTime : a.id.compareTo(b.id);
  }
}
