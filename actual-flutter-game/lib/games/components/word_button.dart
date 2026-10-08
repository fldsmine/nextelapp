import 'package:flutter/material.dart';
import 'package:sample_app/games/utilities/constants.dart';

class WordButton extends StatelessWidget {
  const WordButton({super.key, required this.buttonTitle, this.onPress,required this.isSelected});

  final VoidCallback? onPress;
  final String buttonTitle;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        elevation: 3.0,
        backgroundColor: isSelected 
			? kWordButtonClicked
			: kWordButtonColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        padding: const EdgeInsets.all(4.0),
      ),
      onPressed: onPress,
      child: Text(
        buttonTitle,
        textAlign: TextAlign.center,
        style: kWordButtonTextStyle,
      ),
    );
  }
}
