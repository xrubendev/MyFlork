import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../widgets/common.dart';
import 'apps.dart';

class FlorkverseScreen extends StatefulWidget {
  const FlorkverseScreen({super.key});

  @override
  State<FlorkverseScreen> createState() => _FlorkverseScreenState();
}

class _FlorkverseScreenState extends State<FlorkverseScreen> {
  String _q = '';

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), children: [
            Text('FLORKVERSE', style: Fk.display.copyWith(fontSize: 40)),
            const SizedBox(height: 16),
            TextField(
              onChanged: (v) => setState(() => _q = v.trim().toLowerCase()),
              decoration: const InputDecoration(prefixIcon: Icon(Icons.search_rounded, color: Fk.muted), hintText: 'Search apps'),
            ),
            const SizedBox(height: 16),
            CatalogueGrid(query: _q),
          ]),
        ),
      );
}

/// Category tabs over a two-column grid of app cards.
class CatalogueGrid extends StatefulWidget {
  const CatalogueGrid({super.key, this.query = ''});
  final String query;

  @override
  State<CatalogueGrid> createState() => _CatalogueGridState();
}

class _CatalogueGridState extends State<CatalogueGrid> {
  String _cat = categories.first;

  @override
  Widget build(BuildContext context) {
    final apps = florkApps.where((a) {
      final inCat = _cat == 'All' || a.category == _cat;
      final hit = widget.query.isEmpty || '${a.name} ${a.tagline}'.toLowerCase().contains(widget.query);
      return inCat && hit;
    }).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SizedBox(
        height: 40,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: categories.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, i) {
            final c = categories[i];
            final on = c == _cat;
            return ChoiceChip(
              label: Text(c),
              selected: on,
              showCheckmark: false,
              onSelected: (_) => setState(() => _cat = c),
              selectedColor: Fk.chalk,
              backgroundColor: Fk.card,
              side: BorderSide.none,
              shape: const StadiumBorder(),
              labelStyle: TextStyle(color: on ? Fk.bg : Fk.chalk, fontWeight: FontWeight.w700),
            );
          },
        ),
      ),
      const SizedBox(height: 14),
      GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: apps.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 0.78),
        itemBuilder: (_, i) => _AppTile(app: apps[i]),
      ),
    ]);
  }
}

class _AppTile extends StatelessWidget {
  const _AppTile({required this.app});
  final FlorkApp app;

  @override
  Widget build(BuildContext context) => FkCard(
        padding: EdgeInsets.zero,
        onTap: () => context.push('/app', extra: app),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Container(
              width: double.infinity,
              color: Fk.cardHi,
              padding: const EdgeInsets.all(12),
              child: Image.asset(app.art, fit: BoxFit.contain),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(app.name, style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(app.tagline,
                  maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Fk.muted, fontSize: 12)),
              const SizedBox(height: 6),
              Text(app.category, style: const TextStyle(color: Fk.knit, fontSize: 12, fontWeight: FontWeight.w700)),
            ]),
          ),
        ]),
      );
}

/// Large carousel card on Home with an Open button.
class FeaturedCard extends StatelessWidget {
  const FeaturedCard({super.key, required this.app});
  final FlorkApp app;

  @override
  Widget build(BuildContext context) => FkCard(
        padding: EdgeInsets.zero,
        onTap: () => context.push('/app', extra: app),
        child: Stack(children: [
          Positioned.fill(
            child: Container(
              color: Fk.cardHi,
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 90),
              child: Hero(tag: 'art-${app.url}', child: Image.asset(app.art, fit: BoxFit.contain)),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              color: Fk.card,
              padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(app.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
                    Text(app.tagline, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Fk.muted)),
                  ]),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(minimumSize: const Size(80, 44)),
                  onPressed: () => context.push('/browse', extra: app),
                  child: const Text('Open'),
                ),
              ]),
            ),
          ),
        ]),
      );
}
