import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Game sounds (made for MyFlork, in assets/sfx) with an on/off switch that survives restarts.
class Sfx extends Notifier<bool> {
  static const _key = 'myflork.sound';
  final _tick = AudioPool.createFromAsset(path: 'sfx/wheel_tick.ogg', maxPlayers: 4);
  final _player = AudioPlayer()..setPlayerMode(PlayerMode.lowLatency);

  @override
  bool build() {
    SharedPreferences.getInstance().then((p) => state = p.getBool(_key) ?? true);
    ref.onDispose(_player.dispose);
    return true;
  }

  Future<void> toggle() async {
    state = !state;
    (await SharedPreferences.getInstance()).setBool(_key, state);
  }

  Future<void> tick() async {
    if (state) (await _tick).start(volume: 0.7);
  }

  Future<void> play(String name) async {
    if (state) await _player.play(AssetSource('sfx/$name.ogg'));
  }
}

final sfxProvider = NotifierProvider<Sfx, bool>(Sfx.new);
