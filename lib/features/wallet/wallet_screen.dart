import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/chain.dart';
import '../../core/wallet.dart';
import '../../widgets/common.dart';

class WalletScreen extends ConsumerWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wallet = ref.watch(walletProvider).valueOrNull;
    final portfolio = ref.watch(portfolioProvider);
    return Scaffold(
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.all(10),
          child: CircleAvatar(backgroundColor: Fk.chalk, child: Image.asset('assets/art/logo_flork.png')),
        ),
        title: wallet == null
            ? null
            : GestureDetector(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: wallet.address));
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Address copied')));
                },
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(wallet.short),
                  const SizedBox(width: 6),
                  const Icon(Icons.copy_rounded, size: 16, color: Fk.muted),
                ]),
              ),
        centerTitle: true,
        actions: [IconButton(icon: const Icon(Icons.settings_rounded), onPressed: () => context.push('/settings'))],
      ),
      body: RefreshIndicator(
        color: Fk.knit,
        onRefresh: () => ref.refresh(portfolioProvider.future),
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 24), children: [
          Center(
            child: Text(
              portfolio.when(data: (p) => usd(p.totalUsd), loading: () => '…', error: (_, __) => '—'),
              style: const TextStyle(fontSize: 44, fontWeight: FontWeight.w800, letterSpacing: -1),
            ),
          ),
          const SizedBox(height: 20),
          Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            _Round(icon: Icons.arrow_upward_rounded, label: 'Send', onTap: () => context.push('/send')),
            _Round(icon: Icons.arrow_downward_rounded, label: 'Receive', onTap: () => context.push('/receive')),
            _Round(icon: Icons.swap_horiz_rounded, label: 'Swap', onTap: () => context.push('/swap')),
          ]),
          const SectionTitle('Tokens'),
          ...portfolio.when(
            loading: () =>
                [const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator(color: Fk.knit)))],
            error: (e, _) => [Text('Could not load balances: $e', style: const TextStyle(color: Fk.down))],
            data: (p) => [
              for (final h in p.holdings)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: FkCard(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: Row(children: [
                      TokenLogo(symbol: h.symbol, url: h.logo),
                      const SizedBox(width: 12),
                      Expanded(child: Text(h.symbol, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16))),
                      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        Text(amount(h.amount), style: const TextStyle(fontWeight: FontWeight.w700)),
                        if (h.usd != null) Text(usd(h.usd!), style: const TextStyle(color: Fk.muted)),
                      ]),
                    ]),
                  ),
                ),
            ],
          ),
        ]),
      ),
    );
  }
}

class _Round extends StatelessWidget {
  const _Round({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Column(children: [
          Container(
            width: 60,
            height: 60,
            decoration: const BoxDecoration(color: Fk.card, shape: BoxShape.circle),
            child: Icon(icon, color: Fk.knit),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        ]),
      );
}
