import 'dart:math';

import 'package:flutter/services.dart' show rootBundle;

class HangmanWords {
  int wordCounter = 0;
  List<int> _usedNumbers = [];
  List<String> _words = [];

  Future<void> readWords() async {
    final fileText = await rootBundle.loadString('assets/res/hangman_words.txt');
    _words = fileText.split('\n');
  }

  void resetWords() {
    wordCounter = 0;
    _usedNumbers = [];
//    _words = [];
  }

  String getWord() {
    wordCounter += 1;
    if (_words.isEmpty || wordCounter - 1 == _words.length) return '';

    final random = Random();
    if (_usedNumbers.length >= _words.length) return '';
    var randomIndex = random.nextInt(_words.length);
    while (_usedNumbers.contains(randomIndex)) {
      randomIndex = random.nextInt(_words.length);
    }
    _usedNumbers.add(randomIndex);
    return _words[randomIndex];
  }

  String getHiddenWord(int wordLength) {
    String hiddenWord = '';
    for (int i = 0; i < wordLength; i++) {
      hiddenWord += '_';
    }
    return hiddenWord;
  }
}
