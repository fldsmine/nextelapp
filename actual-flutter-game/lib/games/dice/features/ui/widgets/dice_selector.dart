import 'package:flutter/material.dart';

class DiceSelector extends StatelessWidget {
  final int selected;
  final Function(int) onSelect;

  const DiceSelector({super.key, required this.selected, required this.onSelect});

	Widget build(BuildContext context) {
	  Widget buildItem(int value) {
		bool isSelected = selected == value;

		return GestureDetector(
		  onTap: () => onSelect(value),
		  child: AnimatedContainer(
			duration: const Duration(milliseconds: 300),
			padding: const EdgeInsets.all(4),
			decoration: BoxDecoration(
			  color: isSelected
				  ? Colors.orange.withOpacity(0.2)
				  : Colors.white.withOpacity(0.05),
			  borderRadius: BorderRadius.circular(12),
			  border: Border.all(
				color: isSelected ? Colors.orange : Colors.white24,
			  ),
			  boxShadow: isSelected
				  ? [
					  BoxShadow(
						color: Colors.orange.withOpacity(0.6),
						blurRadius: 20,
					  )
					]
				  : [],
			),
			child: Image.asset(
			  'assets/images/dice_$value.png',
			  height: 45,
			),
		  ),
		);
	  }

	  return Column(
		mainAxisSize: MainAxisSize.min,
		children: [
		  // First row (1–4)
		  Row(
			mainAxisAlignment: MainAxisAlignment.spaceBetween,
			children: List.generate(4, (index) => buildItem(index + 1)),
		  ),

		  const SizedBox(height: 12),

		  // Second row (5 left, 6 right)
		  Row(
			mainAxisAlignment: MainAxisAlignment.spaceBetween,
			children: [
			  buildItem(5),
			  
				const SizedBox(width: 20),
				
				Expanded( 
				flex: 2,
				child: ElevatedButton.icon(
				  onPressed: () {
				  },
				  icon: Icon(Icons.wallet, size: 15),
				  label: Text("Fund wallet"),
				),
				),
				
				const SizedBox(width: 20),
			  
			  buildItem(6),
			],
		  ),
		],
	  );
	}
}