import 'package:flutter/material.dart';

class FeaturedCardSliver extends StatelessWidget {
  const FeaturedCardSliver({
    required this.image,
    required this.title,
    required this.subtitle,
    required this.heroTag,
    required this.onTap,
    super.key,
  });

  final String image;
  final String title;
  final String subtitle;
  final String heroTag;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: heroTag,
      child: SizedBox(
        height: 178,
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(image, fit: BoxFit.cover),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.center,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Color(0xE0000000)],
                    ),
                  ),
                ),
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 16,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ],
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
