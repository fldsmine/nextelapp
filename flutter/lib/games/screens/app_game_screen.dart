import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:nextel_connect/app/router/app_routes.dart';
import 'package:nextel_connect/app/theme/app_theme.dart';
import 'package:nextel_connect/games/dice/core/theme/app_theme.dart' as games_theme;
import 'package:nextel_connect/games/dice/features/logic/game_controller.dart';
import 'package:nextel_connect/games/dice/features/ui/screens/dice_screen.dart';
import 'package:nextel_connect/games/ludo/ludo_provider.dart';
import 'package:nextel_connect/games/ludo/ludo_screen.dart';
import 'package:nextel_connect/games/screens/game_screen.dart';
import 'package:nextel_connect/games/screens/loading_screen.dart';
import 'package:nextel_connect/games/utilities/hangman_words.dart';
import 'package:nextel_connect/games/widgets/bottom_help_sheet.dart';
import 'package:nextel_connect/games/widgets/feature_middle_card.dart';
import 'package:nextel_connect/games/widgets/featured_card.dart';
import 'package:nextel_connect/games/widgets/small_feature_card.dart';

class AppGameScreen extends StatefulWidget {
  const AppGameScreen({super.key});

  @override
  State<AppGameScreen> createState() => _AppGameScreenState();
}

class _AppGameScreenState extends State<AppGameScreen> {
  late final HangmanWords _hangmanWords;
  late final Future<void> _wordsReady;

  @override
  void initState() {
    super.initState();
    _hangmanWords = HangmanWords();
    _wordsReady = _hangmanWords.readWords();
  }

  void _openDice() {
    unawaited(
      Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => Theme(
            data: games_theme.AppTheme.darkTheme,
            child: ChangeNotifierProvider(
              create: (_) => GameController(),
              child: const DiceScreen(),
            ),
          ),
        ),
      ),
    );
  }

  void _openLudo() {
    unawaited(
      Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => Theme(
            data: games_theme.AppTheme.darkTheme,
            child: ChangeNotifierProvider(
              create: (_) => LudoProvider()..startGame(),
              child: const LudoScreen(),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openHangman() async {
    await _wordsReady;
    if (!mounted) return;
    unawaited(
      Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => Theme(
            data: games_theme.AppTheme.darkTheme,
            child: GameScreen(hangmanObject: _hangmanWords),
          ),
        ),
      ),
    );
  }

  void _openScores() {
    unawaited(
      Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => Theme(
            data: games_theme.AppTheme.darkTheme,
            child: const LoadingScreen(),
          ),
        ),
      ),
    );
  }

  void _showGameGuide() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const BottomHelpSheet(
        title: Text('GAME GUIDE'),
        content: Text(
          'Ludo: roll the dice and move your pawns around the board. A six '
          'brings a pawn out of home; safe squares protect pawns from being '
          'captured.\n\n'
          'Dice Roll: choose a face, set your stake and roll. A matching face '
          'returns five times the stake; a miss deducts the stake. Auto Play '
          'offers Manual, Fixed and Martingale strategies.\n\n'
          'Hangman: guess the hidden word before you run out of lives. Use '
          'your hint carefully, then check Scores for your best runs.',
          style: TextStyle(height: 1.55),
        ),
      ),
    );
  }

  void _goBack() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.dashboard);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NextelPalette.primary,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 6, 18, 14),
              child: Row(
                children: [
                  IconButton.filledTonal(
                    tooltip: 'Back to dashboard',
                    onPressed: _goBack,
                    style: IconButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: Colors.white.withValues(alpha: .12),
                    ),
                    icon: const Icon(Icons.arrow_back),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'System games',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Game guide',
                    onPressed: _showGameGuide,
                    icon: const Icon(Icons.help_outline, color: Colors.white),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: NextelPalette.background,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 22, 16, 30),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Play, compete and unwind',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Pick a game and make your next move.',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface
                              .withValues(alpha: .62),
                        ),
                      ),
                      const SizedBox(height: 18),
                      FeaturedCard(
                        image: 'assets/images/ludo.jpg',
                        title: 'Ludo',
                        subtitle: 'Four colours. One board. Play pass-and-play.',
                        emoji: '🎲',
                        borderColor: NextelPalette.accent,
                        onTap: _openLudo,
                      ),
                      const SizedBox(height: 25),
                      Text(
                        'Quick games',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 200,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: [
                            SmallFeatureCard(
                              title: 'Dice Roll',
                              image: 'assets/images/ad_card2.png',
                              badge: 'STRATEGY',
                              onTap: _openDice,
                            ),
                            SmallFeatureCard(
                              title: 'Hangman',
                              image: 'assets/images/hangman.jpg',
                              badge: 'WORD GAME',
                              onTap: () => unawaited(_openHangman()),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 22),
                      Row(
                        children: [
                          Expanded(
                            child: FeatureMiddleCard(
                              title: 'Hangman high scores',
                              image: 'assets/images/ad_card4.png',
                              badge: 'RECORDS',
                              onTap: _openScores,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FeatureMiddleCard(
                              title: 'Rules and tips',
                              image: 'assets/images/ad_card3.png',
                              badge: 'GUIDE',
                              onTap: _showGameGuide,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
