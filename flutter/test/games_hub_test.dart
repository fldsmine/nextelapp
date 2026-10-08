import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nextel_connect/games/screens/app_game_screen.dart';

void main() {
  testWidgets('Games hub presents the integrated games and score entry', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: AppGameScreen()),
    );
    await tester.pumpAndSettle();

    expect(find.text('System games'), findsOneWidget);
    expect(find.text('Ludo'), findsOneWidget);
    expect(find.text('Dice Roll'), findsOneWidget);
    expect(find.text('Hangman'), findsOneWidget);
    expect(find.text('Hangman high scores'), findsOneWidget);
  });
}
