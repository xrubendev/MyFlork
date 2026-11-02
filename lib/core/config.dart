/// Build-time settings: `flutter run --dart-define=FLORK_MINT=... --dart-define=SOLANA_RPC=...`.
/// Keys never live in the app: point SOLANA_RPC at our relay, not at a keyed provider URL.
abstract final class Config {
  static const florkMint = String.fromEnvironment('FLORK_MINT');
  static const solanaRpc = String.fromEnvironment('SOLANA_RPC', defaultValue: 'https://api.mainnet-beta.solana.com');
  static const solanaWs = String.fromEnvironment('SOLANA_WS', defaultValue: 'wss://api.mainnet-beta.solana.com');
}
