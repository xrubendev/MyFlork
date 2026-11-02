import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/theme.dart';
import '../../core/chain.dart';

class ActivityScreen extends ConsumerWidget {
  const ActivityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activity = ref.watch(activityProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Activity')),
      body: RefreshIndicator(
        color: Fk.knit,
        onRefresh: () => ref.refresh(activityProvider.future),
        child: activity.when(
          loading: () => const Center(child: CircularProgressIndicator(color: Fk.knit)),
          error: (e, _) => ListView(children: [Padding(padding: const EdgeInsets.all(24), child: Text('$e'))]),
          data: (items) => items.isEmpty
              ? ListView(children: [
                  const SizedBox(height: 80),
                  Image.asset('assets/art/flork_acostado.png', height: 120),
                  const SizedBox(height: 16),
                  const Center(child: Text('No transactions yet', style: TextStyle(color: Fk.muted))),
                ])
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final a = items[i];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                      leading: CircleAvatar(
                        backgroundColor: a.ok ? Fk.knitSoft : Fk.down.withValues(alpha: 0.15),
                        child:
                            Icon(a.ok ? Icons.swap_horiz_rounded : Icons.error_outline_rounded, color: a.ok ? Fk.knit : Fk.down),
                      ),
                      title: Text('${a.signature.substring(0, 6)}…${a.signature.substring(a.signature.length - 6)}',
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(a.time == null ? 'Pending' : _ago(a.time!), style: const TextStyle(color: Fk.muted)),
                      trailing: const Icon(Icons.open_in_new_rounded, size: 18, color: Fk.muted),
                      onTap: () =>
                          launchUrl(Uri.parse('https://solscan.io/tx/${a.signature}'), mode: LaunchMode.externalApplication),
                    );
                  },
                ),
        ),
      ),
    );
  }

  static String _ago(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'just now';
    if (d.inHours < 1) return '${d.inMinutes}m ago';
    if (d.inDays < 1) return '${d.inHours}h ago';
    return '${d.inDays}d ago';
  }
}
