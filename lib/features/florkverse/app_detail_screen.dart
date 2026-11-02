import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import 'apps.dart';

class AppDetailScreen extends StatelessWidget {
  const AppDetailScreen({super.key, required this.app});
  final FlorkApp app;

  @override
  Widget build(BuildContext context) => Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(backgroundColor: Colors.transparent),
        body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(
            height: 340,
            color: Fk.cardHi,
            padding: const EdgeInsets.fromLTRB(32, 90, 32, 16),
            child: Hero(tag: 'art-${app.url}', child: Image.asset(app.art, fit: BoxFit.contain)),
          ),
          Expanded(
            child: ListView(padding: const EdgeInsets.all(24), children: [
              Row(children: [
                Expanded(child: Text(app.name, style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w800))),
                if (app.official) const Icon(Icons.verified_rounded, color: Fk.knit),
              ]),
              Text('${app.category} · ${app.tagline}', style: const TextStyle(color: Fk.muted, fontSize: 15)),
              const SizedBox(height: 24),
              const Text('About', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text(app.about, style: const TextStyle(fontSize: 16, height: 1.45)),
            ]),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
              child: Column(children: [
                FilledButton(onPressed: () => context.push('/browse', extra: app), child: const Text('Open app')),
                const SizedBox(height: 10),
                Text(Uri.parse(app.url).host, style: const TextStyle(color: Fk.muted)),
              ]),
            ),
          ),
        ]),
      );
}
