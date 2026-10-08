import 'package:flutter/material.dart'; 
import 'package:sample_app/games/ludo/ludo_provider.dart';
import 'package:sample_app/games/ludo/widgets/board_widget.dart';
import 'package:sample_app/games/ludo/widgets/dice_widget.dart';
import 'package:provider/provider.dart';

class LudoScreen extends StatefulWidget {
  const LudoScreen({super.key});

  @override
  State<LudoScreen> createState() => _LudoScreenState();
}

class _LudoScreenState extends State<LudoScreen> {
  @override
  void initState() { 
    super.initState();
  }

  @override
  Widget build(BuildContext context) {

   return PopScope(
     canPop: false,
     child: Scaffold(
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
                    "Ludo game",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
					  color:Colors.white,
                    ),
                  ),
				  Spacer(),
				  IconButton(
					icon: Icon(Icons.search),
					onPressed: () {
					},
				  ),
				  IconButton(
					icon: Icon(Icons.more_vert),
					onPressed: () {
					},
				  ),
				  
                ],
              ),
            ),

            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFFF2F2F2),
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                ),

                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(top:40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
					children: [
					  const Column(
						mainAxisSize: MainAxisSize.min,
						crossAxisAlignment: CrossAxisAlignment.center,
						children: [
						  BoardWidget(),
						  Center(child: SizedBox(width: 50, height: 50, child: DiceWidget())),
						],
					  ),
					  Consumer<LudoProvider>(
						builder: (context, value, child) => value.winners.length == 3
							? Container(
								color: Colors.black.withOpacity(0.8),
								child: Center(
								  child: Column(
									mainAxisSize: MainAxisSize.min,
									children: [
									  Image.asset("assets/images/thankyou.gif"),
									  const Text("Thank you for playing 😙", style: TextStyle(color: Colors.white, fontSize: 20), textAlign: TextAlign.center),
									  Text("The Winners is: ${value.winners.map((e) => e.name.toUpperCase()).join(", ")}", style: const TextStyle(color: Colors.white, fontSize: 30), textAlign: TextAlign.center),
									  const Divider(color: Colors.white),
									  const Text("This game made with Flutter ❤️ by Mochamad Nizwar Syafuan", style: TextStyle(color: Colors.white, fontSize: 15), textAlign: TextAlign.center),
									  const SizedBox(height: 20),
									  const Text("Refresh your browser to play again", style: TextStyle(color: Colors.white, fontSize: 10), textAlign: TextAlign.center),
									],
								  ),
								),
							  )
							: const SizedBox.shrink(),
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
