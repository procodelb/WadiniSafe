import 'package:flutter/material.dart';

class RatingStars extends StatelessWidget {
  final double rating;
  final int starCount;
  final Color color;
  final double size;

  const RatingStars({
    super.key,
    required this.rating,
    this.starCount = 5,
    this.color = const Color(0xFFFFC107), // Amber
    this.size = 20,
  });

  @override
  Widget build(BuildContext context) {
    final fullStars = rating.floor();
    final halfStar = rating - fullStars >= 0.5;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(starCount, (index) {
        if (index < fullStars) {
          return Icon(Icons.star, color: color, size: size);
        } else if (index == fullStars && halfStar) {
          return Icon(Icons.star_half, color: color, size: size);
        } else {
          return Icon(Icons.star_border, color: color, size: size);
        }
      }),
    );
  }
}
