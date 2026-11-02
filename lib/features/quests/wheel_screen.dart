import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/family_api.dart';
import '../../core/sfx.dart';
import '../../core/wallet.dart';
import '../../widgets/common.dart';

/// The Flork wheel, paying Flork. The server picks the prize; the wheel only shows it landing.
class WheelScreen extends ConsumerStatefulWidget {
  const WheelScreen({super.key});

  @override
  ConsumerState<WheelScreen> createState() => _WheelScreenState();
}

class _WheelScreenState extends ConsumerState<WheelScreen> with SingleTickerProviderStateMixin {
  late final _spin = AnimationController(vsync: this, duration: const Duration(milliseconds: 4200));
  double _from = 0, _to = 0;
  bool _busy = false;
  int _lastTick = 0;

  @override
  void initState() {
    super.initState();
    _spin.addListener(() {
      // A light tick each time a slice passes the pointer.
      final n = ref.read(wheelProvider).valueOrNull?.prizes.length ?? 7;
      final slice = (_angle / (2 * pi / n)).floor();
      if (slice != _lastTick) {
        _lastTick = slice;
        HapticFeedback.selectionClick();
        ref.read(sfxProvider.notifier).tick();
      }
      setState(() {});
    });
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  double get _angle => _from + (_to - _from) * Curves.easeOutQuart.transform(_spin.value);

  Future<void> _go(int slices) async {
    final wallet = ref.read(walletProvider).valueOrNull;
    if (wallet == null || _busy) return;
    setState(() => _busy = true);
    try {
      final r = await spinWheel(wallet);
      ref.read(sfxProvider.notifier).play('wheel_start');
      final slice = 2 * pi / slices;
      // Slice i is drawn starting at angle i*slice from the top, clockwise; land its middle under the pointer.
      final target = 2 * pi - (r.index * slice + slice / 2);
      final base = _angle - (_angle % (2 * pi));
      _from = _angle;
      _to = base + 6 * 2 * pi + target + (Random().nextDouble() - 0.5) * slice * 0.6;
      await _spin.forward(from: 0);
      HapticFeedback.heavyImpact();
      ref.read(sfxProvider.notifier).play(r.points >= 500 ? 'wheel_jackpot' : 'wheel_win');
      ref.invalidate(wheelProvider);
      ref.invalidate(pointsProvider);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (c) => AlertDialog(
          backgroundColor: Fk.surface,
          icon: SvgPicture.asset('assets/art/svg/loot_box.svg', height: 120),
          title:
              Text('+${r.points} FLORK', textAlign: TextAlign.center, style: Fk.display.copyWith(fontSize: 34, color: Fk.knit)),
          content: const Text('Added to your Flork on flork.family.', textAlign: TextAlign.center),
          actions: [FilledButton(onPressed: () => Navigator.pop(c), child: const Text('Nice'))],
        ),
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'.replaceFirst('Exception: ', ''))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final wheel = ref.watch(wheelProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Flork wheel'), actions: [
        IconButton(
          tooltip: ref.watch(sfxProvider) ? 'Mute' : 'Sound on',
          icon: Icon(ref.watch(sfxProvider) ? Icons.volume_up_rounded : Icons.volume_off_rounded),
          onPressed: () => ref.read(sfxProvider.notifier).toggle(),
        ),
      ]),
      body: wheel.when(
        loading: () => const Center(child: CircularProgressIndicator(color: Fk.knit)),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child:
                Text('$e'.replaceFirst('Exception: ', ''), textAlign: TextAlign.center, style: const TextStyle(color: Fk.muted)),
          ),
        ),
        data: (w) => ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 24), children: [
          Text('SPIN FOR FLORK', textAlign: TextAlign.center, style: Fk.display.copyWith(fontSize: 34, color: Fk.knit)),
          const SizedBox(height: 4),
          const Text('One spin a day, plus one for every quest you finish.',
              textAlign: TextAlign.center, style: TextStyle(color: Fk.muted)),
          const SizedBox(height: 24),
          AspectRatio(
            aspectRatio: 1,
            child: Stack(alignment: Alignment.center, children: [
              Transform.rotate(angle: _angle, child: CustomPaint(size: Size.infinite, painter: _WheelPainter(w.prizes))),
              Container(
                width: 96,
                height: 96,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: Fk.bg, width: 5),
                  boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 16)],
                ),
                child: Image.asset('assets/art/logo_flork.png'),
              ),
              const Align(alignment: Alignment.topCenter, child: _Pointer()),
            ]),
          ),
          const SizedBox(height: 28),
          FilledButton(
            onPressed: w.tickets > 0 && !_busy ? () => _go(w.prizes.length) : null,
            child: Text(_busy
                ? 'Spinning…'
                : w.tickets > 0
                    ? 'Spin · ${w.tickets} left'
                    : 'Next free spin in ${_until(w.nextDaily)}'),
          ),
          if (w.recent.isNotEmpty) ...[
            const SectionTitle('Your spins'),
            for (final r in w.recent)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(children: [
                  const Icon(Icons.casino_rounded, color: Fk.knit, size: 20),
                  const SizedBox(width: 10),
                  Expanded(child: Text('${r.at.toLocal()}'.substring(0, 16), style: const TextStyle(color: Fk.muted))),
                  Text('+${r.points}', style: const TextStyle(fontWeight: FontWeight.w800, color: Fk.gold)),
                ]),
              ),
          ],
        ]),
      ),
    );
  }

  static String _until(DateTime t) {
    final d = t.difference(DateTime.now());
    if (d.isNegative) return 'a moment';
    return d.inHours > 0 ? '${d.inHours}h ${d.inMinutes % 60}m' : '${d.inMinutes}m';
  }
}

