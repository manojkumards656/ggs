import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'chess_piece_painter.dart';

class ChessClockWidget extends StatelessWidget {
  final String playerName;
  final int timeRemaining; // in seconds
  final bool isActive;
  final bool isWhite;
  final List<String> capturedPieces; // list of captured opponent pieces ('p', 'r', etc.)
  final int materialAdvantage;
  final bool isTimed;
  final bool isFlipped;

  const ChessClockWidget({
    super.key,
    required this.playerName,
    required this.timeRemaining,
    required this.isActive,
    required this.isWhite,
    required this.capturedPieces,
    this.materialAdvantage = 0,
    required this.isTimed,
    this.isFlipped = false,
  });

  /// Format time as MM:SS
  String _formatTime(int seconds) {
    if (seconds <= 0) return '00:00';
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final isUntimed = !isTimed;

    // Pulse effect when active to draw attention without heavy rebuild cost
    Widget clockCard = Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isActive
            ? Theme.of(context).colorScheme.surface.withValues(alpha: 0.9)
            : Theme.of(context).colorScheme.surface.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive
              ? (isWhite ? const Color(0xFFE2E2F0) : const Color(0xFF00F2FE))
              : Colors.white.withValues(alpha: 0.08),
          width: isActive ? 2.0 : 1.0,
        ),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: (isWhite ? const Color(0xFFE2E2F0) : const Color(0xFF00F2FE))
                      .withValues(alpha: 0.25),
                  blurRadius: 10,
                  spreadRadius: 1,
                )
              ]
            : null,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Player info
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isWhite ? Colors.white : const Color(0xFF00F2FE),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    playerName,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              // Captured pieces display
              if (capturedPieces.isNotEmpty || materialAdvantage > 0)
                SizedBox(
                  height: 20,
                  child: Row(
                    children: [
                      ...capturedPieces.map((pieceType) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 2.0),
                          child: Opacity(
                            opacity: 0.65,
                            child: ChessPieceWidget(
                              type: pieceType,
                              color: isWhite ? 'b' : 'w', // opponent's color
                              size: 16,
                            ),
                          ),
                        );
                      }),
                      if (materialAdvantage > 0)
                        Padding(
                          padding: const EdgeInsets.only(left: 4.0),
                          child: Text(
                            '+$materialAdvantage',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isWhite ? Colors.white.withValues(alpha: 0.8) : const Color(0xFF00F2FE).withValues(alpha: 0.8),
                            ),
                          ),
                        ),
                    ],
                  ),
                )
              else
                Text(
                  'No captures',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.4),
                  ),
                ),
            ],
          ),
          // Timer readout
          Text(
            isUntimed ? '∞' : _formatTime(timeRemaining),
            style: TextStyle(
              fontSize: isUntimed ? 26 : 22,
              fontFamily: 'monospace', // equal-width digits for ticking stability
              fontWeight: FontWeight.w700,
              color: isUntimed
                  ? Colors.white.withValues(alpha: 0.6)
                  : (isActive
                      ? (isWhite ? Colors.white : const Color(0xFF00F2FE))
                      : Colors.white.withValues(alpha: 0.6)),
            ),
          ),
        ],
      ),
    );

    // Apply shimmer or gentle pulse to active timer card
    if (isActive && !isUntimed) {
      clockCard = clockCard
          .animate(onPlay: (controller) => controller.repeat(reverse: true))
          .shimmer(
            duration: 2000.ms,
            color: (isWhite ? Colors.white : const Color(0xFF00F2FE)).withValues(alpha: 0.05),
          );
    }

    return RotatedBox(
      quarterTurns: isFlipped ? 2 : 0,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: clockCard,
      ),
    );
  }
}
