import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../domain/models/youknow_card.dart';

class YouKnowCardWidget extends StatelessWidget {
  final YouKnowCard card;
  final bool faceUp;
  final bool isPlayable;
  final double width;
  final double height;
  final VoidCallback? onTap;

  const YouKnowCardWidget({
    super.key,
    required this.card,
    this.faceUp = true,
    this.isPlayable = false,
    this.width = 100,
    this.height = 150,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Widget cardBody;

    if (!faceUp) {
      cardBody = _buildCardBack();
    } else {
      cardBody = _buildCardFace();
    }

    Widget content = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: isPlayable ? 12 : 6,
            spreadRadius: isPlayable ? 2 : 0,
            offset: const Offset(0, 4),
          ),
          if (isPlayable)
            BoxShadow(
              color: card.color == YouKnowColor.wild
                  ? Colors.purpleAccent.withValues(alpha: 0.5)
                  : card.color.colorValue.withValues(alpha: 0.6),
              blurRadius: 16,
              spreadRadius: 3,
            )
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: cardBody,
      ),
    );

    // Apply interactive animations if playable
    if (isPlayable) {
      content = content
          .animate(onPlay: (controller) => controller.repeat(reverse: true))
          .scaleXY(
            begin: 1.0,
            end: 1.03,
            duration: 1200.ms,
            curve: Curves.easeInOut,
          );
    }

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: content,
      );
    }

    return content;
  }

  // ── Renders the Back of the Card ──
  Widget _buildCardBack() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Inner decorative ring
          Container(
            width: width * 0.75,
            height: height * 0.75,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFFFFB300).withValues(alpha: 0.2),
                width: 2,
              ),
            ),
          ),
          // Inner oval
          Transform.rotate(
            angle: -15 * pi / 180,
            child: Container(
              width: width * 0.8,
              height: height * 0.4,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.all(Radius.elliptical(width * 0.8, height * 0.4)),
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF8F00), Color(0xFFFF5722)],
                ),
              ),
            ),
          ),
          // "YouKnow" Text
          Text(
            'YOU\nKNOW',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              textStyle: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: width * 0.16,
                letterSpacing: 1.2,
                height: 1.0,
                shadows: [
                  Shadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: 4,
                    offset: const Offset(2, 2),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Renders the Face of the Card ──
  Widget _buildCardFace() {
    final themeColor = card.color.colorValue;
    final isWild = card.isWild;

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: themeColor, width: width * 0.08),
        borderRadius: BorderRadius.circular(16),
        color: Colors.white,
      ),
      child: Stack(
        children: [
          // Inner Slanted Oval
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.all(width * 0.06),
              child: Transform.rotate(
                angle: -15 * pi / 180,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.all(
                      Radius.elliptical(width * 0.8, height * 0.5),
                    ),
                    color: themeColor,
                  ),
                  child: isWild ? _buildWildFaceCenterBackground() : null,
                ),
              ),
            ),
          ),

          // Top Left Small Corner Value
          Positioned(
            top: 4,
            left: 6,
            child: _buildCornerSymbol(card.value, themeColor),
          ),

          // Bottom Right Small Corner Value
          Positioned(
            bottom: 4,
            right: 6,
            child: Transform.rotate(
              angle: pi,
              child: _buildCornerSymbol(card.value, themeColor),
            ),
          ),

          // Large Center Icon / Symbol
          Center(
            child: _buildCenterSymbol(card.value),
          ),
        ],
      ),
    );
  }

  // Helper to draw wild quad-color background in the center oval
  Widget _buildWildFaceCenterBackground() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(40),
      child: CustomPaint(
        painter: _WildCardOvalPainter(),
      ),
    );
  }

  // Corner symbol builder
  Widget _buildCornerSymbol(YouKnowValue value, Color color) {
    if (value.isAction) {
      IconData icon;
      switch (value) {
        case YouKnowValue.skip:
          icon = Icons.block;
          break;
        case YouKnowValue.reverse:
          icon = Icons.repeat;
          break;
        case YouKnowValue.drawTwo:
          return Text(
            '+2',
            style: GoogleFonts.outfit(
              textStyle: TextStyle(
                color: color,
                fontWeight: FontWeight.w900,
                fontSize: width * 0.14,
              ),
            ),
          );
        case YouKnowValue.wild:
          return Container(
            width: width * 0.12,
            height: width * 0.12,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: SweepGradient(
                colors: [Colors.red, Colors.blue, Colors.green, Colors.yellow, Colors.red],
              ),
            ),
          );
        case YouKnowValue.wildDrawFour:
          return Text(
            '+4',
            style: GoogleFonts.outfit(
              textStyle: const TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w900,
                fontSize: 12,
              ),
            ),
          );
        default:
          icon = Icons.star;
      }
      return Icon(icon, color: color, size: width * 0.14);
    } else {
      return Text(
        value.displayName,
        style: GoogleFonts.outfit(
          textStyle: TextStyle(
            color: color,
            fontWeight: FontWeight.w900,
            fontSize: width * 0.16,
          ),
        ),
      );
    }
  }

  // Center symbol builder
  Widget _buildCenterSymbol(YouKnowValue value) {
    final double centerSize = width * 0.45;
    final shadow = [
      Shadow(
        color: Colors.black.withValues(alpha: 0.3),
        blurRadius: 3,
        offset: const Offset(1, 2),
      )
    ];

    if (value.isAction) {
      switch (value) {
        case YouKnowValue.skip:
          return Icon(
            Icons.block,
            color: Colors.white,
            size: centerSize,
            shadows: shadow,
          );
        case YouKnowValue.reverse:
          return Icon(
            Icons.repeat,
            color: Colors.white,
            size: centerSize,
            shadows: shadow,
          );
        case YouKnowValue.drawTwo:
          return Text(
            '+2',
            style: GoogleFonts.outfit(
              textStyle: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: width * 0.3,
                shadows: shadow,
              ),
            ),
          );
        case YouKnowValue.wild:
          // Large wild color wheel
          return Container(
            width: width * 0.45,
            height: width * 0.45,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                )
              ],
              gradient: const SweepGradient(
                colors: [
                  Color(0xFFE53935), // Red
                  Color(0xFF1E88E5), // Blue
                  Color(0xFF43A047), // Green
                  Color(0xFFFFB300), // Yellow
                  Color(0xFFE53935),
                ],
              ),
            ),
          );
        case YouKnowValue.wildDrawFour:
          return Stack(
            alignment: Alignment.center,
            children: [
              // 4-color wheel
              Container(
                width: width * 0.45,
                height: width * 0.45,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                  gradient: const SweepGradient(
                    colors: [
                      Color(0xFFE53935),
                      Color(0xFF1E88E5),
                      Color(0xFF43A047),
                      Color(0xFFFFB300),
                      Color(0xFFE53935),
                    ],
                  ),
                ),
              ),
              // Overlay text "+4"
              Text(
                '+4',
                style: GoogleFonts.outfit(
                  textStyle: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: width * 0.22,
                    shadows: [
                      Shadow(
                        color: Colors.black.withValues(alpha: 0.6),
                        blurRadius: 4,
                      )
                    ],
                  ),
                ),
              ),
            ],
          );
        default:
          return const SizedBox.shrink();
      }
    } else {
      // Normal Number
      return Text(
        value.displayName,
        style: GoogleFonts.outfit(
          textStyle: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: width * 0.42,
            shadows: shadow,
          ),
        ),
      );
    }
  }
}

