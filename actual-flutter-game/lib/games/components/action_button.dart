import 'package:flutter/material.dart';
import 'package:sample_app/games/utilities/constants.dart';

class ActionButton extends StatelessWidget {
  const ActionButton({super.key, required this.buttonTitle, this.onPress});

  final VoidCallback? onPress;
  final String buttonTitle;

  @override
  Widget build(BuildContext context) {

      return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: onPress,
          style: ElevatedButton.styleFrom(
            padding: EdgeInsets.zero,
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
          ),
          child: Ink(
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [Colors.orange, Colors.deepOrange]),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.orange.withOpacity(0.7),
                  blurRadius: 20,
                )
              ],
            ),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 18, vertical: 15),
              alignment: Alignment.center, // 👈 centers text
              child: Text(buttonTitle, style: kActionButtonTextStyle),
            ),
          ),
        ),
      );
  }
}
