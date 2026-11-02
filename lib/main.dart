import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/router.dart';
import 'app/theme.dart';
import 'core/lock.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: Fk.surface,
  ));
  runApp(const ProviderScope(child: MyFlork()));
}

class MyFlork extends ConsumerStatefulWidget {
  const MyFlork({super.key});

  @override
  ConsumerState<MyFlork> createState() => _MyFlorkState();
}

class _MyFlorkState extends ConsumerState<MyFlork> {
  late final AppLifecycleListener _life;
  DateTime? _hiddenAt;

  // Locks again after a minute in the background; short trips (biometric prompt, share sheet) don't count.
  static const _grace = Duration(minutes: 1);

  @override
  void initState() {
    super.initState();
    _life = AppLifecycleListener(
      onHide: () => _hiddenAt = DateTime.now(),
      onShow: () {
        if (_hiddenAt != null && DateTime.now().difference(_hiddenAt!) > _grace) ref.read(lockProvider.notifier).lock();
        _hiddenAt = null;
      },
    );
  }

  @override
  void dispose() {
    _life.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp.router(
        title: 'MyFlork',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        routerConfig: ref.watch(routerProvider),
      );
}
