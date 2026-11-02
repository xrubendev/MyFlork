import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../app/theme.dart';
import '../../core/wallet.dart';

class ReceiveScreen extends ConsumerWidget {
  const ReceiveScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wallet = ref.watch(walletProvider).valueOrNull;
    if (wallet == null) return const Scaffold();
    return Scaffold(
      appBar: AppBar(title: const Text('Receive')),
      body: ListView(padding: const EdgeInsets.all(24), children: [
        const Text('Solana · SOL, FLORK and any SPL token', textAlign: TextAlign.center, style: TextStyle(color: Fk.muted)),
        const SizedBox(height: 20),
        Center(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(Fk.r)),
            child: QrImageView(
              data: wallet.address,
              size: 240,
              embeddedImage: const AssetImage('assets/art/logo_flork.png'),
              embeddedImageStyle: const QrEmbeddedImageStyle(size: Size(56, 56)),
              errorCorrectionLevel: QrErrorCorrectLevel.H,
            ),
          ),
        ),
        const SizedBox(height: 20),
        SelectableText(wallet.address, textAlign: TextAlign.center, style: const TextStyle(fontSize: 15, height: 1.4)),
        const SizedBox(height: 24),
        FilledButton.icon(
          icon: const Icon(Icons.copy_rounded),
          label: const Text('Copy address'),
          onPressed: () {
            Clipboard.setData(ClipboardData(text: wallet.address));
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Address copied')));
          },
        ),
      ]),
    );
  }
}
