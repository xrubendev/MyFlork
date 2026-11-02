import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/theme.dart';
import '../core/lock.dart';

/// Six dots and a number pad; the bottom-left key is fingerprint or face when offered.
class PinPad extends StatefulWidget {
  const PinPad({super.key, required this.onComplete, this.bio = Bio.none, this.onBio, this.error});
  final Future<bool> Function(String pin) onComplete;
  final Bio bio;
  final VoidCallback? onBio;
  final String? error;

  @override
  State<PinPad> createState() => PinPadState();
}

class PinPadState extends State<PinPad> with SingleTickerProviderStateMixin {
  String _pin = '';
  bool _busy = false;
  late final _shake = AnimationController(vsync: this, duration: const Duration(milliseconds: 360));

  @override
  void dispose() {
    _shake.dispose();
    super.dispose();
  }

  void clear() => setState(() => _pin = '');

  Future<void> _tap(String d) async {
    if (_busy || _pin.length >= 6) return;
    HapticFeedback.selectionClick();
    setState(() => _pin += d);
    if (_pin.length < 6) return;
    _busy = true;
    final ok = await widget.onComplete(_pin);
    _busy = false;
    if (!mounted) return;
    if (!ok) {
      HapticFeedback.heavyImpact();
      await _shake.forward(from: 0);
    }
    setState(() => _pin = '');
  }

  @override
  Widget build(BuildContext context) => Column(mainAxisSize: MainAxisSize.min, children: [
        AnimatedBuilder(
          animation: _shake,
          builder: (_, child) {
            final t = _shake.value;
            return Transform.translate(offset: Offset(sin(t * pi * 6) * 12 * (1 - t), 0), child: child);
          },
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            for (var i = 0; i < 6; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                margin: const EdgeInsets.symmetric(horizontal: 9),
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i < _pin.length ? Fk.knit : Colors.transparent,
                  border: Border.all(color: i < _pin.length ? Fk.knit : Fk.lineStrong, width: 2),
                ),
              ),
          ]),
        ),
        SizedBox(
          height: 44,
          child: Center(child: Text(widget.error ?? '', style: const TextStyle(color: Fk.down, fontWeight: FontWeight.w600))),
        ),
        for (final row in const [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
        ])
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [for (final d in row) _Key(label: d, onTap: () => _tap(d))]),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          widget.onBio != null && widget.bio != Bio.none
              ? _Key(
                  icon: widget.bio == Bio.face ? Icons.face_retouching_natural_rounded : Icons.fingerprint_rounded,
                  onTap: widget.onBio!)
              : const SizedBox(width: 96, height: 80),
          _Key(label: '0', onTap: () => _tap('0')),
          _Key(
            icon: Icons.backspace_outlined,
            onTap: () => setState(() => _pin = _pin.isEmpty ? '' : _pin.substring(0, _pin.length - 1)),
          ),
        ]),
      ]);
}

class _Key extends StatelessWidget {
  const _Key({this.label, this.icon, required this.onTap});
  final String? label;
  final IconData? icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(6),
        child: Material(
          color: label == null ? Colors.transparent : Fk.card,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(
              width: 84,
              height: 68,
              child: Center(
                child: label != null
                    ? Text(label!, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700))
                    : Icon(icon, size: 30, color: icon == Icons.backspace_outlined ? Fk.muted : Fk.knit),
              ),
            ),
          ),
        ),
      );
}
