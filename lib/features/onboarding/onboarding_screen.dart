import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/wallet.dart';

enum _Step { welcome, backup, import }

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  var _step = _Step.welcome;
  String _phrase = '';
  bool _saved = false, _busy = false;
  final _import = TextEditingController();

  @override
  void dispose() {
    _import.dispose();
    super.dispose();
  }

  Future<void> _open(String phrase) async {
    setState(() => _busy = true);
    try {
      await ref.read(walletProvider.notifier).open(phrase);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: _step == _Step.welcome,
        onPopInvokedWithResult: (popped, _) {
          if (!popped) setState(() => _step = _Step.welcome);
        },
        child: Scaffold(
          body: SafeArea(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: switch (_step) {
                _Step.welcome => _welcome(),
                _Step.backup => _backup(),
                _Step.import => _importView(),
              },
            ),
          ),
        ),
      );

  Widget _welcome() => Padding(
        key: const ValueKey('welcome'),
        padding: const EdgeInsets.all(24),
        child: Column(children: [
          const Spacer(),
          Image.asset('assets/art/meet_flork.png', height: 240),
          const SizedBox(height: 28),
          Text('MYFLORK', style: Fk.display.copyWith(fontSize: 52, color: Fk.knit)),
          const SizedBox(height: 10),
          const Text('Your keys. Your Florks. The whole Florkverse.',
              textAlign: TextAlign.center, style: TextStyle(color: Fk.muted, fontSize: 16)),
          const Spacer(),
          FilledButton(
            onPressed: () => setState(() {
              _phrase = WalletNotifier.newPhrase();
              _saved = false;
              _step = _Step.backup;
            }),
            child: const Text('Create a new wallet'),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => setState(() => _step = _Step.import),
            child: const Text('I already have a wallet', style: TextStyle(color: Fk.chalk, fontWeight: FontWeight.w700)),
          ),
        ]),
      );

  Widget _backup() {
    final words = _phrase.split(' ');
    return ListView(
      key: const ValueKey('backup'),
      padding: const EdgeInsets.all(24),
      children: [
        Text('WRITE IT DOWN', style: Fk.display.copyWith(fontSize: 36)),
        const SizedBox(height: 8),
        const Text('These 12 words are the only way back into your wallet. Keep them offline, never share them.',
            style: TextStyle(color: Fk.muted)),
        const SizedBox(height: 24),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 2.6,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          children: [
            for (var i = 0; i < words.length; i++)
              Container(
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(color: Fk.card, borderRadius: BorderRadius.circular(12)),
                child: Text.rich(TextSpan(children: [
                  TextSpan(text: '${i + 1} ', style: const TextStyle(color: Fk.muted, fontSize: 12)),
                  TextSpan(text: words[i], style: const TextStyle(fontWeight: FontWeight.w700)),
                ])),
              ),
          ],
        ),
        const SizedBox(height: 20),
        CheckboxListTile(
          value: _saved,
          onChanged: (v) => setState(() => _saved = v ?? false),
          activeColor: Fk.knit,
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          title: const Text('I saved my recovery phrase'),
        ),
        const SizedBox(height: 12),
        FilledButton(onPressed: _saved && !_busy ? () => _open(_phrase) : null, child: const Text('Open my wallet')),
      ],
    );
  }

  Widget _importView() => ListView(
        key: const ValueKey('import'),
        padding: const EdgeInsets.all(24),
        children: [
          Text('IMPORT', style: Fk.display.copyWith(fontSize: 36)),
          const SizedBox(height: 8),
          const Text('Paste the 12 or 24 words of a Solana wallet (Phantom, Solflare, Backpack).',
              style: TextStyle(color: Fk.muted)),
          const SizedBox(height: 20),
          TextField(
            controller: _import,
            minLines: 4,
            maxLines: 6,
            autocorrect: false,
            enableSuggestions: false,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(hintText: 'word1 word2 word3 …'),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: WalletNotifier.validPhrase(_import.text) && !_busy ? () => _open(_import.text) : null,
            child: const Text('Import wallet'),
          ),
        ],
      );
}
