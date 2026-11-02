import 'package:flutter/material.dart';

import '../app/theme.dart';

/// Rounded card surface used everywhere.
class FkCard extends StatelessWidget {
  const FkCard({super.key, required this.child, this.padding = const EdgeInsets.all(20), this.color = Fk.card, this.onTap});
  final Widget child;
  final EdgeInsets padding;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: color,
        borderRadius: BorderRadius.circular(Fk.r),
        clipBehavior: Clip.antiAlias,
        child: InkWell(onTap: onTap, child: Padding(padding: padding, child: child)),
      );
}

/// White pill with an icon, as on the balance card.
class ActionPill extends StatelessWidget {
  const ActionPill({super.key, required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Material(
          color: Fk.chalk,
          shape: const StadiumBorder(),
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: onTap,
            child: SizedBox(
              height: 52,
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(icon, size: 20, color: Fk.bg),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(label,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Fk.bg, fontWeight: FontWeight.w700, fontSize: 15)),
                ),
              ]),
            ),
          ),
        ),
      );
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 28, 4, 12),
        child: Row(children: [
          Expanded(child: Text(text, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800))),
          if (trailing != null) trailing!,
        ]),
      );
}

/// Token logo with a fallback initial.
class TokenLogo extends StatelessWidget {
  const TokenLogo({super.key, required this.symbol, this.url, this.size = 40});
  final String symbol;
  final String? url;
  final double size;

  @override
  Widget build(BuildContext context) {
    final fallback = CircleAvatar(
      radius: size / 2,
      backgroundColor: Fk.cardHi,
      child: Text(symbol.isEmpty ? '?' : symbol[0], style: const TextStyle(fontWeight: FontWeight.w800)),
    );
    if (url == null) return fallback;
    return ClipOval(
      child: Image.network(url!, width: size, height: size, fit: BoxFit.cover, errorBuilder: (_, __, ___) => fallback),
    );
  }
}

String usd(double v) {
  if (v >= 1000) return '\$${v.toStringAsFixed(0).replaceAllMapped(RegExp(r'\B(?=(\d{3})+$)'), (_) => ',')}';
  if (v >= 1) return '\$${v.toStringAsFixed(2)}';
  if (v == 0) return '\$0.00';
  return '\$${v.toStringAsPrecision(3)}';
}

String amount(double v) => v >= 1000 ? v.toStringAsFixed(0) : (v >= 1 ? v.toStringAsFixed(3) : v.toStringAsPrecision(4));
