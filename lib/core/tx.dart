import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:solana/encoder.dart';
import 'package:solana/solana.dart' hide Wallet;

import 'chain.dart';
import 'config.dart';
import 'wallet.dart';

const _ataProgram = 'ATokenGPvbdGVxr1b2hvZbsiqW5xWH25efTNsLJA8knL';
const _systemProgram = '11111111111111111111111111111111';

/// Decimal string to base units without going through floating point.
BigInt toRaw(String amount, int decimals) {
  final parts = amount.trim().replaceAll(',', '.').split('.');
  final whole = parts[0].isEmpty ? '0' : parts[0];
  var frac = parts.length > 1 ? parts[1] : '';
  frac = frac.length > decimals ? frac.substring(0, decimals) : frac.padRight(decimals, '0');
  return BigInt.parse('$whole$frac');
}

double fromRaw(String raw, int decimals) => BigInt.parse(raw) / BigInt.from(10).pow(decimals);

List<int> _u64(BigInt v) => [for (var i = 0; i < 8; i++) ((v >> (8 * i)) & BigInt.from(0xff)).toInt()];

Future<Ed25519HDPublicKey> _ata(String owner, String mint, String program) => Ed25519HDPublicKey.findProgramAddress(
      seeds: [
        Ed25519HDPublicKey.fromBase58(owner).bytes,
        Ed25519HDPublicKey.fromBase58(program).bytes,
        Ed25519HDPublicKey.fromBase58(mint).bytes,
      ],
      programId: Ed25519HDPublicKey.fromBase58(_ataProgram),
    );

/// Sends SOL or any SPL / Token-2022 token, creating the recipient's token account when missing.
Future<String> sendToken(Wallet wallet, Holding token, String to, String amount) async {
  if (token.isSol) return sendSol(wallet, to, double.parse(amount.replaceAll(',', '.')));

  final program = token.program!;
  final owner = wallet.keyPair.publicKey;
  final mint = Ed25519HDPublicKey.fromBase58(token.mint);
  final from = await _ata(wallet.address, token.mint, program);
  final dest = await _ata(to.trim(), token.mint, program);
  final pk = Ed25519HDPublicKey.fromBase58;

  final createDest = Instruction(
    programId: pk(_ataProgram),
    accounts: [
      AccountMeta.writeable(pubKey: owner, isSigner: true),
      AccountMeta.writeable(pubKey: dest, isSigner: false),
      AccountMeta.readonly(pubKey: pk(to.trim()), isSigner: false),
      AccountMeta.readonly(pubKey: mint, isSigner: false),
      AccountMeta.readonly(pubKey: pk(_systemProgram), isSigner: false),
      AccountMeta.readonly(pubKey: pk(program), isSigner: false),
    ],
    data: ByteArray([1]), // CreateIdempotent
  );
  final transfer = Instruction(
    programId: pk(program),
    accounts: [
      AccountMeta.writeable(pubKey: from, isSigner: false),
      AccountMeta.readonly(pubKey: mint, isSigner: false),
      AccountMeta.writeable(pubKey: dest, isSigner: false),
      AccountMeta.readonly(pubKey: owner, isSigner: true),
    ],
    data: ByteArray([12, ..._u64(toRaw(amount, token.decimals)), token.decimals]), // TransferChecked
  );

  final client = SolanaClient(rpcUrl: Uri.parse(Config.solanaRpc), websocketUrl: Uri.parse(Config.solanaWs));
  return client.sendAndConfirmTransaction(
    message: Message(instructions: [createDest, transfer]),
    signers: [wallet.keyPair],
    commitment: Commitment.confirmed,
  );
}

class SwapQuote {
  const SwapQuote(this.raw, {required this.outAmount, required this.minOut, required this.priceImpact, required this.route});
  final Map<String, dynamic> raw;
  final String outAmount;
  final String minOut;
  final double priceImpact;
  final List<String> route;
}

const _jup = 'https://lite-api.jup.ag/swap/v1';

/// Best route from Jupiter for [rawAmount] base units of [inputMint].
Future<SwapQuote> quote(String inputMint, String outputMint, BigInt rawAmount, {int slippageBps = 100}) async {
  final res = await http.get(Uri.parse('$_jup/quote?inputMint=$inputMint&outputMint=$outputMint'
      '&amount=$rawAmount&slippageBps=$slippageBps&restrictIntermediateTokens=true'));
  final body = jsonDecode(res.body) as Map<String, dynamic>;
  if (res.statusCode != 200) throw Exception(body['error'] ?? 'No route');
  return SwapQuote(
    body,
    outAmount: body['outAmount'] as String,
    minOut: body['otherAmountThreshold'] as String,
    priceImpact: double.tryParse('${body['priceImpactPct']}') ?? 0,
    route: [for (final r in body['routePlan'] as List) r['swapInfo']['label'] as String],
  );
}

/// Builds the swap with Jupiter, signs it here and sends it. Returns the signature once confirmed.
Future<String> swap(Wallet wallet, SwapQuote q) async {
  final res = await http.post(
    Uri.parse('$_jup/swap'),
    headers: {'content-type': 'application/json'},
    body: jsonEncode({
      'quoteResponse': q.raw,
      'userPublicKey': wallet.address,
      'dynamicComputeUnitLimit': true,
      'dynamicSlippage': true,
      'prioritizationFeeLamports': {
        'priorityLevelWithMaxLamports': {'maxLamports': 1000000, 'priorityLevel': 'high'},
      },
    }),
  );
  final body = jsonDecode(res.body) as Map<String, dynamic>;
  final unsigned = body['swapTransaction'] as String?;
  if (unsigned == null) throw Exception(body['error'] ?? 'Swap failed');

  // Wire format: shortvec(signature count), signatures (64 bytes each), message. We are the fee payer: slot 0.
  final tx = base64Decode(unsigned);
  var count = 0, shift = 0, off = 0;
  while (true) {
    final b = tx[off++];
    count |= (b & 0x7f) << shift;
    if (b & 0x80 == 0) break;
    shift += 7;
  }
  final message = tx.sublist(off + 64 * count);
  final sig = await wallet.keyPair.sign(message);
  tx.setRange(off, off + 64, sig.bytes);

  final signature = await rpc('sendTransaction', [
    base64Encode(tx),
    {'encoding': 'base64', 'maxRetries': 3, 'preflightCommitment': 'confirmed'},
  ]) as String;
  await confirm(signature);
  return signature;
}

/// Polls until the transaction is confirmed or fails; gives up after about 45 seconds.
Future<void> confirm(String signature) async {
  for (var i = 0; i < 30; i++) {
    final res = await rpc('getSignatureStatuses', [
      [signature]
    ]);
    final st = (res['value'] as List).first;
    if (st != null) {
      if (st['err'] != null) throw Exception('Transaction failed on-chain');
      if (st['confirmationStatus'] == 'confirmed' || st['confirmationStatus'] == 'finalized') return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 1500));
  }
  throw Exception('Not confirmed yet, check Activity');
}
