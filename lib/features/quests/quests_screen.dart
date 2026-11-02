import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/family_api.dart';
import '../../widgets/common.dart';
import '../florkverse/apps.dart';

/// Earn Flork: the quests from flork.family; each one opens where it's done.
class QuestsScreen extends ConsumerWidget {
  const QuestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final board = ref.watch(pointsProvider);
    return Scaffold(
      body: RefreshIndicator(
        color: Fk.knit,
        onRefresh: () => ref.refresh(pointsProvider.future),
        child: CustomScrollView(slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 240,
            backgroundColor: Fk.bg,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient:
                      LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF3A1730), Fk.bg]),
                ),
                child: Stack(children: [
                  Positioned(right: 8, bottom: 0, child: Image.asset('assets/art/meet_flork.png', height: 150)),
                  Positioned(
                    left: 20,
                    bottom: 24,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('QUESTS', style: Fk.display.copyWith(fontSize: 44, color: Fk.knit)),
                      const SizedBox(height: 4),
                      board.when(
                        data: (b) => Text(
                          '${b.total} Flork${b.rank == null ? '' : ' · #${b.rank} of ${b.people}'}',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                        loading: () => const SizedBox(height: 20),
                        error: (_, __) => const SizedBox(height: 20),
                      ),
                    ]),
                  ),
                ]),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            sliver: board.when(
              loading: () => const SliverToBoxAdapter(
                  child: Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator(color: Fk.knit)))),
              error: (e, _) => SliverToBoxAdapter(child: Text('$e', style: const TextStyle(color: Fk.muted))),
              data: (b) => SliverList.separated(
                itemCount: b.quests.length + 1,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) => i == 0 ? const _WheelBanner() : _QuestCard(q: b.quests[i - 1]),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

class _QuestCard extends StatelessWidget {
  const _QuestCard({required this.q});
  final Quest q;

  @override
  Widget build(BuildContext context) {
    final progress = q.need == 0 ? 0.0 : (q.have / q.need).clamp(0.0, 1.0).toDouble();
    return FkCard(
      onTap: q.done
          ? null
          : () => context.push('/browse',
              extra: FlorkApp(
                name: 'Flork Family',
                tagline: q.title,
                about: q.title,
                url: '$familyBase${q.href}',
                category: 'Earn',
                art: 'assets/art/meet_flork.png',
              )),
      padding: const EdgeInsets.all(16),
      child: Row(children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(color: q.done ? Fk.up.withValues(alpha: 0.15) : Fk.knitSoft, shape: BoxShape.circle),
          child: Icon(q.done ? Icons.check_rounded : Icons.bolt_rounded, color: q.done ? Fk.up : Fk.knit),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(q.title, style: TextStyle(fontWeight: FontWeight.w700, color: q.done ? Fk.muted : Fk.chalk)),
            if (q.need > 1) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(value: progress, minHeight: 6, color: Fk.knit, backgroundColor: Fk.cardHi),
              ),
              const SizedBox(height: 4),
              Text('${q.have.toStringAsFixed(q.have % 1 == 0 ? 0 : 1)} / ${q.need}',
                  style: const TextStyle(color: Fk.muted, fontSize: 12)),
            ],
          ]),
        ),
        const SizedBox(width: 10),
        Text('+${q.points} Flork${q.repeat ? ' each' : ''}',
            style: TextStyle(fontWeight: FontWeight.w800, color: q.done ? Fk.muted : Fk.gold)),
      ]),
    );
  }
}

class _WheelBanner extends ConsumerWidget {
  const _WheelBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tickets = ref.watch(wheelProvider).valueOrNull?.tickets;
    return FkCard(
      color: Fk.knitSoft,
      onTap: () => context.push('/wheel'),
      padding: const EdgeInsets.all(18),
      child: Row(children: [
        const Icon(Icons.casino_rounded, color: Fk.knit, size: 40),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('FLORK WHEEL', style: Fk.display.copyWith(fontSize: 24)),
            Text(tickets == null ? 'Every quest gives you a spin' : '$tickets spin${tickets == 1 ? '' : 's'} ready',
                style: const TextStyle(color: Fk.muted)),
          ]),
        ),
        const Icon(Icons.chevron_right_rounded, color: Fk.knit),
      ]),
    );
  }
}
