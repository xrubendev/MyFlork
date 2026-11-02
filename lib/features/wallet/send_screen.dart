import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/chain.dart';
import '../../core/tx.dart';
import '../../core/wallet.dart';
import '../../widgets/common.dart';
import '../../widgets/swipe_to_confirm.dart';
import '../../widgets/token_picker.dart';

/// Sends SOL or any token in the wallet.
class SendScreen extends ConsumerStatefulWidget {
  const SendScreen({super.key});

  @override
  ConsumerState<SendScreen> createState() => _SendScreenState();
}

class _SendScreenState extends ConsumerState<SendScreen> {
  final _to = TextEditingController();
  final _amount = TextEditingController();
  Tok? _token;

  // SOL kept back for the network fee and, for tokens, a new account for the recipient.
  static const _solReserve = 0.003;

  @override
  void dispose() {
    _to.dispose();
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final holdings = ref.watch(portfolioProvider).valueOrNull?.holdings ?? [];
    final sol = holdings.where((h) => h.isSol).firstOrNull;
    final token = _token ?? (sol == null ? null : Tok.held(sol));
    final balance = token?.balance ?? 0;
    final solBalance = sol?.amount ?? 0;
    final max = token?.holding?.isSol ?? true ? (balance - _solReserve).clamp(0.0, double.infinity) : balance;

    final value = double.tryParse(_amount.text.replaceAll(',', '.')) ?? 0;
    final validTo = isSolanaAddress(_to.text);
    final enoughToken = value <= max;
    final enoughFee = solBalance >= (token?.holding?.isSol ?? true ? value + _solReserve : _solReserve);
    final ok = token != null && validTo && value > 0 && enoughToken && enoughFee;

    return Scaffold(
      appBar: AppBar(title: const Text('Send')),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        Row(children: [
          TokenButton(
            token: token,
            onTap: () async {
              final t = await pickToken(context, heldOnly: true);
              if (t != null) setState(() => _token = t);
            },
          ),
          const Spacer(),
          TextButton(
            onPressed: max > 0 ? () => setState(() => _amount.text = max.toStringAsFixed(token!.decimals.clamp(0, 6))) : null,
            child: Text('Max ${amount(max)}', style: const TextStyle(color: Fk.knit)),
          ),
        ]),
        const SizedBox(height: 12),
        TextField(
          controller: _amount,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: (_) => setState(() {}),
          style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800),
          decoration: InputDecoration(hintText: '0.0', suffixText: token?.symbol),
        ),
        if (token?.price != null && value > 0)
          Padding(
              padding: const EdgeInsets.only(top: 8, left: 4),
              child: Text('≈ ${usd(value * token!.price!)}', style: const TextStyle(color: Fk.muted))),
        if (value > 0 && !enoughToken)
          Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('Not enough ${token?.symbol}', style: const TextStyle(color: Fk.down))),
        if (value > 0 && enoughToken && !enoughFee)
          const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('Not enough SOL for the network fee', style: TextStyle(color: Fk.down))),
        const SizedBox(height: 24),
        const Text('To', style: TextStyle(color: Fk.muted)),
        const SizedBox(height: 8),
        TextField(
          controller: _to,
          autocorrect: false,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: 'Solana address',
            errorText: _to.text.isNotEmpty && !validTo ? 'Not a Solana address' : null,
            suffixIcon: IconButton(
              icon: const Icon(Icons.content_paste_rounded, color: Fk.muted),
              onPressed: () async {
                final clip = await Clipboard.getData('text/plain');
                if (clip?.text != null) setState(() => _to.text = clip!.text!.trim());
              },
            ),
          ),
        ),
      ]),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: SwipeToConfirm(
            label: 'Swipe to send',
            enabled: ok,
            onConfirm: () async {
              final wallet = ref.read(walletProvider).valueOrNull!;
              try {
                final sig = await sendToken(wallet, token!.holding!, _to.text.trim(), _amount.text);
                ref.invalidate(portfolioProvider);
                ref.invalidate(activityProvider);
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Sent · ${sig.substring(0, 8)}…')));
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
