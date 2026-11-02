import 'dart:convert';
import 'dart:typed_data';

import '../../core/chain.dart';
import '../../core/wallet.dart';

/// Registers MyFlork as a Wallet Standard wallet inside the page, so Privy and the Solana wallet
/// adapter list it like Phantom. Every call goes to Flutter through the `MyFlork` channel and waits
/// for the user's answer there.
String bridgeScript({required String address, required String iconDataUri}) => '''
(function () {
  if (window.__myflork) return;
  const b58 = '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz';
  function fromB58(s) {
    const out = [0];
    for (const c of s) {
      let carry = b58.indexOf(c);
      for (let i = 0; i < out.length; i++) { carry += out[i] * 58; out[i] = carry & 255; carry >>= 8; }
      while (carry) { out.push(carry & 255); carry >>= 8; }
    }
    for (const c of s) { if (c === '1') out.push(0); else break; }
    return new Uint8Array(out.reverse());
  }
  const toB64 = (u8) => { let s = ''; for (const x of u8) s += String.fromCharCode(x); return btoa(s); };
  const fromB64 = (s) => Uint8Array.from(atob(s), (c) => c.charCodeAt(0));

  let seq = 0;
  const pending = {};
  function call(method, params) {
    return new Promise((resolve, reject) => {
      const id = ++seq;
      pending[id] = { resolve, reject };
      MyFlork.postMessage(JSON.stringify({ id, method, params }));
    });
  }
  window.__myflork = {
    resolve(id, result) { const p = pending[id]; delete pending[id]; p && p.resolve(result); },
    reject(id, message) { const p = pending[id]; delete pending[id]; p && p.reject(new Error(message)); },
  };

  const chains = ['solana:mainnet'];
  const features = ['solana:signTransaction', 'solana:signAndSendTransaction', 'solana:signMessage'];
  const account = Object.freeze({ address: '$address', publicKey: fromB58('$address'), chains, features, label: 'MyFlork' });
  let accounts = [];
  const listeners = { change: [] };
  const emit = () => listeners.change.forEach((l) => l({ accounts }));

  const wallet = {
    version: '1.0.0',
    name: 'MyFlork',
    icon: '$iconDataUri',
    chains,
    get accounts() { return accounts; },
    features: {
      'standard:connect': { version: '1.0.0', connect: async (input) => {
        if (!accounts.length) {
          await call('connect', { silent: !!(input && input.silent) });
          accounts = [account];
          emit();
        }
        return { accounts };
      } },
      'standard:disconnect': { version: '1.0.0', disconnect: async () => { accounts = []; emit(); } },
      'standard:events': { version: '1.0.0', on: (event, listener) => {
        (listeners[event] = listeners[event] || []).push(listener);
        return () => { listeners[event] = listeners[event].filter((l) => l !== listener); };
      } },
      'solana:signTransaction': { version: '1.0.0', supportedTransactionVersions: ['legacy', 0],
        signTransaction: async (...inputs) => {
          const out = [];
          for (const i of inputs) out.push({ signedTransaction: fromB64(await call('signTransaction', { tx: toB64(i.transaction) })) });
          return out;
        } },
      'solana:signAndSendTransaction': { version: '1.0.0', supportedTransactionVersions: ['legacy', 0],
        signAndSendTransaction: async (...inputs) => {
          const out = [];
          for (const i of inputs) out.push({ signature: fromB58(await call('signAndSendTransaction', { tx: toB64(i.transaction) })) });
          return out;
        } },
      'solana:signMessage': { version: '1.0.0',
        signMessage: async (...inputs) => {
          const out = [];
          for (const i of inputs) out.push({ signedMessage: i.message, signature: fromB64(await call('signMessage', { message: toB64(i.message) })) });
          return out;
        } },
    },
  };

  const register = ({ register }) => register(wallet);
  try { window.dispatchEvent(new CustomEvent('wallet-standard:register-wallet', { detail: register })); } catch (e) {}
  try { window.addEventListener('wallet-standard:app-ready', ({ detail }) => register(detail)); } catch (e) {}
})();
''';

/// A request from the page, already decoded.
class DappRequest {
  DappRequest(this.id, this.method, this.params);
  final int id;
  final String method;
  final Map<String, dynamic> params;

  factory DappRequest.parse(String raw) {
    final m = jsonDecode(raw) as Map<String, dynamic>;
    return DappRequest(m['id'] as int, m['method'] as String, (m['params'] as Map?)?.cast<String, dynamic>() ?? {});
  }
}

/// Signs the slot that belongs to [wallet] in a serialized (legacy or v0) transaction.
Future<Uint8List> signSerialized(Wallet wallet, Uint8List tx) async {
  var off = 0;
  int shortvec() {
    var v = 0, shift = 0;
    while (true) {
      final b = tx[off++];
      v |= (b & 0x7f) << shift;
      if (b & 0x80 == 0) return v;
      shift += 7;
    }
  }

  final sigCount = shortvec();
  final sigStart = off;
  final msgStart = sigStart + 64 * sigCount;
  off = msgStart;
  if (tx[off] & 0x80 != 0) off++; // versioned prefix
  final requiredSigs = tx[off];
  off += 3;
  final keyCount = shortvec();
  final me = wallet.keyPair.publicKey.bytes;
  var slot = -1;
  for (var i = 0; i < keyCount && i < requiredSigs; i++) {
    final key = tx.sublist(off + 32 * i, off + 32 * i + 32);
    if (_eq(key, me)) slot = i;
  }
  if (slot < 0) throw Exception('This transaction does not need your signature');

  final sig = await wallet.keyPair.sign(tx.sublist(msgStart));
  final out = Uint8List.fromList(tx);
  out.setRange(sigStart + 64 * slot, sigStart + 64 * slot + 64, sig.bytes);
  return out;
}

Future<String> sendSerialized(Uint8List signed) async {
  final sig = await rpc('sendTransaction', [
    base64Encode(signed),
    {'encoding': 'base64', 'maxRetries': 3, 'preflightCommitment': 'confirmed'},
  ]) as String;
  return sig;
}

/// What the transaction does to this wallet's SOL, from a simulation. Null when the node can't tell.
Future<double?> simulateSolChange(Wallet wallet, Uint8List tx) async {
  try {
    final res = await rpc('simulateTransaction', [
      base64Encode(tx),
      {
        'encoding': 'base64',
        'sigVerify': false,
        'replaceRecentBlockhash': true,
        'accounts': {
          'encoding': 'base64',
          'addresses': [wallet.address]
        },
      },
    ]);
    final v = res['value'];
    if (v['err'] != null) throw Exception('Simulation failed: ${v['err']}');
    final after = (v['accounts'] as List).first?['lamports'] as int?;
    final before = (await rpc('getBalance', [wallet.address]))['value'] as int;
    return after == null ? null : (after - before) / 1e9;
  } on Exception {
    rethrow;
  } catch (_) {
    return null;
  }
}

bool _eq(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
