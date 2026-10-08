import 'package:flutter/material.dart';
import 'package:sample_app/games/screens/score_screen.dart';
import 'package:sample_app/games/utilities/score_db.dart' as score_database;
import 'package:sample_app/games/utilities/user_scores.dart';
import 'package:lottie/lottie.dart';

class LoadingScreen extends StatefulWidget {
  const LoadingScreen({super.key});

  @override
  LoadingScreenState createState() => LoadingScreenState();
}

class LoadingScreenState extends State<LoadingScreen> {
  @override
  void initState() {
    super.initState();
    queryScores();
  }

  void queryScores() async {
    final database = score_database.openDB();
    List<Score> queryResult = await score_database.scores(database);
    goToScoreScreen(queryResult);
  }

  void goToScoreScreen(List<Score> queryResult) {
    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) {
          return ScoreScreen(
            query: queryResult,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Lottie.asset(
          'assets/lottie/loading.json',
          width: 150,
          height: 150,
          repeat: true,
        ),
      ),
    );
  }
}