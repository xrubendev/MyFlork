import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/chain.dart';
import '../florkverse/apps.dart';
import '../florkverse/florkverse_screen.dart';
import '../../widgets/common.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final portfolio = ref.watch(portfolioProvider);
    final earn = florkApps.firstWhere((a) => a.category == 'Earn');
    return Scaffold(
      body: RefreshIndicator(
        color: Fk.knit,
        onRefresh: () => ref.refresh(portfolioProvider.future),
        child: CustomScrollView(slivers: [
          SliverToBoxAdapter(child: _Hero(onTap: () => context.push('/browse', extra: earn))),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            sliver: SliverList.list(children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: FkCard(
                  color: Fk.surface,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Your balance', style: TextStyle(color: Fk.muted)),
                    const SizedBox(height: 4),
                    Text(
                      portfolio.when(data: (p) => usd(p.totalUsd), loading: () => '…', error: (_, __) => '—'),
                      style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w800, letterSpacing: -1),
                    ),
                    const SizedBox(height: 16),
                    Row(children: [
                      ActionPill(icon: Icons.arrow_upward_rounded, label: 'Send', onTap: () => context.push('/send')),
                      const SizedBox(width: 10),
                      ActionPill(icon: Icons.arrow_downward_rounded, label: 'Receive', onTap: () => context.push('/receive')),
                      const SizedBox(width: 10),
                      ActionPill(icon: Icons.swap_horiz_rounded, label: 'Swap', onTap: () => context.push('/swap')),
                    ]),
                  ]),
                ),
              ),
              _SearchField(onTap: () => context.go('/florkverse')),
              const SectionTitle('Featured'),
              SizedBox(
                height: 300,
                child: PageView(
                  controller: PageController(viewportFraction: 0.86),
                  padEnds: false,
                  children: [
                    for (final app in florkApps.where((a) => a.category != 'Earn'))
                      Padding(padding: const EdgeInsets.only(right: 12), child: FeaturedCard(app: app)),
                  ],
                ),
              ),
              const SectionTitle('Florkverse'),
              const CatalogueGrid(),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// Full-bleed campaign hero: the Earn FLORK quests.
class _Hero extends StatelessWidget {
  const _Hero({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          height: 360,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF3A1730), Fk.bg],
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Stack(children: [
              Positioned(right: -10, bottom: 8, child: Image.asset('assets/art/flork_celular.png', height: 290)),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 140, 0),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('EARN\nFLORK', style: Fk.display.copyWith(fontSize: 56, color: Fk.knit)),
                  const SizedBox(height: 10),
                  const Text('Quests, posts and trades that pay in FLORK.', style: TextStyle(fontSize: 15)),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    decoration: BoxDecoration(color: Fk.knit, borderRadius: BorderRadius.circular(Fk.rPill)),
                    child: const Text('Start quests', style: TextStyle(fontWeight: FontWeight.w800)),
                  ),
                ]),
              ),
            ]),
          ),
        ),
      );
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => FkCard(
        onTap: onTap,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: const Row(children: [
          Icon(Icons.search_rounded, color: Fk.muted),
          SizedBox(width: 12),
          Text('Search Florkverse apps', style: TextStyle(color: Fk.muted, fontSize: 16)),
        ]),
      );
}
