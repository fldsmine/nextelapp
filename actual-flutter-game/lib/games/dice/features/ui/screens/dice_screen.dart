import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:confetti/confetti.dart';

import '../../logic/game_controller.dart';
import '../widgets/lottie_dice.dart';
import '../widgets/dice_selector.dart';
import '../widgets/balance_card.dart';
import '../widgets/play_button.dart';
import '../widgets/glass_card.dart';
import '../widgets/confetti_widget.dart';
import '../widgets/win_dialog.dart';
import '/views/menu/bottom_dialog.dart';
import '../widgets/history_panel.dart';
import '../widgets/strategy_selector.dart';
import '../widgets/stats_dashboard.dart';
import '/games/components/action_button.dart';

const String _howToUse = "1. Select your dice (D4, D6, D8, D10, D12, D20).\n2. Enter your bet amount.\n3. Press the Play button to roll the dice.\n4. If you roll a 1, you lose your bet. If you roll a 6, you win 5x your bet!\n\nThis is your developer section.\n\nYou can place debug info, logs, API responses,\nor any internal tools here.\n\nExample:\n- App Version: 1.0.0\n- Environment: Development\n- API Status: Connected\n\nAdd anything useful for debugging or testing.";

class DiceScreen extends StatefulWidget {
  const DiceScreen({super.key});
	
  @override
  State<DiceScreen> createState() => _DiceScreenState();
}

class _DiceScreenState extends State<DiceScreen> {
  late ConfettiController _confettiController;
  final TextEditingController _betController = TextEditingController();

  double _lastBetValue = 0;

  @override
  void initState() {
    super.initState();
    _confettiController =
        ConfettiController(duration: const Duration(seconds: 2));
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _betController.dispose();
    super.dispose();
  }

  void _handleResult(GameController controller) {
    final game = controller.state;

    if (!game.isRolling && controller.isWin) {
      _confettiController.play();

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => WinDialog(
          amount: game.betAmount * 5,
        ),
      );
    }
  }

  /// 🔄 Sync bet input safely (prevents cursor jump)
  void _syncBetInput(double betAmount) {
    if (_lastBetValue != betAmount) {
      _betController.text = betAmount.toStringAsFixed(0);
      _betController.selection = TextSelection.fromPosition(
        TextPosition(offset: _betController.text.length),
      );
      _lastBetValue = betAmount;
    }
  }

  @override
  Widget build(BuildContext context) {
	  
    final controller = context.read<GameController>();
    final game = context.watch<GameController>().state;

    // 🔥 Sync auto-play bet updates into UI
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncBetInput(game.betAmount);
    });


   return PopScope(
     canPop: false,
     child: Scaffold(
	    resizeToAvoidBottomInset: false, 
       body: SafeArea(
        child: Column(
          children: [

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
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
                  Text(
                    "Dice Rolling",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
					  color:Colors.white,
                    ),
                  ),
                  Spacer(),
				  IconButton(
					icon: Icon(Icons.help),
					onPressed: () => {
					  showDevBottomSheet(
						context,
						title: const Text("HOW TO PLAY"),
						content: Text(_howToUse),
					  ),
					},
				  ),
                  IconButton(
                    icon: Icon(Icons.settings),
                    onPressed: () {},
                  ),
                ],
              ),
            ),

            Expanded(
              child: Container(
				decoration: const BoxDecoration(
				  gradient: LinearGradient(
					colors: [Color(0xFF2d4b2f), Color(0xFF1A2238)],
					begin: Alignment.topCenter,
					end: Alignment.bottomCenter,
				  ),
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
				),

                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(top:40,left:15,right:15),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
					children: [
					  // 🎉 Confetti Overlay
					  ConfettiWidgetCustom(
						controller: _confettiController,
					  ),
					  Column(
						mainAxisSize: MainAxisSize.min,
						crossAxisAlignment: CrossAxisAlignment.center,
						children: [
						
						  const SizedBox(height: 20),

						  // 🎲 Lottie Dice
						  LottieDice(
							isRolling: game.isRolling,
							finalValue: game.rolledDice,
							isFirstRoll: game.isFirstRoll,
						  ),

						  const SizedBox(height: 15),

						  Row(
							mainAxisAlignment: MainAxisAlignment.center,
							children: [
							  BalanceCard(balance: game.balance),
							  
								const SizedBox(width: 10),
								
							GlassCard(
							  padding: const EdgeInsets.only(left:12, top:2,right:12,bottom:2),
							  borderRadius: BorderRadius.circular(8),
							  border: Border.all(color: Colors.white, width: 1),
							  child: Column(
								crossAxisAlignment: CrossAxisAlignment.start,
								children: [
								  const Text("BET STRATEGY",
								  style: TextStyle(color: Colors.white)),
								  StrategySelector(
									strategy: controller.strategy,
									onChanged: controller.setStrategy,
								  ),
								],
							  ),
							),
								
							],
						  ),

						  const SizedBox(height: 15),

						  // 🎯 Dice Selector
						  GlassCard(
							child: Column(
							  children: [
								const Text(
								  "SELECT YOUR DICE",
								  style: TextStyle(color: Colors.white70),
								),
								const SizedBox(height: 10),
								DiceSelector(
								  selected: game.selectedDice,
								  onSelect: controller.selectDice,
								),
							  ],
							),
						  ),

						  const SizedBox(height: 20),
						
						  /// 💵 Bet Input (SYNCED WITH AUTO PLAY)
						  GlassCard(
							padding: const EdgeInsets.all(10),
							child: TextField(
							  controller: _betController,
							  keyboardType: TextInputType.number,
							  style: const TextStyle(color: Colors.white),
							  onChanged: (val) {
								controller.setBet(
								  double.tryParse(val) ?? 0,
								);
							  },
							  decoration: const InputDecoration(
								hintText: "Enter Bet Amount",
								hintStyle: TextStyle(color: Colors.white54),
								border: InputBorder.none,
							  ),
							),
						  ),

						  const SizedBox(height: 20),

						  // ▶️ Play Button
							Row(
							  children: [
								Expanded(
								  child: PlayButton(
									onTap: () async {
									  await controller.rollDice(false);
									  _handleResult(controller);
									},
									loading: game.isRolling,
								  ),
								),
								const SizedBox(width: 10),
								Expanded(
								  child: ActionButton(
								  buttonTitle: controller.isAutoPlaying ? "STOP AUTO" : "AUTO PLAY",
									onPress: controller.isAutoPlaying
										? controller.stopAutoPlay
										: controller.startAutoPlay,
								  ),
								),
	
							  ],
							),

						  const SizedBox(height: 20),
						  
							StatsDashboard(history: controller.history),
							const SizedBox(height: 20),
							GlassCard(
							  padding: const EdgeInsets.all(10),
							  child: HistoryPanel(history: controller.history),
							),
							const SizedBox(height: 20),

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
    ),
   );
  }
}

void showDevBottomSheet(
  BuildContext context, {
  required Widget title,
  required Widget content,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => BottomHelpSheet(
      title: title,
      content: content,
    ),
  );
}