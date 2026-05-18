import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class HangmanFigure extends StatelessWidget {
  final int remainingLives;
  final int maxLives;

  const HangmanFigure({
    super.key,
    required this.remainingLives,
    required this.maxLives,
  });

  @override
  Widget build(BuildContext context) {
    int errors = maxLives - remainingLives;
    
    return SizedBox(
      width: 150,
      height: 200,
      child: Stack(
        children: [
          // Gallows (always visible)
          CustomPaint(
            size: const Size(150, 200),
            painter: _GallowsPainter(),
          ),
          
          // Head
          if (errors >= 1)
            Positioned(
              top: 40,
              left: 60,
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 4),
                ),
              ).animate().fadeIn().scale(),
            ),
            
          // Body
          if (errors >= 2)
            Positioned(
              top: 70,
              left: 73,
              child: Container(
                width: 4,
                height: 50,
                color: Colors.white,
              ).animate().fadeIn().moveY(begin: -10, end: 0),
            ),
            
          // Left Arm
          if (errors >= 3)
            Positioned(
              top: 80,
              left: 45,
              child: Transform.rotate(
                angle: 0.5,
                child: Container(
                  width: 40,
                  height: 4,
                  color: Colors.white,
                ),
              ).animate().fadeIn().slideX(begin: 0.5),
            ),
            
          // Right Arm
          if (errors >= 4)
            Positioned(
              top: 80,
              left: 70,
              child: Transform.rotate(
                angle: -0.5,
                child: Container(
                  width: 40,
                  height: 4,
                  color: Colors.white,
                ),
              ).animate().fadeIn().slideX(begin: -0.5),
            ),
            
          // Left Leg
          if (errors >= 5)
            Positioned(
              top: 115,
              left: 55,
              child: Transform.rotate(
                angle: 0.5,
                child: Container(
                  width: 4,
                  height: 40,
                  color: Colors.white,
                ),
              ).animate().fadeIn().slideY(begin: -0.5),
            ),
            
          // Right Leg
          if (errors >= 6)
            Positioned(
              top: 115,
              left: 90,
              child: Transform.rotate(
                angle: -0.5,
                child: Container(
                  width: 4,
                  height: 40,
                  color: Colors.white,
                ),
              ).animate().fadeIn().slideY(begin: -0.5),
            ),
        ],
      ),
    );
  }
}

class _GallowsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white70
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // Base
    canvas.drawLine(Offset(20, size.height), Offset(130, size.height), paint);
    // Pole
    canvas.drawLine(Offset(40, size.height), const Offset(40, 20), paint);
    // Top arm
    canvas.drawLine(const Offset(40, 20), const Offset(75, 20), paint);
    // Rope
    canvas.drawLine(const Offset(75, 20), const Offset(75, 40), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
