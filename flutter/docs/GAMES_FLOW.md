# Games flow and source integration

The `/games` route in `lib/app/router/app_router.dart` opens `lib/games/screens/app_game_screen.dart`. The game implementation is adapted from the uploaded `actual-flutter-game/lib/games/` folder; game controllers, rules, board/word/dice screens and artwork remain Flutter. The host app keeps its existing GoRouter, Riverpod setup, app-level theme and Android bridges.

## Navigation and providers

- Dice is pushed as a nested game route with a `GameController` provider.
- Ludo is pushed with a `LudoProvider`; `startGame()` is called in the provider factory so its four player models exist before the board renders.
- Hangman awaits the original word-list asset before creating its screen.
- High scores open the source SQLite loading/score screens.
- Game screens use the source dark-theme appearance. The Games hub follows the host app palette.
- The upload did not include the shared feature-card and help-sheet widgets or the original app root, so small Flutter-native card/sheet equivalents are provided in `lib/games/widgets/`. The app theme uses the locally bundled Poppins font instead of downloading a Google Font at runtime.

## Assets and dependencies

The game image, Lottie, sound and word-list assets are bundled under `assets/images/`, `assets/lottie/`, `assets/sounds/` and `assets/res/`. Fira Mono and Patrick Hand are registered in `pubspec.yaml`. Game-only packages (audio, animation, provider, alerts, icons and SQLite) are scoped to the Flutter app dependencies.

## Existing game data

The existing `LegacyDataMigrator` copies old Android JSON preferences to the logical keys `games.dice.history.v1` and `games.hangman.scores.v1` before routes can open. Dice accepts its original `game_history` schema and those old aliases (`rolled`, `selected`, `bet`, `result`, `win`, `at`), then writes imported entries back using the uploaded source schema. Hangman maps old `score`/`date` objects into the source SQLite columns `userScore`/`scoreDate` in `scores_database.db`. Its import completion marker is `games.hangman.sqlite_imported.v1`; malformed or failed imports leave the preference payload intact for a retry. The two legacy JSON preference values are not deleted by the games importer.

## Verification

`test/dice_history_migration_test.dart`, `test/hangman_legacy_scores_test.dart` and `test/ludo_provider_test.dart` cover the data mappings and Ludo initialization. Run `flutter analyze` and `flutter test` from this directory after installing Flutter 3.32+ / Dart 3.8+. Device, audio-plugin and SQLite integration still require Android runtime verification.
