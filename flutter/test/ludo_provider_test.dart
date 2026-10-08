import 'package:flutter_test/flutter_test.dart';
import 'package:nextel_connect/games/ludo/constants.dart';
import 'package:nextel_connect/games/ludo/ludo_provider.dart';

void main() {
  test('startGame initializes all four pass-and-play players', () {
    final provider = LudoProvider()..startGame();
    addTearDown(provider.dispose);

    expect(provider.players, hasLength(4));
    expect(
      provider.players.map((player) => player.type),
      containsAll(LudoPlayerType.values),
    );
    expect(provider.players.every((player) => player.pawns.length == 4), isTrue);
    expect(provider.winners, isEmpty);
  });
}
