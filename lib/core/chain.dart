import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:solana/solana.dart' hide Wallet;

import 'config.dart';
import 'wallet.dart';

/// Plain JSON-RPC: one call per need, so any relay that speaks Solana RPC works.
Future<dynamic> rpc(String method, List<dynamic> params) async {
  final res = await http.post(
    Uri.parse(Config.solanaRpc),
    headers: {'content-type': 'application/json'},
    body: jsonEncode({'jsonrpc': '2.0', 'id': 1, 'method': method, 'params': params}),
  );
  final body = jsonDecode(res.body) as Map<String, dynamic>;
  if (body['error'] != null) throw Exception(body['error']['message'] ?? 'RPC error');
  return body['result'];
}

class Holding {
  const Holding({
    required this.mint,
    required this.symbol,
    required this.amount,
    this.usd,
    this.logo,
    this.decimals = 9,
    this.program,
  });
  final String mint;
  final String symbol;
  final double amount;
  final double? usd;
  final String? logo;
  final int decimals;

  /// Token program that owns this mint; null for native SOL.
  final String? program;
  bool get isSol => program == null;
  double? get price => usd == null || amount == 0 ? null : usd! / amount;
}

class Portfolio {
  const Portfolio(this.holdings);
  final List<Holding> holdings;
  double get totalUsd => holdings.fold(0, (s, h) => s + (h.usd ?? 0));
}

const solMint = 'So11111111111111111111111111111111111111112';
const _tokenPrograms = ['TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA', 'TokenzQdBNbLqP5VEhdkAS6EPFLC1PHnBqCXEpPxuEb'];

/// SOL plus every SPL token with a balance, priced through Jupiter's public price API.
final portfolioProvider = FutureProvider<Portfolio>((ref) async {
  final wallet = await ref.watch(walletProvider.future);
  if (wallet == null) return const Portfolio([]);
  final owner = wallet.address;

  final lamports = (await rpc('getBalance', [owner]))['value'] as int;
  final amounts = <String, double>{solMint: lamports / lamportsPerSol};
  final decimals = <String, int>{};
  final programs = <String, String>{};
  for (final program in _tokenPrograms) {
    final res = await rpc('getTokenAccountsByOwner', [
      owner,
      {'programId': program},
      {'encoding': 'jsonParsed'},
    ]);
    for (final acc in res['value'] as List) {
      final info = acc['account']['data']['parsed']['info'];
      final ui = (info['tokenAmount']['uiAmount'] as num?)?.toDouble() ?? 0;
      final mint = info['mint'] as String;
      if (ui <= 0) continue;
      amounts[mint] = (amounts[mint] ?? 0) + ui;
      decimals[mint] = info['tokenAmount']['decimals'] as int;
      programs[mint] = program;
    }
  }

  final meta = await _tokenMeta(amounts.keys.toList());
  final holdings = [
    for (final e in amounts.entries)
      Holding(
        mint: e.key,
        symbol: meta[e.key]?.symbol ?? (e.key == solMint ? 'SOL' : '${e.key.substring(0, 4)}…'),
        amount: e.value,
        usd: meta[e.key]?.price == null ? null : meta[e.key]!.price! * e.value,
        logo: meta[e.key]?.logo,
        decimals: decimals[e.key] ?? 9,
        program: programs[e.key],
      ),
  ]..sort((a, b) => (b.usd ?? 0).compareTo(a.usd ?? 0));
  return Portfolio(holdings);
});

class TokenMeta {
  const TokenMeta({required this.symbol, this.price, this.logo, this.change24h});
  final String symbol;
  final double? price;
  final String? logo;
  final double? change24h;
}

/// Symbol, logo, USD price and 24h change from Jupiter's token search (lite tier, no key).
Future<Map<String, TokenMeta>> _tokenMeta(List<String> mints) async {
  if (mints.isEmpty) return {};
  final res = await http.get(Uri.parse('https://lite-api.jup.ag/tokens/v2/search?query=${mints.join(',')}'));
  if (res.statusCode != 200) return {};
  return {
    for (final t in jsonDecode(res.body) as List)
      t['id'] as String: TokenMeta(
        symbol: t['symbol'] as String,
        price: (t['usdPrice'] as num?)?.toDouble(),
        logo: t['icon'] as String?,
        change24h: (t['stats24h']?['priceChange'] as num?)?.toDouble(),
      ),
  };
}

final tokenMetaProvider = FutureProvider.family<TokenMeta?, String>((ref, mint) async => (await _tokenMeta([mint]))[mint]);

class Activity {
  const Activity({required this.signature, required this.time, required this.ok});
  final String signature;
  final DateTime? time;
  final bool ok;
}

final activityProvider = FutureProvider<List<Activity>>((ref) async {
  final wallet = await ref.watch(walletProvider.future);
  if (wallet == null) return [];
  final res = await rpc('getSignaturesForAddress', [
    wallet.address,
    {'limit': 30}
  ]) as List;
  return [
    for (final s in res)
      Activity(
        signature: s['signature'] as String,
        time: s['blockTime'] == null ? null : DateTime.fromMillisecondsSinceEpoch((s['blockTime'] as int) * 1000),
        ok: s['err'] == null,
      ),
  ];
});

/// Sends SOL and waits for confirmation. Returns the signature.
Future<String> sendSol(Wallet wallet, String to, double amount) async {
  final client = SolanaClient(rpcUrl: Uri.parse(Config.solanaRpc), websocketUrl: Uri.parse(Config.solanaWs));
  final ix = SystemInstruction.transfer(
    fundingAccount: wallet.keyPair.publicKey,
    recipientAccount: Ed25519HDPublicKey.fromBase58(to),
    lamports: (amount * lamportsPerSol).round(),
  );
  return client.sendAndConfirmTransaction(
    message: Message.only(ix),
    signers: [wallet.keyPair],
    commitment: Commitment.confirmed,
  );
}

bool isSolanaAddress(String s) {
  try {
    return Ed25519HDPublicKey.fromBase58(s.trim()).bytes.length == 32;
  } catch (_) {
    return false;
  }
}