// Custom Painter to draw Red, Blue, Green, Yellow sections in the wild oval background
class _WildCardOvalPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final paint = Paint()..style = PaintingStyle.fill;
    final center = Offset(size.width / 2, size.height / 2);

    // Draw the 4 slices
    // Arc drawing angles in radians: Red (top-left), Blue (top-right), Green (bottom-right), Yellow (bottom-left)
    // To align with a tilted oval, we draw 4 segments.
    // Red: 180 to 270 degrees
    paint.color = const Color(0xFFE53935);
    canvas.drawArc(rect, pi, pi / 2, true, paint);

    // Blue: 270 to 360/0 degrees
    paint.color = const Color(0xFF1E88E5);
    canvas.drawArc(rect, 1.5 * pi, pi / 2, true, paint);

    // Green: 0 to 90 degrees
    paint.color = const Color(0xFF43A047);
    canvas.drawArc(rect, 0, pi / 2, true, paint);

    // Yellow: 90 to 180 degrees
    paint.color = const Color(0xFFFFB300);
    canvas.drawArc(rect, 0.5 * pi, pi / 2, true, paint);

    // Draw white center border divider
    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawLine(Offset(0, center.dy), Offset(size.width, center.dy), linePaint);
    canvas.drawLine(Offset(center.dx, 0), Offset(center.dx, size.height), linePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
