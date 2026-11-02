import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../app/theme.dart';
import '../../core/chain.dart';
import '../../core/wallet.dart';
import '../../widgets/common.dart';
import '../../widgets/swipe_to_confirm.dart';
import 'apps.dart';
import 'dapp_bridge.dart';

/// Sites the user connected during this run of the app.
final _connected = <String>{};

/// In-app browser for Florkverse apps, with MyFlork available to them as a Solana wallet.
class BrowserScreen extends ConsumerStatefulWidget {
  const BrowserScreen({super.key, required this.app});
  final FlorkApp app;

  @override
  ConsumerState<BrowserScreen> createState() => _BrowserScreenState();
}

class _BrowserScreenState extends ConsumerState<BrowserScreen> {
  late final WebViewController _web;
  double _progress = 0;
  String? _script;

  @override
  void initState() {
    super.initState();
    _web = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Fk.bg)
      ..addJavaScriptChannel('MyFlork', onMessageReceived: (m) => _handle(DappRequest.parse(m.message)))
      ..setNavigationDelegate(NavigationDelegate(
        onProgress: (p) => setState(() => _progress = p / 100),
        onPageStarted: (_) => _inject(),
        onPageFinished: (_) => _inject(),
      ))
      ..loadRequest(Uri.parse(widget.app.url));
  }

  Future<void> _inject() async {
    final wallet = ref.read(walletProvider).valueOrNull;
    if (wallet == null) return;
    if (_script == null) {
      final icon = await rootBundle.load('assets/art/icon96.png');
      _script = bridgeScript(
        address: wallet.address,
        iconDataUri: 'data:image/png;base64,${base64Encode(icon.buffer.asUint8List())}',
      );
    }
    await _web.runJavaScript(_script!).catchError((_) {});
  }

  Future<String> _host() async => Uri.tryParse(await _web.currentUrl() ?? '')?.host ?? Uri.parse(widget.app.url).host;

  void _reply(int id, String result) => _web.runJavaScript('window.__myflork.resolve($id, ${jsonEncode(result)})');
  void _fail(int id, String message) => _web.runJavaScript('window.__myflork.reject($id, ${jsonEncode(message)})');

  Future<void> _handle(DappRequest r) async {
    final wallet = ref.read(walletProvider).valueOrNull;
    if (wallet == null) return _fail(r.id, 'No wallet');
    final host = await _host();
    try {
      switch (r.method) {
        case 'connect':
          if (_connected.contains(host)) return _reply(r.id, 'ok');
          if (r.params['silent'] == true) return _fail(r.id, 'Not connected');
          final ok = await _approve(
            host: host,
            title: 'Connect MyFlork',
            body: const [
              _Line(Icons.visibility_rounded, 'See your address and balances'),
              _Line(Icons.edit_note_rounded, 'Ask you to approve transactions'),
            ],
            action: 'Swipe to connect',
          );
          if (!ok) return _fail(r.id, 'User rejected the request');
          _connected.add(host);
          return _reply(r.id, 'ok');

        case 'signMessage':
          _requireConnected(host);
          final msg = base64Decode(r.params['message'] as String);
          final text = utf8.decode(msg, allowMalformed: true);
          final ok = await _approve(host: host, title: 'Sign message', body: [_Message(text)], action: 'Swipe to sign');
          if (!ok) return _fail(r.id, 'User rejected the request');
          final sig = await wallet.keyPair.sign(msg);
          return _reply(r.id, base64Encode(sig.bytes));

        case 'signTransaction':
        case 'signAndSendTransaction':
          _requireConnected(host);
          final tx = base64Decode(r.params['tx'] as String);
          final send = r.method == 'signAndSendTransaction';
          final ok = await _approve(
            host: host,
            title: send ? 'Approve transaction' : 'Sign transaction',
            body: [_Simulation(wallet: wallet, tx: tx)],
            action: 'Swipe to approve',
          );
          if (!ok) return _fail(r.id, 'User rejected the request');
          final signed = await signSerialized(wallet, tx);
          if (!send) return _reply(r.id, base64Encode(signed));
          final sig = await sendSerialized(signed);
          ref.invalidate(portfolioProvider);
          ref.invalidate(activityProvider);
          return _reply(r.id, sig);

        default:
          _fail(r.id, 'Unsupported method ${r.method}');
      }
    } catch (e) {
      _fail(r.id, '$e'.replaceFirst('Exception: ', ''));
    }
  }

  void _requireConnected(String host) {
    if (!_connected.contains(host)) throw Exception('Connect MyFlork first');
  }

  Future<bool> _approve({required String host, required String title, required List<Widget> body, required String action}) async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isDismissible: true,
      isScrollControlled: true,
      backgroundColor: Fk.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (c) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Center(
              child: Container(
                  width: 40, height: 4, decoration: BoxDecoration(color: Fk.lineStrong, borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 20),
            Row(children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: Fk.cardHi,
                child: Text(host.isEmpty ? '?' : host[0].toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w800)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                  Text(host, style: const TextStyle(color: Fk.muted)),
                ]),
              ),
              if (!florkApps.any((a) => Uri.parse(a.url).host == host))
                const Text('Not in Florkverse', style: TextStyle(color: Fk.gold, fontSize: 12, fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: 20),
            ...body,
            const SizedBox(height: 24),
            SwipeToConfirm(label: action, onConfirm: () async => Navigator.pop(c, true)),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Reject', style: TextStyle(color: Fk.chalk, fontWeight: FontWeight.w700)),
            ),
          ]),
        ),
      ),
    );
    return ok ?? false;
  }

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: false,
        onPopInvokedWithResult: (popped, _) async {
          if (popped) return;
          if (await _web.canGoBack()) {
            await _web.goBack();
          } else if (context.mounted) {
            Navigator.of(context).pop();
          }
        },
        child: Scaffold(
          appBar: AppBar(
            leading: IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.of(context).pop()),
            title: Text(widget.app.name),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(2),
              child: _progress < 1
                  ? LinearProgressIndicator(value: _progress, minHeight: 2, color: Fk.knit, backgroundColor: Colors.transparent)
                  : const SizedBox(height: 2),
            ),
          ),
          body: WebViewWidget(controller: _web),
          bottomNavigationBar: SafeArea(
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
              IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded),
                  onPressed: () async {
                    if (await _web.canGoBack()) _web.goBack();
                  }),
              IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _web.reload),
              IconButton(
                  icon: const Icon(Icons.arrow_forward_ios_rounded),
                  onPressed: () async {
                    if (await _web.canGoForward()) _web.goForward();
                  }),
            ]),
          ),
        ),
      );
}

