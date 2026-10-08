import 'package:flutter/material.dart';
import 'package:sample_app/games/dice/features/ui/screens/dice_screen.dart';
import 'package:sample_app/games/utilities/hangman_words.dart';
import 'package:sample_app/widget/featured_card.dart';
import 'package:sample_app/widget/feature_middle_card.dart';
import 'package:sample_app/widget/featured_card_sliver.dart';
import 'package:sample_app/widget/small_feature_card.dart';
import 'package:sample_app/games/ludo/ludo_screen.dart';
import 'package:provider/provider.dart';
import 'game_screen.dart';


class AppGameScreen extends StatefulWidget {
  final VoidCallback toggleDrawer;
  final AnimationController animation;
  final HangmanWords hangmanWords = HangmanWords();

  AppGameScreen({
    super.key,
    required this.toggleDrawer,
    required this.animation,
  });

  @override
  AppGameScreenState createState() => AppGameScreenState();
}

class AppGameScreenState extends State<AppGameScreen> {

  @override
  Widget build(BuildContext context) {
    double height = MediaQuery.of(context).size.height;
    widget.hangmanWords.readWords();

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
					IconButton(
					  onPressed: widget.toggleDrawer,
					  icon: AnimatedIcon(
						icon: AnimatedIcons.menu_arrow,
						progress: widget.animation,
						color: Colors.white,
					  ),
					),
                  SizedBox(width: 10),
                  Text(
                    "System games",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
					  color:Colors.white,
                    ),
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
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
						
                      const SizedBox(height: 12),
                      FeaturedCard(
                        image: "assets/images/ludo.jpg",
                        title: "Featured Feature",
                        subtitle: "This is a feature coming soon",
                        emoji: "🔥",
                        borderColor: Colors.blue,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => LudoScreen(),
                            ),
                          );
                        },
                      ),
					  
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 232,
                        child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          SmallFeatureCard(
                            title: "Feature March",
                            image: "assets/images/ad_card2.png",
                            badge: "NEW",
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => DiceScreen(),
                                ),
                              );
                            },
                          ),
                          SmallFeatureCard(
                          title: "Newbie Task",
                          image: "assets/images/ad_card3.png",
                          badge: "HOT",
                          onTap: () {},
                          ),
                          SmallFeatureCard(
                          title: "Voucher Claim",
                          image: "assets/images/ad_card4.png",
                          onTap: () {},
                          ),
                        ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      Row(
                        children: [
                          Expanded(
                            child: FeatureMiddleCard(
							  title: "Feature March",
							  image: "assets/images/ludo.jpg",
							  badge: "NEW",
							  onTap: () {},
							),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: FeatureMiddleCard(
							  title: "Feature Tournament",
							  image: "assets/images/hangman.jpg",
							  badge: "HOT",
							  onTap: () {},
							),
                          ),
                        ],
                      ),

                      const SizedBox(height: 25),
                      
                      FeaturedCardSliver(
                        image: "assets/images/hangman.jpg",
                        title: "Featured Feature",
                        subtitle: "This is a feature coming soon",
                        heroTag: "feature_1",
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
								builder: (context) => GameScreen(
								  hangmanObject: widget.hangmanWords,
								),
                            ),
                          );
                        },
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