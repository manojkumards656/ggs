import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../domain/models/youknow_card.dart';

class WildColorDialog extends StatelessWidget {
  const WildColorDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1E1E2C),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Select Wild Color',
              style: GoogleFonts.outfit(
                textStyle: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Choose the color for the next player to match.',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                textStyle: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Quadrant layout for colors
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              children: [
                _buildColorButton(context, YouKnowColor.red, const Color(0xFFE53935)),
                _buildColorButton(context, YouKnowColor.blue, const Color(0xFF1E88E5)),
                _buildColorButton(context, YouKnowColor.green, const Color(0xFF43A047)),
                _buildColorButton(context, YouKnowColor.yellow, const Color(0xFFFFB300)),
              ],
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    ).animate().scale(duration: 300.ms, curve: Curves.easeOutBack).fade();
  }

  Widget _buildColorButton(BuildContext context, YouKnowColor youKnowColor, Color color) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).pop(youKnowColor);
      },
      child: Container(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: Text(
            youKnowColor.displayName.toUpperCase(),
            style: GoogleFonts.outfit(
              textStyle: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 16,
                letterSpacing: 1.0,
                shadows: [
                  Shadow(
                    color: Colors.black26,
                    blurRadius: 4,
                  )
                ],
              ),
            ),
          ),
        ),
      ).animate(onPlay: (controller) => controller.repeat(reverse: true)).shimmer(
            delay: 1000.ms,
            duration: 1500.ms,
            color: Colors.white24,
          ),
    );
  }
}
