
import 'package:flutter/material.dart';

class OndaClipper extends CustomClipper<Path> {
  final Animation<double> animation;

  OndaClipper({required this.animation})
      : super(reclip: animation);

  @override
  Path getClip(Size size) {
    final progress = animation.value;
    final width = size.width;
    final height = size.height;

    // A água sobe de baixo para cima.
    final surfaceY = height * (1 - progress);

    // Ondas mais visíveis no início e suaves no final.
    final amplitude = 30.0 *
        (1 - progress).clamp(0.0, 1.0);

    final path = Path()
      ..moveTo(0, surfaceY);

    // Primeira onda.
    path.cubicTo(
      width * 0.18,
      surfaceY - amplitude * 1.5,
      width * 0.30,
      surfaceY + amplitude,
      width * 0.50,
      surfaceY,
    );

    // Segunda onda.
    path.cubicTo(
      width * 0.70,
      surfaceY - amplitude,
      width * 0.82,
      surfaceY + amplitude * 1.5,
      width,
      surfaceY,
    );

    // Preenche toda a área abaixo da superfície.
    path
      ..lineTo(width, height)
      ..lineTo(0, height)
      ..close();

    return path;
  }

  @override
  bool shouldReclip(covariant OndaClipper oldClipper) {
    return oldClipper.animation != animation;
  }
}
