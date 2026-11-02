import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/lock.dart';
import '../core/wallet.dart';
import '../features/lock/lock_screens.dart';
import '../features/activity/activity_screen.dart';
import '../features/florkverse/app_detail_screen.dart';
import '../features/florkverse/apps.dart';
import '../features/florkverse/browser_screen.dart';
import '../features/florkverse/florkverse_screen.dart';
import '../features/home/home_screen.dart';
import '../features/market/market_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/quests/quests_screen.dart';
import '../features/quests/wheel_screen.dart';
import '../features/swap/swap_screen.dart';
import '../widgets/token_picker.dart';
import '../features/wallet/receive_screen.dart';
import '../features/wallet/send_screen.dart';
import '../features/wallet/settings_screen.dart';
import '../features/wallet/wallet_screen.dart';
import 'shell.dart';
import 'theme.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier(0);
  ref.listen(walletProvider, (_, __) => refresh.value++);
  ref.listen(lockProvider, (_, __) => refresh.value++);
  ref.onDispose(refresh.dispose);

  String? pending;

  return GoRouter(
    initialLocation: '/home',
    refreshListenable: refresh,
    redirect: (context, state) {
      final wallet = ref.read(walletProvider);
      final lock = ref.read(lockProvider);
      final at = state.matchedLocation;
      if (wallet.isLoading || !lock.ready) return at == '/splash' ? null : '/splash';
      // Gate order: a wallet, then a PIN, then unlocked.
      final String? gate = wallet.valueOrNull == null
          ? '/welcome'
          : !lock.hasPin
              ? '/set-pin'
              : lock.locked
                  ? '/lock'
                  : null;
      const gates = ['/splash', '/welcome', '/set-pin', '/lock'];
      if (gate != null) {
        // Keep where a link wanted to go (myflork://open/wheel) and go there once unlocked.
        if (!gates.contains(at)) pending = at;
        return at == gate ? null : gate;
      }
      if (gates.contains(at)) {
        final next = pending ?? '/home';
        pending = null;
        return next;
      }
      return null;
    },
    routes: [
      GoRoute(
          path: '/splash', builder: (_, __) => const Scaffold(body: Center(child: CircularProgressIndicator(color: Fk.knit)))),
      GoRoute(path: '/welcome', builder: (_, __) => const OnboardingScreen()),
      GoRoute(path: '/set-pin', builder: (_, __) => const SetPinScreen()),
      GoRoute(path: '/lock', builder: (_, __) => const LockScreen()),
      GoRoute(path: '/change-pin', builder: (_, __) => const SetPinScreen(changing: true)),
      StatefulShellRoute.indexedStack(
        builder: (_, __, shell) => Shell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [GoRoute(path: '/home', builder: (_, __) => const HomeScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/wallet', builder: (_, __) => const WalletScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/market', builder: (_, __) => const MarketScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/activity', builder: (_, __) => const ActivityScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/florkverse', builder: (_, __) => const FlorkverseScreen())]),
        ],
      ),
      GoRoute(path: '/quests', builder: (_, __) => const QuestsScreen()),
      GoRoute(path: '/wheel', builder: (_, __) => const WheelScreen()),
      GoRoute(path: '/send', builder: (_, __) => const SendScreen()),
      GoRoute(path: '/swap', builder: (_, s) => SwapScreen(initialTo: s.extra as Tok?)),
      GoRoute(path: '/receive', builder: (_, __) => const ReceiveScreen()),
      GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
      GoRoute(path: '/app', builder: (_, s) => AppDetailScreen(app: s.extra! as FlorkApp)),
      GoRoute(path: '/browse', builder: (_, s) => BrowserScreen(app: s.extra! as FlorkApp)),
    ],
  );
});
