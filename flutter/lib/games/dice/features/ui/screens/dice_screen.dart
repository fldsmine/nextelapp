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
import 'package:nextel_connect/games/widgets/bottom_help_sheet.dart';
import 'package:nextel_connect/games/utilities/game_exit_confirmation.dart';
import '../widgets/history_panel.dart';
import '../widgets/strategy_selector.dart';
import '../widgets/stats_dashboard.dart';
import 'package:nextel_connect/games/components/action_button.dart';

const String _howToUse = '1. Choose one of the six dice faces.\n2. Enter a stake greater than zero and no higher than your balance.\n3. Roll: matching your chosen face adds 5× your stake; a miss deducts the stake.\n4. Use Auto Play for up to ten rounds with Manual, Fixed or Martingale strategy.';

class DiceScreen extends StatefulWidget {
  const DiceScreen({super.key});

  @override
  State<DiceScreen> createState() => _DiceScreenState();
}

class _DiceScreenState extends State<DiceScreen> {
  late ConfettiController _confettiController;
  final TextEditingController _betController = TextEditingController();

  double _lastBetValue = 0;
  bool _allowPop = false;
  bool _confirmingExit = false;

  Future<void> _requestExit() async {
    if (_confirmingExit) return;
    _confirmingExit = true;
    final shouldExit = await confirmGameExit(context);
    _confirmingExit = false;
    if (!shouldExit || !mounted) return;

    setState(() => _allowPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).maybePop();
    });
  }

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


   return PopScope<void>(
     canPop: _allowPop,
     onPopInvokedWithResult: (didPop, result) {
       if (!didPop) _requestExit();
     },
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
						onPressed: _requestExit,
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
					icon: const Icon(Icons.help),
					onPressed: () => showDevBottomSheet(
					  context,
					  title: const Text('HOW TO PLAY'),
					  content: const Text(_howToUse),
					),
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
