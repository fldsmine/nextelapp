import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

import 'package:nextel_connect/games/dice/core/constants/app_constants.dart';
import 'package:nextel_connect/games/dice/core/utils/sound_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/game_state.dart';
import '../data/bet_strategy.dart';
import '../data/game_history.dart';

class GameController extends ChangeNotifier {
  final Random _random = Random();
  static const String historyKey = 'game_history';
  static const String legacyHistoryKey = 'games.dice.history.v1';

  GameState _state = GameState(
    balance: 500000,
    selectedDice: 1,
    rolledDice: 1,
    betAmount: 100,
    isRolling: false,
    isFirstRoll: true,
  );

	GameController() {
	  _loadHistory();
	}

  GameState get state => _state;

  bool isWin = false;

  /// 🎰 Auto Play
  bool isAutoPlaying = false;
  BetStrategy strategy = BetStrategy(
    type: BetStrategyType.manual,
    baseBet: 100,
  );

  int _currentRound = 0;
  double _currentBet = 100;

  /// 🧾 History
  final List<GameHistory> _history = [];
  List<GameHistory> get history => List.unmodifiable(_history);

  /// =========================
  /// 🎯 USER ACTIONS
  /// =========================

  void selectDice(int value) {
    if (_state.isRolling) return;

    SoundManager.click();

    _state = _state.copyWith(selectedDice: value);
    notifyListeners();
  }

  void setBet(double value) {
    if (_state.isRolling || isAutoPlaying) return;

    _state = _state.copyWith(betAmount: value);
    notifyListeners();
  }

  void setStrategy(BetStrategy newStrategy) {
    strategy = newStrategy;
    _currentBet = strategy.baseBet;
    notifyListeners();
  }

  /// =========================
  /// 🎲 SINGLE ROLL
  /// =========================

  Future<void> rollDice([bool? isBool]) async {
    _updateState(isFirstRoll: isBool);

    if (_state.isRolling) return;

    if (_state.betAmount <= 0 ||
        _state.betAmount > _state.balance) {
      return;
    }

    isWin = false;

    _updateState(isRolling: true);

    SoundManager.roll();

    for (int i = 0; i < 10; i++) {
      await Future.delayed(const Duration(milliseconds: 80));

      _updateState(
        rolledDice: _random.nextInt(6) + 1,
      );
    }

    SoundManager.stop();

    final result = _random.nextInt(6) + 1;

    final win = result == _state.selectedDice;

    double newBalance = _state.balance;
    double resultAmount;

    if (win) {
      resultAmount =
          _state.betAmount * AppConstants.winMultiplier;

      newBalance += resultAmount;

      SoundManager.win();
    } else {
      resultAmount = -_state.betAmount;

      newBalance -= _state.betAmount;

      SoundManager.lose();
    }

    isWin = win;

    _addHistory(result, resultAmount, win);

    _updateState(
      rolledDice: result,
      balance: newBalance,
      isRolling: false,
    );
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final currentData = prefs.getString(historyKey);
    final legacyData = prefs.getString(legacyHistoryKey);

    for (final data in [currentData, legacyData]) {
      if (data == null || data.isEmpty) continue;
      try {
        final decoded = GameHistory.decode(data);
        _history
          ..clear()
          ..addAll(decoded.take(100));
        if (data == legacyData && (currentData == null || currentData.isEmpty)) {
          await _saveHistory();
        }
        notifyListeners();
        return;
      } on FormatException {
        // Try the legacy payload if the current local copy is malformed.
      } on TypeError {
        // Ignore malformed older records without blocking the Dice screen.
      }
    }
  }

	Future<void> _saveHistory() async {
	  final prefs = await SharedPreferences.getInstance();
	  await prefs.setString(
		historyKey,
		GameHistory.encode(_history),
	  );
	}

  /// =========================
  /// 🎰 AUTO PLAY ENGINE
  /// =========================

	Future<void> startAutoPlay() async {
    _updateState(isFirstRoll: false);
	  if (isAutoPlaying) return;

	  isAutoPlaying = true;

	  _currentRound = 0;

	  // ✅ Use user's current bet as base
	  _currentBet = _state.betAmount;

	  strategy = BetStrategy(
		type: strategy.type,
		baseBet: _currentBet,
		multiplier: strategy.multiplier,
		maxRounds: strategy.maxRounds,
	  );

	  notifyListeners();

	  while (isAutoPlaying &&
		  _currentRound < strategy.maxRounds) {
		_currentRound++;

		// 🔥 Update UI with current bet
		_updateState(betAmount: _currentBet);

		await rollDice();

		await Future.delayed(const Duration(milliseconds: 500));

		_applyStrategy();

		if (_state.balance <= 0 ||
			_currentBet > _state.balance) {
		  stopAutoPlay();
		}
	  }

	  stopAutoPlay();
	}

  void stopAutoPlay() {
    isAutoPlaying = false;
    notifyListeners();
  }

  /// =========================
  /// 📊 STRATEGY LOGIC
  /// =========================

  void _applyStrategy() {
    switch (strategy.type) {
      case BetStrategyType.martingale:
        if (isWin) {
          _currentBet = strategy.baseBet;
        } else {
          _currentBet *= strategy.multiplier;
        }
        break;

      case BetStrategyType.fixed:
        _currentBet = strategy.baseBet;
        break;

      case BetStrategyType.manual:
        break;
    }
  }

  /// =========================
  /// 🧾 HISTORY TRACKING
  /// =========================
	void _addHistory(int rolled, double result, bool win) {
	  _history.insert(
		0,
		GameHistory(
		  rolledDice: rolled,
		  selectedDice: _state.selectedDice,
		  betAmount: _state.betAmount,
		  resultAmount: result,
		  isWin: win,
		  timestamp: DateTime.now(),
		),
	  );

	  if (_history.length > 100) {
		_history.removeLast();
	  }

	  _saveHistory(); // 🔥 persist
	}

  /// =========================
  /// 🧹 HELPERS
  /// =========================

  void _updateState({
    double? balance,
    int? selectedDice,
    int? rolledDice,
    double? betAmount,
    bool? isRolling,
    bool? isFirstRoll,
  }) {
    _state = _state.copyWith(
      balance: balance,
      selectedDice: selectedDice,
      rolledDice: rolledDice,
      betAmount: betAmount,
      isRolling: isRolling,
      isFirstRoll: isFirstRoll,
    );

    notifyListeners();
  }
}
