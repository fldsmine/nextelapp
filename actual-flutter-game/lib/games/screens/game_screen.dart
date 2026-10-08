import 'dart:math';

import 'package:flutter/material.dart';
import 'package:sample_app/games/components/word_button.dart';
import 'package:sample_app/games/screens/app_game_screen.dart';
import 'package:sample_app/games/screens/loading_screen.dart';
import 'package:sample_app/games/utilities/alphabet.dart';
import 'package:sample_app/games/utilities/constants.dart';
import 'package:sample_app/games/utilities/hangman_words.dart';
import 'package:sample_app/games/utilities/score_db.dart' as score_database;
import 'package:sample_app/games/utilities/user_scores.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:rflutter_alert/rflutter_alert.dart';

class GameScreen extends StatefulWidget {
  final HangmanWords hangmanObject;

  const GameScreen({super.key,	required this.hangmanObject });

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  final database = score_database.openDB();
  int lives = 5;
  Alphabet englishAlphabet = Alphabet();
  late String word;
  late String hiddenWord;
  List<String> wordList = [];
  List<int> hintLetters = [];
  late List<bool> buttonStatus;
  late bool hintStatus;
  int hangState = 0;
  int wordCount = 0;
  bool finishedGame = false;
  bool resetGame = false;
  late List<bool> isSelected;

  void newGame() {
    setState(() {
      widget.hangmanObject.resetWords();
      englishAlphabet = Alphabet();
      lives = 5;
      wordCount = 0;
      finishedGame = false;
      resetGame = false;
      initWords();
    });
  }

