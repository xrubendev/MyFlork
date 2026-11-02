import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/lock.dart';
import '../../core/wallet.dart';
import '../../widgets/common.dart';
import '../lock/lock_screens.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lock = ref.watch(lockProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(4, 0, 4, 8),
          child: Text('Security', style: TextStyle(color: Fk.muted, fontWeight: FontWeight.w600)),
        ),
        FkCard(
          padding: EdgeInsets.zero,
          child: Column(children: [
            if (lock.bio != Bio.none) ...[
              SwitchListTile(
                secondary: Icon(lock.bio == Bio.face ? Icons.face_retouching_natural_rounded : Icons.fingerprint_rounded,
                    color: Fk.knit),
                title: Text('Unlock with ${bioLabel(lock.bio)}'),
                activeThumbColor: Fk.knit,
                value: lock.bioEnabled,
                onChanged: (on) async {
                  final ok = await ref.read(lockProvider.notifier).enableBiometrics(on);
                  if (!ok && context.mounted) {
                    ScaffoldMessenger.of(context)
                        .showSnackBar(SnackBar(content: Text('Could not turn on ${bioLabel(lock.bio)}')));
                  }
                },
              ),
              const Divider(height: 1),
            ],
            ListTile(
              leading: const Icon(Icons.pin_rounded, color: Fk.knit),
              title: const Text('Change PIN'),
              onTap: () async {
                if (await confirmIdentity(context, ref, 'Confirm it is you') && context.mounted) {
                  context.push('/change-pin');
                }
              },
            ),
          ]),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(4, 24, 4, 8),
          child: Text('Wallet', style: TextStyle(color: Fk.muted, fontWeight: FontWeight.w600)),
        ),
        FkCard(
          padding: EdgeInsets.zero,
          child: Column(children: [
            ListTile(
              leading: const Icon(Icons.key_rounded, color: Fk.knit),
              title: const Text('Show recovery phrase'),
              onTap: () async {
                if (!await confirmIdentity(context, ref, 'Show your recovery phrase')) return;
                final phrase = await ref.read(walletProvider.notifier).revealPhrase();
                if (!context.mounted || phrase == null) return;
                showDialog<void>(
                  context: context,
                  builder: (_) => AlertDialog(
                    backgroundColor: Fk.surface,
                    title: const Text('Recovery phrase'),
                    content: SelectableText(phrase, style: const TextStyle(fontSize: 17, height: 1.5)),
                  ),
                );
              },
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.logout_rounded, color: Fk.down),
              title: const Text('Remove wallet from this phone', style: TextStyle(color: Fk.down)),
              onTap: () async {
                final yes = await showDialog<bool>(
                  context: context,
                  builder: (c) => AlertDialog(
                    backgroundColor: Fk.surface,
                    title: const Text('Remove wallet?'),
                    content: const Text('Without your recovery phrase you will lose access to these funds.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
                      TextButton(
                        onPressed: () => Navigator.pop(c, true),
                        child: const Text('Remove', style: TextStyle(color: Fk.down)),
                      ),
                    ],
                  ),
                );
                if (yes != true || !context.mounted) return;
                if (!await confirmIdentity(context, ref, 'Remove this wallet')) return;
                await ref.read(lockProvider.notifier).forget();
                await ref.read(walletProvider.notifier).forget();
              },
            ),
          ]),
        ),
      ]),
    );
  }
}
