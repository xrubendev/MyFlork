import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../app/theme.dart';
import '../core/chain.dart';
import 'common.dart';

/// A token the user can pick: one they hold, or any token Jupiter knows.
class Tok {
  const Tok(
      {required this.mint,
      required this.symbol,
      required this.decimals,
      this.logo,
      this.balance,
      this.price,
      this.holding,
      this.verified = false,
      this.score = 0});
  final String mint, symbol;
  final int decimals;
  final String? logo;
  final double? balance, price;
  final Holding? holding;
  final bool verified;
  final double score;

  factory Tok.held(Holding h) => Tok(
      mint: h.mint,
      symbol: h.symbol,
      decimals: h.isSol ? 9 : h.decimals,
      logo: h.logo,
      balance: h.amount,
      price: h.price,
      holding: h);

  factory Tok.jup(Map<String, dynamic> t) => Tok(
        mint: t['id'] as String,
        symbol: t['symbol'] as String,
        decimals: t['decimals'] as int,
        logo: t['icon'] as String?,
        price: (t['usdPrice'] as num?)?.toDouble(),
        verified: t['isVerified'] == true,
        score: (t['organicScore'] as num?)?.toDouble() ?? 0,
      );
}

Future<List<Tok>> _search(String q) async {
  final url = q.isEmpty
      ? 'https://lite-api.jup.ag/tokens/v2/toptrending/1h?limit=30'
      : 'https://lite-api.jup.ag/tokens/v2/search?query=${Uri.encodeQueryComponent(q)}';
  final res = await http.get(Uri.parse(url));
  if (res.statusCode != 200) return [];
  final list = [for (final t in jsonDecode(res.body) as List) Tok.jup(t as Map<String, dynamic>)];
  // Verified tokens first, so copycats of a well-known symbol never sit above the real one.
  final sym = q.toUpperCase();
  int rank(Tok t) => (t.verified ? 2 : 0) + (t.verified && t.symbol.toUpperCase() == sym ? 1 : 0);
  list.sort((a, b) => rank(b) != rank(a) ? rank(b) - rank(a) : b.score.compareTo(a.score));
  return list;
}

/// Bottom sheet: your tokens first, then trending or search results (by name, symbol or address).
Future<Tok?> pickToken(BuildContext context, {required bool heldOnly, String? exclude}) => showModalBottomSheet<Tok>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Fk.surface,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => FractionallySizedBox(heightFactor: 0.88, child: _Picker(heldOnly: heldOnly, exclude: exclude)),
    );

class _Picker extends ConsumerStatefulWidget {
  const _Picker({required this.heldOnly, this.exclude});
  final bool heldOnly;
  final String? exclude;

  @override
  ConsumerState<_Picker> createState() => _PickerState();
}

class _PickerState extends ConsumerState<_Picker> {
  String _q = '';
  Timer? _debounce;
  Future<List<Tok>>? _results;

  @override
  void initState() {
    super.initState();
    if (!widget.heldOnly) _results = _search('');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onQuery(String v) {
    setState(() => _q = v.trim());
    if (widget.heldOnly) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () => setState(() => _results = _search(_q)));
  }

  @override
  Widget build(BuildContext context) {
    final held = (ref.watch(portfolioProvider).valueOrNull?.holdings ?? [])
        .map(Tok.held)
        .where((t) => t.mint != widget.exclude)
        .where((t) => _q.isEmpty || t.symbol.toLowerCase().contains(_q.toLowerCase()) || t.mint == _q)
        .toList();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(children: [
        TextField(
          autofocus: false,
          onChanged: _onQuery,
          decoration:
              const InputDecoration(prefixIcon: Icon(Icons.search_rounded, color: Fk.muted), hintText: 'Name, symbol or address'),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView(children: [
            if (held.isNotEmpty) const _Label('Your tokens'),
            for (final t in held) _TokRow(t),
            if (!widget.heldOnly)
              FutureBuilder(
                future: _results,
                builder: (_, snap) {
                  final list =
                      (snap.data ?? []).where((t) => t.mint != widget.exclude && !held.any((h) => h.mint == t.mint)).toList();
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Padding(
                        padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator(color: Fk.knit)));
                  }
                  return Column(children: [
                    if (list.isNotEmpty) _Label(_q.isEmpty ? 'Trending' : 'Results'),
                    for (final t in list) _TokRow(t),
                  ]);
                },
              ),
          ]),
        ),
      ]),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 16, 4, 4),
        child: Text(text, style: const TextStyle(color: Fk.muted, fontWeight: FontWeight.w600)),
      );
}

class _TokRow extends StatelessWidget {
  const _TokRow(this.t);
  final Tok t;

  @override
  Widget build(BuildContext context) => ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 4),
        leading: TokenLogo(symbol: t.symbol, url: t.logo),
        title: Row(children: [
          Flexible(child: Text(t.symbol, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700))),
          const SizedBox(width: 6),
          if (t.verified)
            const Icon(Icons.verified_rounded, size: 16, color: Fk.knit)
          else if (t.holding == null)
            const Text('Unverified', style: TextStyle(color: Fk.down, fontSize: 12, fontWeight: FontWeight.w700)),
        ]),
        subtitle:
            Text('${t.mint.substring(0, 4)}…${t.mint.substring(t.mint.length - 4)}', style: const TextStyle(color: Fk.muted)),
        trailing: t.balance == null
            ? null
            : Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(amount(t.balance!), style: const TextStyle(fontWeight: FontWeight.w700)),
                if (t.price != null) Text(usd(t.price! * t.balance!), style: const TextStyle(color: Fk.muted)),
              ]),
        onTap: () => Navigator.pop(context, t),
      );
}

/// Pill button showing the chosen token, opens the picker.
class TokenButton extends StatelessWidget {
  const TokenButton({super.key, required this.token, required this.onTap});
  final Tok? token;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: Fk.cardHi,
        shape: const StadiumBorder(),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (token != null) TokenLogo(symbol: token!.symbol, url: token!.logo, size: 28) else const SizedBox(width: 4),
              const SizedBox(width: 8),
              Text(token?.symbol ?? 'Select', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              const Icon(Icons.keyboard_arrow_down_rounded),
            ]),
          ),
        ),
      );
}
