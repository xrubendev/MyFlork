import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../app/theme.dart';
import '../../core/chain.dart';
import '../../core/config.dart';
import 'package:go_router/go_router.dart';

import '../../widgets/common.dart';
import '../../widgets/token_picker.dart';

class MarketToken {
  const MarketToken(
      {required this.mint,
      required this.symbol,
      required this.name,
      required this.decimals,
      this.logo,
      this.price,
      this.change,
      this.mcap});
  final String mint, symbol, name;
  final int decimals;
  final String? logo;
  final double? price, change, mcap;

  factory MarketToken.fromJup(Map<String, dynamic> t) => MarketToken(
        mint: t['id'] as String,
        symbol: t['symbol'] as String,
        name: t['name'] as String,
        decimals: t['decimals'] as int,
        logo: t['icon'] as String?,
        price: (t['usdPrice'] as num?)?.toDouble(),
        change: (t['stats24h']?['priceChange'] as num?)?.toDouble(),
        mcap: (t['mcap'] as num?)?.toDouble(),
      );
}

/// Trending Solana tokens over the last hour, from Jupiter's public token API.
final trendingProvider = FutureProvider<List<MarketToken>>((ref) async {
  final res = await http.get(Uri.parse('https://lite-api.jup.ag/tokens/v2/toptrending/1h?limit=30'));
  if (res.statusCode != 200) throw Exception('Market unavailable (${res.statusCode})');
  return [for (final t in jsonDecode(res.body) as List) MarketToken.fromJup(t as Map<String, dynamic>)];
});

class MarketScreen extends ConsumerWidget {
  const MarketScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trending = ref.watch(trendingProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Market')),
      body: RefreshIndicator(
        color: Fk.knit,
        onRefresh: () => ref.refresh(trendingProvider.future),
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: [
          if (Config.florkMint.isNotEmpty) _FlorkCard(mint: Config.florkMint),
          const SectionTitle('Trending'),
          ...trending.when(
            loading: () =>
                [const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator(color: Fk.knit)))],
            error: (e, _) => [Text('$e', style: const TextStyle(color: Fk.muted))],
            data: (list) => [for (var i = 0; i < list.length; i++) _Row(rank: i + 1, t: list[i])],
          ),
        ]),
      ),
    );
  }
}

class _FlorkCard extends ConsumerWidget {
  const _FlorkCard({required this.mint});
  final String mint;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final meta = ref.watch(tokenMetaProvider(mint)).valueOrNull;
    final ch = meta?.change24h;
    return FkCard(
      color: Fk.knitSoft,
      child: Row(children: [
        Image.asset('assets/art/logo_flork.png', width: 56),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('FLORK', style: Fk.display.copyWith(fontSize: 26)),
            if (meta?.price != null) Text(usd(meta!.price!), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          ]),
        ),
        if (ch != null)
          Text('${ch >= 0 ? '+' : ''}${ch.toStringAsFixed(2)}%',
              style: TextStyle(color: ch >= 0 ? Fk.up : Fk.down, fontWeight: FontWeight.w800, fontSize: 16)),
      ]),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.rank, required this.t});
  final int rank;
  final MarketToken t;

  @override
  Widget build(BuildContext context) {
    final ch = t.change;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () =>
          context.push('/swap', extra: Tok(mint: t.mint, symbol: t.symbol, decimals: t.decimals, logo: t.logo, price: t.price)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(children: [
          SizedBox(width: 26, child: Text('$rank', style: const TextStyle(color: Fk.muted))),
          TokenLogo(symbol: t.symbol, url: t.logo, size: 38),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(t.symbol, style: const TextStyle(fontWeight: FontWeight.w700)),
              if (t.mcap != null) Text('MC ${usd(t.mcap!)}', style: const TextStyle(color: Fk.muted, fontSize: 12)),
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            if (t.price != null) Text(usd(t.price!), style: const TextStyle(fontWeight: FontWeight.w600)),
            if (ch != null)
              Text('${ch >= 0 ? '+' : ''}${ch.toStringAsFixed(2)}%',
                  style: TextStyle(color: ch >= 0 ? Fk.up : Fk.down, fontSize: 12, fontWeight: FontWeight.w700)),
          ]),
        ]),
      ),
    );
  }
}
