import 'package:flutter/material.dart';

class PlayButton extends StatelessWidget {
  final VoidCallback onTap;
  final bool loading;

  const PlayButton({super.key, required this.onTap, required this.loading});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Colors.orange, Colors.deepOrange],
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.orange.withOpacity(0.7),
              blurRadius: 20,
            )
          ],
        ),

		child: Center(
		  child: SizedBox(
			height: 24,
			child: Stack(
			  alignment: Alignment.center,
			  children: [
				Opacity(
				  opacity: loading ? 0 : 1,
				  child: const Text(
					"PLAY NOW",
					style: TextStyle(
					  fontWeight: FontWeight.bold,
					  fontSize: 16,
					),
				  ),
				),
				if (loading)
				  const SizedBox(
					height: 20,
					width: 20,
					child: CircularProgressIndicator(
					  color: Colors.white,
					  strokeWidth: 2,
					),
				  ),
			  ],
			),
		  ),
		),
      ),
    );
  }
}
