import 'package:flutter/material.dart';

class SmallFeatureCard extends StatelessWidget {
  const SmallFeatureCard({
    required this.title,
    required this.image,
    required this.onTap,
    this.badge,
    super.key,
  });

  final String title;
  final String image;
  final String? badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 164,
      child: Card(
        clipBehavior: Clip.antiAlias,
        margin: const EdgeInsets.only(right: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset(image, fit: BoxFit.cover),
                    if (badge != null)
                      Positioned(
                        top: 10,
                        left: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDCEB6A),
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: Text(
                            badge!,
                            style: const TextStyle(
                              color: Color(0xFF18443E),
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: .5,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
