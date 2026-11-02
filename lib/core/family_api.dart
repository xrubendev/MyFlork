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