class _Pointer extends StatelessWidget {
  const _Pointer();

  @override
  Widget build(BuildContext context) => CustomPaint(size: const Size(34, 40), painter: _PointerPainter());
}

class _PointerPainter extends CustomPainter {
  @override
  void paint(Canvas c, Size s) {
    final p = Path()
      ..moveTo(0, 0)
      ..lineTo(s.width, 0)
      ..lineTo(s.width / 2, s.height)
      ..close();
    c.drawShadow(p, Colors.black, 6, false);
    c.drawPath(p, Paint()..color = Fk.gold);
    c.drawPath(
        p,
        Paint()
          ..color = Fk.bg
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3);
  }

  @override
  bool shouldRepaint(_) => false;
}

class _WheelPainter extends CustomPainter {
  _WheelPainter(this.prizes);
  final List<int> prizes;

  static const _fills = [Fk.knit, Color(0xFF3A2440), Color(0xFFB8336A), Fk.card];

  @override
  void paint(Canvas c, Size s) {
    final r = s.shortestSide / 2;
    final center = Offset(s.width / 2, s.height / 2);
    final rect = Rect.fromCircle(center: center, radius: r - 8);
    final slice = 2 * pi / prizes.length;

    c.drawCircle(center, r, Paint()..color = Fk.bg);
    for (var i = 0; i < prizes.length; i++) {
      // Slice i starts at the top (-pi/2) and runs clockwise.
      final start = -pi / 2 + i * slice;
      c.drawArc(rect, start, slice, true, Paint()..color = _fills[i % _fills.length]);
      c.drawArc(
          rect,
          start,
          slice,
          true,
          Paint()
            ..color = Fk.bg
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3);

      final mid = start + slice / 2;
      final label = TextPainter(
        text: TextSpan(
          text: '${prizes[i]}',
          style: TextStyle(
            fontFamily: 'ComicKats',
            fontSize: prizes[i] >= 1000 ? 26 : 30,
            color: prizes[i] >= 500 ? Fk.gold : Colors.white,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      c.save();
      c.translate(center.dx + cos(mid) * r * 0.66, center.dy + sin(mid) * r * 0.66);
      c.rotate(mid + pi / 2);
      label.paint(c, Offset(-label.width / 2, -label.height / 2));
      c.restore();
    }
    // Rim with bulbs, like a fair wheel.
    c.drawCircle(
        center,
        r - 4,
        Paint()
          ..color = Fk.gold
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6);
    for (var i = 0; i < prizes.length * 3; i++) {
      final a = i * 2 * pi / (prizes.length * 3);
      c.drawCircle(center + Offset(cos(a), sin(a)) * (r - 4), 4, Paint()..color = i.isEven ? Colors.white : Fk.knit);
    }
  }

  @override
  bool shouldRepaint(covariant _WheelPainter old) => old.prizes != prizes;
}
