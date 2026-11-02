import 'package:bip39/bip39.dart' as bip39;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:solana/solana.dart';

/// One self-custody wallet: the phrase stays in the platform keystore, the key pair only in memory.
class Wallet {
  Wallet(this.keyPair);
  final Ed25519HDKeyPair keyPair;
  String get address => keyPair.address;
  String get short => '${address.substring(0, 4)}…${address.substring(address.length - 4)}';
}

const _store = FlutterSecureStorage(aOptions: AndroidOptions(encryptedSharedPreferences: true));
const _phraseKey = 'myflork.phrase';

class WalletNotifier extends AsyncNotifier<Wallet?> {
  @override
  Future<Wallet?> build() async {
    final phrase = await _store.read(key: _phraseKey);
    return phrase == null ? null : _derive(phrase);
  }

  static String newPhrase() => bip39.generateMnemonic();

  static bool validPhrase(String phrase) => bip39.validateMnemonic(_clean(phrase));

  /// Saves the phrase and opens the wallet. Same derivation as Phantom and Solflare (m/44'/501'/0'/0').
  Future<void> open(String phrase) async {
    final clean = _clean(phrase);
    if (!bip39.validateMnemonic(clean)) throw ArgumentError('Invalid recovery phrase');
    await _store.write(key: _phraseKey, value: clean);
    state = AsyncData(await _derive(clean));
  }

  Future<String?> revealPhrase() => _store.read(key: _phraseKey);

  Future<void> forget() async {
    await _store.delete(key: _phraseKey);
    state = const AsyncData(null);
  }

  static Future<Wallet> _derive(String phrase) async =>
      Wallet(await Ed25519HDKeyPair.fromMnemonic(phrase, account: 0, change: 0));

  static String _clean(String phrase) => phrase.trim().toLowerCase().split(RegExp(r'\s+')).join(' ');
}

final walletProvider = AsyncNotifierProvider<WalletNotifier, Wallet?>(WalletNotifier.new);