class _Line extends StatelessWidget {
  const _Line(this.icon, this.text);
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [
          Icon(icon, color: Fk.knit, size: 22),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 16))),
        ]),
      );
}

class _Message extends StatelessWidget {
  const _Message(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 220),
        child: FkCard(
          color: Fk.card,
          padding: const EdgeInsets.all(16),
          child: SingleChildScrollView(child: Text(text, style: const TextStyle(height: 1.4))),
        ),
      );
}

/// Simulates the transaction and shows how much SOL leaves or enters the wallet.
class _Simulation extends StatelessWidget {
  const _Simulation({required this.wallet, required this.tx});
  final Wallet wallet;
  final List<int> tx;

  @override
  Widget build(BuildContext context) => FkCard(
        padding: const EdgeInsets.all(16),
        child: FutureBuilder<double?>(
          future: simulateSolChange(wallet, Uint8List.fromList(tx)),
          builder: (_, s) {
            if (s.connectionState != ConnectionState.done) {
              return const Row(children: [
                SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Fk.knit)),
                SizedBox(width: 12),
                Text('Simulating…', style: TextStyle(color: Fk.muted)),
              ]);
            }
            if (s.hasError) {
              return Text('${s.error}'.replaceFirst('Exception: ', ''), style: const TextStyle(color: Fk.down));
            }
            final d = s.data;
            if (d == null) return const Text('Could not preview this transaction', style: TextStyle(color: Fk.gold));
            return Row(children: [
              const Expanded(child: Text('SOL balance change', style: TextStyle(color: Fk.muted))),
              Text('${d >= 0 ? '+' : ''}${amount(d)} SOL',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: d < 0 ? Fk.down : Fk.up)),
            ]);
          },
        ),
      );
}
