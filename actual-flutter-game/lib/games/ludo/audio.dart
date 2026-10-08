import 'package:audioplayers/audioplayers.dart';

class Audio {
  static final AudioPlayer _player = AudioPlayer();

  static Future<void> playMove() async {
    await _player.stop();
    await _player.play(AssetSource('sounds/move.wav'));
  }

  static Future<void> playKill() async {
    await _player.stop();
    await _player.play(AssetSource('sounds/laugh.mp3'));
  }

  static Future<void> rollDice() async {
    await _player.stop();
    await _player.play(AssetSource('sounds/roll_the_dice.mp3'));
  }

}
