import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/lock.dart';
import '../../widgets/pin_pad.dart';

/// Create (or change) the 6-digit PIN, then offer fingerprint or face.
class SetPinScreen extends ConsumerStatefulWidget {
  const SetPinScreen({super.key, this.changing = false});
  final bool changing;

  @override
  ConsumerState<SetPinScreen> createState() => _SetPinScreenState();
}

class _SetPinScreenState extends ConsumerState<SetPinScreen> {
  String? _first;
  String? _error;
  final _pad = GlobalKey<PinPadState>();

  Future<bool> _onPin(String pin) async {
    if (_first == null) {
      if (RegExp(r'^(\d)\1{5}$').hasMatch(pin) || '0123456789'.contains(pin) || '9876543210'.contains(pin)) {
        setState(() => _error = 'Too easy to guess, try another');
        return false;
      }
      setState(() {
        _first = pin;
        _error = null;
      });
      return true;
    }
    if (pin != _first) {
      setState(() {
        _first = null;
        _error = "PINs didn't match, start again";
      });
      return false;
    }
    final lock = ref.read(lockProvider.notifier);
    // Ask about biometrics before saving: saving the PIN unlocks the app and the router leaves this screen.
    final bio = ref.read(lockProvider).bio;
    if (mounted && bio != Bio.none && !ref.read(lockProvider).bioEnabled) {
      final yes = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          backgroundColor: Fk.surface,
          icon:
              Icon(bio == Bio.face ? Icons.face_retouching_natural_rounded : Icons.fingerprint_rounded, color: Fk.knit, size: 48),
          title: Text('Unlock with ${bioLabel(bio)}?'),
          content: const Text('Faster than typing your PIN. Your PIN keeps working if it fails.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Not now')),
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(120, 44)),
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Turn on'),
            ),
          ],
        ),
      );
      if (yes == true) await lock.enableBiometrics(true);
    }
    await lock.setPin(pin);
    if (mounted && widget.changing) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PIN changed')));
      context.pop();
    }
    return true;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: widget.changing ? AppBar() : null,
        body: SafeArea(
          child: Column(children: [
            const Spacer(),
            Image.asset('assets/art/logo_flork.png', height: 88),
            const SizedBox(height: 16),
            Text(_first == null ? 'CREATE A PIN' : 'CONFIRM YOUR PIN', style: Fk.display.copyWith(fontSize: 30)),
            const SizedBox(height: 6),
            Text(
              _first == null ? '6 digits to unlock MyFlork' : 'Type it once more',
              style: const TextStyle(color: Fk.muted),
            ),
            const SizedBox(height: 28),
            PinPad(key: _pad, onComplete: _onPin, error: _error),
            const Spacer(),
          ]),
        ),
      );
}

/// Shown when the app opens or comes back after a while.
class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key});

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen> {
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bio());
  }

  Future<void> _bio() async {
    final lock = ref.read(lockProvider.notifier);
    if (await lock.biometric('Unlock MyFlork')) lock.unlock();
  }

  Future<bool> _onPin(String pin) async {
    final lock = ref.read(lockProvider.notifier);
    final wait = await lock.waitSeconds();
    if (wait > 0) {
      setState(() => _error = 'Too many tries. Wait ${wait}s');
      return false;
    }
    if (await lock.checkPin(pin)) {
      lock.unlock();
      return true;
    }
    final after = await lock.waitSeconds();
    setState(() => _error = after > 0 ? 'Too many tries. Wait ${after}s' : 'Wrong PIN');
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(lockProvider);
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          const Spacer(),
          Image.asset('assets/art/flork_celular.png', height: 150),
          const SizedBox(height: 16),
          Text('WELCOME BACK', style: Fk.display.copyWith(fontSize: 30)),
          const SizedBox(height: 6),
          const Text('Enter your PIN', style: TextStyle(color: Fk.muted)),
          const SizedBox(height: 24),
          PinPad(onComplete: _onPin, error: _error, bio: s.bioEnabled ? s.bio : Bio.none, onBio: _bio),
          const Spacer(),
        ]),
      ),
    );
  }
}

/// Asks for fingerprint or face, falling back to the PIN; true when the owner confirmed.
Future<bool> confirmIdentity(BuildContext context, WidgetRef ref, String reason) async {
  final lock = ref.read(lockProvider.notifier);
  if (await lock.biometric(reason)) return true;
  if (!context.mounted) return false;
  final ok = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Fk.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (c) => _PinSheet(reason: reason),
  );
  return ok ?? false;
}

class _PinSheet extends ConsumerStatefulWidget {
  const _PinSheet({required this.reason});
  final String reason;

  @override
  ConsumerState<_PinSheet> createState() => _PinSheetState();
}

class _PinSheetState extends ConsumerState<_PinSheet> {
  String? _error;

  @override
  Widget build(BuildContext context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(widget.reason, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 20),
            PinPad(
              error: _error,
              onComplete: (pin) async {
                final lock = ref.read(lockProvider.notifier);
                if (await lock.checkPin(pin)) {
                  if (context.mounted) Navigator.pop(context, true);
                  return true;
                }
                final wait = await lock.waitSeconds();
                setState(() => _error = wait > 0 ? 'Too many tries. Wait ${wait}s' : 'Wrong PIN');
                return false;
              },
            ),
          ]),
        ),
      );
}
