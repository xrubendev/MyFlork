import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import 'theme.dart';

/// Bottom bar with the five sections; the active one sits on a pink-tinted tile.
class Shell extends StatelessWidget {
  const Shell({super.key, required this.shell});
  final StatefulNavigationShell shell;

  static const _tabs = [
    (Icons.home_rounded, 'Home'),
    (Icons.account_balance_wallet_rounded, 'Wallet'),
    (Icons.show_chart_rounded, 'Market'),
    (Icons.history_rounded, 'Activity'),
    (Icons.auto_awesome_rounded, 'Florkverse'),
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
        body: shell,
        bottomNavigationBar: DecoratedBox(
          decoration: const BoxDecoration(color: Fk.surface, border: Border(top: BorderSide(color: Fk.line))),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
              child: Row(children: [
                for (var i = 0; i < _tabs.length; i++)
                  Expanded(
                      child: _Tab(
                          icon: _tabs[i].$1,
                          label: _tabs[i].$2,
                          active: shell.currentIndex == i,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            shell.goBranch(i, initialLocation: i == shell.currentIndex);
                          })),
              ]),
            ),
          ),
        ),
      );
}

class _Tab extends StatelessWidget {
  const _Tab({required this.icon, required this.label, required this.active, required this.onTap});
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? Fk.knit : Fk.muted;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(color: active ? Fk.knitSoft : Colors.transparent, borderRadius: BorderRadius.circular(16)),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: color, size: 26),
          const SizedBox(height: 4),
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.fade,
              softWrap: false,
              style: TextStyle(color: color, fontSize: 12, fontWeight: active ? FontWeight.w700 : FontWeight.w500)),
        ]),
      ),
    );
  }
}
