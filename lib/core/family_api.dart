import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:solana/base58.dart';

import 'wallet.dart';

/// flork.family's API: the Earn quests, the Flork each wallet has stacked, and the Flork wheel.
const familyBase = 'https://flork.family';

class Quest {
  const Quest(
      {required this.id,
      required this.title,
      required this.points,
      required this.repeat,
      required this.have,
      required this.need,
      required this.earned,
      required this.href});
  final String id, title;
  final int points, earned;
  final bool repeat;
  final num have, need;

  /// Where the quest is done on flork.family.
  final String href;
  bool get done => !repeat && have >= need;

  factory Quest.fromJson(Map<String, dynamic> j) {
    final a = j['action'] as Map<String, dynamic>;
    final href = switch (a['kind']) {
      'go' => (a['href'] as String).startsWith('/') ? a['href'] as String : '/${a['href']}',
      _ => '/earn',
    };
    return Quest(
      id: j['id'] as String,
      title: j['title'] as String,
      points: j['points'] as int,
      repeat: j['repeat'] as bool,
      have: j['have'] as num,
      need: j['need'] as num,
      earned: j['earned'] as int,
      href: href,
    );
  }
}

/// A task on a post on X opened by the flork.family team (repost, like, reply); verified on flork.family Earn.
class XTask {
  const XTask(
      {required this.id,
      required this.author,
      required this.text,
      required this.actions,
      required this.points,
      required this.spotsLeft,
      required this.done});
  final String id, author;
  final String? text;
  final List<String> actions;
  final int points, spotsLeft;
  final bool done;

  factory XTask.fromJson(Map<String, dynamic> j) => XTask(
        id: '${j['id']}',
        author: j['author'] as String,
        text: j['text'] as String?,
        actions: [for (final a in j['actions'] as List) '$a'],
        points: (j['points'] as int?) == null || j['points'] == 0 ? 50 : j['points'] as int,
        spotsLeft: ((j['spots'] as int? ?? 0) - (j['verified'] as int? ?? 0)).clamp(0, 1 << 30),
        done: (j['mine'] as Map?)?['status'] == 'paid',
      );
}

/// Open X tasks plus the ones this wallet already finished.
final xTasksProvider = FutureProvider<List<XTask>>((ref) async {
  final wallet = await ref.watch(walletProvider.future);
  final res = await http.get(Uri.parse('$familyBase/api/tasks?wallet=${wallet?.address ?? ''}'));
  if (res.statusCode != 200) return [];
  final list = (jsonDecode(res.body) as Map<String, dynamic>)['tasks'] as List;
  return [
    for (final t in list)
      if ((t as Map<String, dynamic>)['status'] == 'open' || (t['mine'] as Map?)?['status'] == 'paid') XTask.fromJson(t),
  ]..sort((a, b) => (a.done ? 1 : 0) - (b.done ? 1 : 0));
});

class PointsBoard {
  const PointsBoard({required this.quests, required this.total, required this.rank, required this.people});
  final List<Quest> quests;
  final int total;
  final int? rank;
  final int people;
}

final pointsProvider = FutureProvider<PointsBoard>((ref) async {
  final wallet = await ref.watch(walletProvider.future);
  final res = await http.get(Uri.parse('$familyBase/api/points?wallet=${wallet?.address ?? ''}'));
  if (res.statusCode != 200) throw Exception('flork.family is not answering (${res.statusCode})');
  final j = jsonDecode(res.body) as Map<String, dynamic>;
  final quests = [for (final q in j['quests'] as List) Quest.fromJson(q as Map<String, dynamic>)]
    ..sort((a, b) => (a.done ? 1 : 0) - (b.done ? 1 : 0));
  return PointsBoard(quests: quests, total: (j['total'] as int?) ?? 0, rank: j['rank'] as int?, people: j['people'] as int);
});

class WheelState {
  const WheelState({required this.tickets, required this.prizes, required this.nextDaily, required this.recent});
  final int tickets;
  final List<int> prizes;
  final DateTime nextDaily;
  final List<({int points, DateTime at})> recent;
}

final wheelProvider = FutureProvider<WheelState>((ref) async {
  final wallet = await ref.watch(walletProvider.future);
  final res = await http.get(Uri.parse('$familyBase/api/wheel?wallet=${wallet?.address ?? ''}'));
  if (res.statusCode != 200) throw Exception('The wheel is not live yet');
  final j = jsonDecode(res.body) as Map<String, dynamic>;
  return WheelState(
    tickets: j['tickets'] as int,
    prizes: [for (final p in j['prizes'] as List) p as int],
    nextDaily: DateTime.parse(j['nextDaily'] as String),
    recent: [
      for (final r in j['recent'] as List) (points: r['points'] as int, at: DateTime.parse(r['at'] as String)),
    ],
  );
});

/// The headers flork.family accepts instead of a session: the wallet signs "flork.family auth\nwallet: …\nts: …".
Future<Map<String, String>> _signedHeaders(Wallet wallet) async {
  final ts = DateTime.now().millisecondsSinceEpoch;
  final message = 'flork.family auth\nwallet: ${wallet.address}\nts: $ts';
  final sig = await wallet.keyPair.sign(utf8.encode(message));
  return {
    'x-wallet': wallet.address,
    'x-signature': base58encode(sig.bytes),
    'x-timestamp': '$ts',
    'content-type': 'application/json',
  };
}

/// Spends one ticket on the server and returns the prize index and points.
Future<({int index, int points})> spinWheel(Wallet wallet) async {
  final res = await http.post(Uri.parse('$familyBase/api/wheel/spin'), headers: await _signedHeaders(wallet));
  final j = jsonDecode(res.body) as Map<String, dynamic>;
  if (res.statusCode != 200) throw Exception(j['error'] ?? 'Spin failed');
  return (index: j['index'] as int, points: j['points'] as int);
}
