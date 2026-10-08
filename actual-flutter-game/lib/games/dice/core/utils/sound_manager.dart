import 'package:audioplayers/audioplayers.dart';

class SoundManager {
  static final AudioPlayer _player = AudioPlayer();

  static Future<void> play(String path) async {
    await _player.stop();
    await _player.play(AssetSource(path));
  }

  static void click() => play('sounds/click.mp3');
  static void roll() => play('sounds/dice.mp3');
  static void stop() => play('sounds/move.wav');
  static void win() => play('sounds/win.mp3');
  static void lose() => play('sounds/lost.mp3');
}