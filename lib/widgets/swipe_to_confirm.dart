import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/theme.dart';

/// Drag the Flork knob to the end to confirm; let go early and it springs back.
class SwipeToConfirm extends StatefulWidget {
  const SwipeToConfirm({super.key, required this.label, required this.onConfirm, this.enabled = true});
  final String label;
  final Future<void> Function() onConfirm;
  final bool enabled;

  @override
  State<SwipeToConfirm> createState() => _SwipeToConfirmState();
}

class _SwipeToConfirmState extends State<SwipeToConfirm> with SingleTickerProviderStateMixin {
  static const _h = 64.0, _pad = 6.0;
  late final _back = AnimationController(vsync: this, duration: const Duration(milliseconds: 260));
  double _x = 0, _from = 0;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _back.addListener(() => setState(() => _x = _from * (1 - Curves.easeOutCubic.transform(_back.value))));
  }

  @override
  void dispose() {
    _back.dispose();
    super.dispose();
  }

  Future<void> _release(double max) async {
    if (_x >= max * 0.92) {
      HapticFeedback.mediumImpact();
      setState(() {
        _x = max;
        _busy = true;
      });
      try {
        await widget.onConfirm();
      } finally {
        if (mounted) {
          _busy = false;
          _from = _x;
          _back.forward(from: 0);
        }
      }
    } else {
      _from = _x;
      _back.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final on = widget.enabled && !_busy;
    return LayoutBuilder(builder: (context, c) {
      final max = c.maxWidth - _h;
      final t = max <= 0 ? 0.0 : (_x / max).clamp(0.0, 1.0);
      return Opacity(
        opacity: widget.enabled ? 1 : 0.45,
        child: Container(
          height: _h,
          decoration: BoxDecoration(
            color: Color.lerp(Fk.card, Fk.knitSoft, t),
            borderRadius: BorderRadius.circular(Fk.rPill),
            border: Border.all(color: Fk.lineStrong),
          ),
          child: Stack(alignment: Alignment.centerLeft, children: [
            Center(
              child: _busy
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Fk.knit))
                  : Opacity(
                      opacity: 1 - t,
                      child: Text(widget.label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                    ),
            ),
            Positioned(
              left: _x,
              child: GestureDetector(
                onHorizontalDragUpdate: on ? (d) => setState(() => _x = (_x + d.delta.dx).clamp(0, max)) : null,
                onHorizontalDragEnd: on ? (_) => _release(max) : null,
                child: Container(
                  width: _h,
                  height: _h,
                  padding: const EdgeInsets.all(_pad),
                  child: DecoratedBox(
                    decoration: const BoxDecoration(color: Fk.knit, shape: BoxShape.circle),
                    child: Icon(t > 0.92 ? Icons.check_rounded : Icons.arrow_forward_rounded, color: Colors.white),
                  ),
                ),
              ),
            ),
          ]),
        ),
      );
    });
  }
}