  Widget createButton(index) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 3.5, vertical: 6.0),
      child: Center(
        child: WordButton(
          buttonTitle: englishAlphabet.alphabet[index].toUpperCase(),
          onPress: buttonStatus[index] ? () => wordPress(index) : () {},
		  isSelected: isSelected[index], 
        ),
      ),
    );
  }

  void returnHomePage() {
    /*Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => AppGameScreen()),
      ModalRoute.withName('homePage'),
    );*/
  }

  void initWords() {
    finishedGame = false;
    resetGame = false;
    hintStatus = true;
    hangState = 0;
	buttonStatus = List.generate(26, (index) => true);
	isSelected = List.generate(26, (index) => false);

    wordList = [];
    hintLetters = [];
    word = widget.hangmanObject.getWord();
	
    if (word.isNotEmpty) {
      hiddenWord = widget.hangmanObject.getHiddenWord(word.length);
    } else {
      returnHomePage();
    }

    for (int i = 0; i < word.length; i++) {
      wordList.add(word[i]);
      hintLetters.add(i);
    }
  }

  void wordPress(int index) {
    if (lives == 0) {
      returnHomePage();
    }

    if (finishedGame) {
      setState(() {
        resetGame = true;
      });
      return;
    }
		/*ScaffoldMessenger.of(context).showSnackBar(
		  SnackBar(
			content: Text(word),
			duration: Duration(seconds: 2),
			behavior: SnackBarBehavior.floating, 
		  ),
		);*/

    bool check = false;
    setState(() {
      for (int i = 0; i < wordList.length; i++) {
        if (wordList[i] == englishAlphabet.alphabet[index]) {
          check = true;
          wordList[i] = '';
          hiddenWord = hiddenWord.replaceFirst(RegExp('_'), word[i], i);
        }
      }
	  
      for (int i = 0; i < wordList.length; i++) {
        if (wordList[i] == '') {
          hintLetters.remove(i);
        }
      }
      if (!check) {
        hangState += 1;
      }

      if (hangState == 6) {
        finishedGame = true;
        lives -= 1;
        if (lives < 1) {
          if (wordCount > 0) {
            Score score = Score(
                id: 1,
                scoreDate: DateTime.now().toString(),
                userScore: wordCount);
            score_database.manipulateDatabase(score, database);
          }
          Alert(
              style: kGameOverAlertStyle,
              context: context,
              title: "Game Over!",
              desc: "Your score is $wordCount",
              buttons: [
                DialogButton(
                  color: kDialogButtonColor,
                  onPressed: () => returnHomePage(),
                  child: Icon(
                    MdiIcons.home,
                    size: 30.0,
                  ),
                ),
                DialogButton(
                  onPressed: () {
                    newGame();
                    Navigator.pop(context);
                  },
                  color: kDialogButtonColor,
                  child: Icon(MdiIcons.refresh, size: 30.0),
                ),
              ]).show();
        } else {
          Alert(
            context: context,
            style: kFailedAlertStyle,
            type: AlertType.error,
            title: word,
            buttons: [
              DialogButton(
                radius: BorderRadius.circular(10),
                width: 127,
                color: kDialogButtonColor,
                height: 52,
                child: Icon(
                  MdiIcons.arrowRightThick,
                  size: 30.0,
                ),
                onPressed: () {
                  setState(() {
                    Navigator.pop(context);
                    initWords();
                  });
                },
              ),
            ],
          ).show();
        }
      }

      buttonStatus[index] = false;
	  isSelected[index] = true;
	  
      if (hiddenWord == word) {
        finishedGame = true;
        Alert(
          context: context,
          style: kSuccessAlertStyle,
          type: AlertType.success,
          title: word,
          buttons: [
            DialogButton(
              radius: BorderRadius.circular(10),
              width: 127,
              color: kDialogButtonColor,
              height: 52,
              child: Icon(
                MdiIcons.arrowRightThick,
                size: 30.0,
              ),
              onPressed: () {
                setState(() {
                  wordCount += 1;
                  Navigator.pop(context);
                  initWords();
                });
              },
            )
          ],
        ).show();
      }
    });
  }

  @override
  void initState() {
    super.initState();
    initWords();
  }

  @override
  Widget build(BuildContext context) {
    if (resetGame) {
      setState(() {
        initWords();
      });
    }
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: <Widget>[
              Expanded(
                  flex: 4,
                  child: Column(
                    children: <Widget>[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(6.0, 8.0, 6.0, 35.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: <Widget>[
                            Row(
                              children: <Widget>[
							    IconButton.filled(
									tooltip: 'End game',
									highlightColor: Colors.transparent,
									splashColor: Colors.transparent,
									iconSize: 24,
									icon: Icon(Icons.adaptive.arrow_back),
									onPressed: () {
										showDialog(
										  context: context,
										  builder: (dialogContext) => AlertDialog(
											title: Text("Exit Game"),
											content: Text("Are you sure you want to exit the current game?"),
											backgroundColor: Colors.white,
											actions: [
											  TextButton.icon(
												onPressed: () => Navigator.pop(dialogContext),
												icon: Icon(Icons.close, color: Colors.red),
												label: Text("Cancel", style: TextStyle(color: Colors.red)),
											  ),
											  ElevatedButton.icon(
												onPressed: () { 
													Navigator.of(dialogContext).pop();
													Navigator.pop(context);
												},
												icon: Icon(Icons.check),
												label: Text("Proceed"),
											  ),
											],
										  ),
										);
									},
								),
							    SizedBox(width: 10),
							  
                                Stack(
                                  children: <Widget>[
                                    Container(
                                      padding: const EdgeInsets.only(top: 0.5),
                                      child: IconButton(
                                        tooltip: 'Lives',
                                        highlightColor: Colors.transparent,
                                        splashColor: Colors.transparent,
                                        iconSize: 39,
                                        icon: Icon(MdiIcons.heart),
                                        onPressed: () {},
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.fromLTRB(
                                          8.7, 7.9, 0, 0.8),
                                      alignment: Alignment.center,
                                      child: SizedBox(
                                        height: 38,
                                        width: 38,
                                        child: Center(
                                          child: Padding(
                                            padding: const EdgeInsets.all(2.0),
                                            child: Text(
                                              lives.toString() == "1"
                                                  ? "I"
                                                  : lives.toString(),
                                              style: const TextStyle(
                                                color: Color(0xFF2C1E68),
                                                fontSize: 20,
                                                fontWeight: FontWeight.bold,
                                                fontFamily: 'PatrickHand',
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    )
                                  ],
                                ),
                              ],
                            ),
                            SizedBox(
                              child: Text(
                                wordCount == 1 ? "I" : '$wordCount',
                                style: kWordCounterTextStyle,
                              ),
                            ),
                            SizedBox(
                              child: IconButton(
                                tooltip: 'Hint',
                                iconSize: 39,
                                icon: Icon(MdiIcons.lightbulb),
                                highlightColor: Colors.transparent,
                                splashColor: Colors.transparent,
                                onPressed: hintStatus
                                    ? () {
                                        int rand = Random()
                                            .nextInt(hintLetters.length);
                                        wordPress(englishAlphabet.alphabet
                                            .indexOf(
                                                wordList[hintLetters[rand]]));
                                        hintStatus = false;
                                      }
                                    : null,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        flex: 6,
                        child: Container(
                          alignment: Alignment.bottomCenter,
                          child: FittedBox(
                            fit: BoxFit.contain,
                            child: Image.asset(
                              'assets/images/h_$hangState.png',
                              height: 1001,
                              width: 991,
                              gaplessPlayback: true,
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 5,
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 35.0),
                          alignment: Alignment.center,
                          child: FittedBox(
                            fit: BoxFit.fitWidth,
                            child: Text(
                              hiddenWord,
                              style: kWordTextStyle,
                            ),
                          ),
                        ),
                      ),
                    ],
                  )),
                  Container(
                    padding: const EdgeInsets.fromLTRB(10.0, 2.0, 8.0, 10.0),
                    child: Column(
                    children: [
                      Row(
                      children: [
                        for (int i = 0; i <= 6; i++)
                        Expanded(child: createButton(i)),
                      ],
                      ),
                      Row(
                      children: [
                        for (int i = 7; i <= 13; i++)
                        Expanded(child: createButton(i)),
                      ],
                      ),
                      Row(
                      children: [
                        for (int i = 14; i <= 20; i++)
                        Expanded(child: createButton(i)),
                      ],
                      ),
                      Row(
                      children: [
                        for (int i = 21; i <= 25; i++)
                        Expanded(child: createButton(i)),

                        // This takes space of TWO cells
                        Expanded( 
                        flex: 2,
                        child: ElevatedButton.icon(
                          onPressed: () {
							Navigator.push(
							  context,
							  MaterialPageRoute(
								builder: (context) => LoadingScreen(),
							  ),
							);
						  },
                          icon: Icon(Icons.remove_red_eye, size: 15),
                          label: Text("Scores"),
                        ),
                        ),
                      ],
                      ),
                    ],
                    ),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}