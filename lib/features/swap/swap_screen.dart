import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/chain.dart';
import '../../core/tx.dart';
import '../../core/wallet.dart';
import '../../widgets/common.dart';
import '../../widgets/swipe_to_confirm.dart';
import '../../widgets/token_picker.dart';

/// Swap any Solana token through Jupiter's best route.
class SwapScreen extends ConsumerStatefulWidget {
  const SwapScreen({super.key, this.initialTo});
  final Tok? initialTo;

  @override
  ConsumerState<SwapScreen> createState() => _SwapScreenState();
}

class _SwapScreenState extends ConsumerState<SwapScreen> {
  final _amount = TextEditingController();
  Tok? _from, _to;
  SwapQuote? _quote;
  String? _error;
  bool _quoting = false;
  Timer? _debounce;
  int _seq = 0;

  static const _solReserve = 0.003;

  @override
  void initState() {
    super.initState();
    _to = widget.initialTo;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _amount.dispose();
    super.dispose();
  }

  Tok? _defaultFrom() {
    final sol = ref.read(portfolioProvider).valueOrNull?.holdings.where((h) => h.isSol).firstOrNull;
    return sol == null ? null : Tok.held(sol);
  }

  void _requote() {
    _debounce?.cancel();
    final from = _from ?? _defaultFrom(), to = _to;
    final text = _amount.text.trim();
    setState(() {
      _quote = null;
      _error = null;
      _quoting = from != null && to != null && (double.tryParse(text.replaceAll(',', '.')) ?? 0) > 0;
    });
    if (!_quoting) return;
    final seq = ++_seq;
    _debounce = Timer(const Duration(milliseconds: 450), () async {
      try {
        final q = await quote(from!.mint, to!.mint, toRaw(text, from.decimals));
        if (mounted && seq == _seq)
          setState(() {
            _quote = q;
            _quoting = false;
          });
      } catch (e) {
        if (mounted && seq == _seq)
          setState(() {
            _error = '$e'.replaceFirst('Exception: ', '');
            _quoting = false;
          });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(portfolioProvider);
    final from = _from ?? _defaultFrom();
    final to = _to;
    final value = double.tryParse(_amount.text.replaceAll(',', '.')) ?? 0;
    final max = from == null
        ? 0.0
        : (from.holding?.isSol ?? false ? (from.balance! - _solReserve).clamp(0.0, double.infinity) : from.balance ?? 0);
    final enough = value <= max;
    final out = _quote == null || to == null ? null : fromRaw(_quote!.outAmount, to.decimals);
    final minOut = _quote == null || to == null ? null : fromRaw(_quote!.minOut, to.decimals);

    return Scaffold(
      appBar: AppBar(title: const Text('Swap')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        _Side(
          label: 'You pay',
          token: from,
          trailing: from?.balance == null
              ? null
              : TextButton(
                  onPressed: max > 0
                      ? () {
                          _amount.text = max.toStringAsFixed(from!.decimals.clamp(0, 6));
                          _requote();
                        }
                      : null,
                  child: Text('Max ${amount(max)}', style: const TextStyle(color: Fk.knit)),
                ),
          onPick: () async {
            final t = await pickToken(context, heldOnly: true, exclude: to?.mint);
            if (t != null) {
              _from = t;
              _requote();
            }
          },
          child: TextField(
            controller: _amount,
            onChanged: (_) => _requote(),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800),
            decoration: const InputDecoration(hintText: '0', filled: false, contentPadding: EdgeInsets.zero),
          ),
          footer: from?.price != null && value > 0 ? usd(value * from!.price!) : null,
        ),
        Center(
          child: Transform.translate(
            offset: const Offset(0, -2),
            child: IconButton.filled(
              style: IconButton.styleFrom(backgroundColor: Fk.cardHi, foregroundColor: Fk.knit),
              icon: const Icon(Icons.swap_vert_rounded),
              onPressed: to?.balance == null
                  ? null
                  : () {
                      _from = to;
                      _to = from;
                      _amount.clear();
                      _requote();
                    },
            ),
          ),
        ),
        _Side(
          label: 'You receive',
          token: to,
          onPick: () async {
            final t = await pickToken(context, heldOnly: false, exclude: from?.mint);
            if (t != null) {
              _to = t;
              _requote();
            }
          },
          child: _quoting
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: LinearProgressIndicator(color: Fk.knit, backgroundColor: Fk.cardHi))
              : Text(out == null ? '0' : amount(out),
                  style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: out == null ? Fk.muted : Fk.chalk)),
          footer: to?.price != null && out != null ? usd(out * to!.price!) : null,
        ),
        if (value > 0 && !enough)
          Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text('Not enough ${from?.symbol}', style: const TextStyle(color: Fk.down))),
        if (_error != null)
          Padding(padding: const EdgeInsets.only(top: 12), child: Text(_error!, style: const TextStyle(color: Fk.down))),
        if (_quote != null && out != null && value > 0) ...[
          const SizedBox(height: 16),
          FkCard(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              _Detail('Rate', '1 ${from!.symbol} = ${amount(out / value)} ${to!.symbol}'),
              _Detail('Minimum received', '${amount(minOut!)} ${to.symbol}'),
              _Detail('Price impact', '${(_quote!.priceImpact * 100).toStringAsFixed(2)}%',
                  color: _quote!.priceImpact > 0.03 ? Fk.down : null),
              _Detail('Route', _quote!.route.toSet().join(' → ')),
            ]),
          ),
        ],
      ]),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: SwipeToConfirm(
            label: 'Swipe to swap',
            enabled: _quote != null && enough && value > 0,
            onConfirm: () async {
              final wallet = ref.read(walletProvider).valueOrNull!;
              try {
                final sig = await swap(wallet, _quote!);
                ref.invalidate(portfolioProvider);
                ref.invalidate(activityProvider);
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Swapped · ${sig.substring(0, 8)}…')));
                context.pop();
              } catch (e) {
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
              }
            },
          ),
        ),
      ),
    );
  }
}

class _Side extends StatelessWidget {
  const _Side({required this.label, required this.token, required this.onPick, required this.child, this.trailing, this.footer});
  final String label;
  final Tok? token;
  final VoidCallback onPick;
  final Widget child;
  final Widget? trailing;
  final String? footer;

  @override
  Widget build(BuildContext context) => FkCard(
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(label, style: const TextStyle(color: Fk.muted)),
            const Spacer(),
            if (trailing != null) trailing! else const SizedBox(height: 40),
          ]),
          Row(children: [
            Expanded(child: child),
            const SizedBox(width: 8),
            TokenButton(token: token, onTap: onPick),
          ]),
          if (footer != null) Text(footer!, style: const TextStyle(color: Fk.muted)),
        ]),
      );
}

class _Detail extends StatelessWidget {
  const _Detail(this.k, this.v, {this.color});
  final String k, v;
  final Color? color;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(k, style: const TextStyle(color: Fk.muted)),
          const SizedBox(width: 16),
          Expanded(child: Text(v, textAlign: TextAlign.end, style: TextStyle(fontWeight: FontWeight.w600, color: color))),
        ]),
      );
}
