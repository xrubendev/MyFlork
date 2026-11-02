import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

const _store = FlutterSecureStorage(aOptions: AndroidOptions(encryptedSharedPreferences: true));
const _pinKey = 'myflork.pin';
const _bioKey = 'myflork.biometrics';
const _failKey = 'myflork.pin.fails';
const _untilKey = 'myflork.pin.until';

/// Which biometric the phone offers, for labels and icons.
enum Bio { none, face, fingerprint }

class LockState {
  const LockState({required this.ready, required this.hasPin, required this.locked, required this.bioEnabled, required this.bio});
  final bool ready, hasPin, locked, bioEnabled;
  final Bio bio;

  LockState copyWith({bool? hasPin, bool? locked, bool? bioEnabled}) => LockState(
        ready: ready,
        hasPin: hasPin ?? this.hasPin,
        locked: locked ?? this.locked,
        bioEnabled: bioEnabled ?? this.bioEnabled,
        bio: bio,
      );
}

/// App lock: a 6-digit PIN that always works, plus fingerprint or face when the phone has it.
class LockNotifier extends Notifier<LockState> {
  final _auth = LocalAuthentication();

  @override
  LockState build() {
    _load();
    return const LockState(ready: false, hasPin: false, locked: true, bioEnabled: false, bio: Bio.none);
  }

  Future<void> _load() async {
    final hasPin = await _store.read(key: _pinKey) != null;
    final bioEnabled = await _store.read(key: _bioKey) == '1';
    state = LockState(ready: true, hasPin: hasPin, locked: hasPin, bioEnabled: bioEnabled, bio: await _bioKind());
  }

  Future<Bio> _bioKind() async {
    try {
      if (!await _auth.isDeviceSupported() || !await _auth.canCheckBiometrics) return Bio.none;
      final kinds = await _auth.getAvailableBiometrics();
      if (kinds.contains(BiometricType.face)) return Bio.face;
      if (kinds.contains(BiometricType.fingerprint) || kinds.contains(BiometricType.strong)) return Bio.fingerprint;
      return Bio.none;
    } on PlatformException {
      return Bio.none;
    }
  }

  static String _hash(String pin, String salt) {
    // Iterated HMAC so a stolen hash can't be brute-forced in a blink.
    List<int> h = utf8.encode(pin);
    final key = base64Decode(salt);
    for (var i = 0; i < 20000; i++) {
      h = Hmac(sha256, key).convert(h).bytes;
    }
    return base64Encode(h);
  }

  Future<void> setPin(String pin) async {
    final salt = base64Encode(List<int>.generate(16, (_) => Random.secure().nextInt(256)));
    await _store.write(key: _pinKey, value: '$salt:${_hash(pin, salt)}');
    await _store.delete(key: _failKey);
    await _store.delete(key: _untilKey);
    state = state.copyWith(hasPin: true, locked: false);
  }

  /// Seconds the user still has to wait after too many wrong PINs.
  Future<int> waitSeconds() async {
    final until = int.tryParse(await _store.read(key: _untilKey) ?? '') ?? 0;
    return max(0, ((until - DateTime.now().millisecondsSinceEpoch) / 1000).ceil());
  }

  /// Checks the PIN; after 5 misses each further miss doubles a wait that starts at 30 seconds.
  Future<bool> checkPin(String pin) async {
    if (await waitSeconds() > 0) return false;
    final saved = await _store.read(key: _pinKey);
    if (saved == null) return false;
    final [salt, hash] = saved.split(':');
    if (_hash(pin, salt) == hash) {
      await _store.delete(key: _failKey);
      await _store.delete(key: _untilKey);
      return true;
    }
    final fails = (int.tryParse(await _store.read(key: _failKey) ?? '') ?? 0) + 1;
    await _store.write(key: _failKey, value: '$fails');
    if (fails >= 5) {
      final wait = 30 * pow(2, fails - 5).toInt();
      await _store.write(key: _untilKey, value: '${DateTime.now().millisecondsSinceEpoch + wait * 1000}');
    }
    return false;
  }

  Future<bool> biometric(String reason) async {
    if (!state.bioEnabled || state.bio == Bio.none) return false;
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(biometricOnly: true, stickyAuth: true),
      );
    } on PlatformException {
      return false;
    }
  }

  Future<bool> enableBiometrics(bool on) async {
    if (on) {
      // Ask once now, so the user knows it works before relying on it.
      try {
        final ok = await _auth.authenticate(
          localizedReason: 'Turn on ${bioLabel(state.bio)} for MyFlork',
          options: const AuthenticationOptions(biometricOnly: true, stickyAuth: true),
        );
        if (!ok) return false;
      } on PlatformException {
        return false;
      }
    }
    await _store.write(key: _bioKey, value: on ? '1' : '0');
    state = state.copyWith(bioEnabled: on);
    return true;
  }

  void unlock() => state = state.copyWith(locked: false);

  void lock() {
    if (state.hasPin) state = state.copyWith(locked: true);
  }

  Future<void> forget() async {
    for (final k in [_pinKey, _bioKey, _failKey, _untilKey]) {
      await _store.delete(key: k);
    }
    state = state.copyWith(hasPin: false, locked: false, bioEnabled: false);
  }
}

final lockProvider = NotifierProvider<LockNotifier, LockState>(LockNotifier.new);

String bioLabel(Bio b) => switch (b) {
      Bio.face => 'face unlock',
      Bio.fingerprint => 'fingerprint',
      Bio.none => 'biometrics',
    };
