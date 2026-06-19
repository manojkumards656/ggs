import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'chess_piece_painter.dart';

class ChessClockWidget extends StatelessWidget {
  final String playerName;
  final int timeRemaining; // in seconds
  final bool isActive;
  final bool isWhite;
  final String boardFen;
  final bool isFlipped;

  const ChessClockWidget({
    super.key,
    required this.playerName,
    required this.timeRemaining,
    required this.isActive,
    required this.isWhite,
    required this.boardFen,
    this.isFlipped = false,
  });

  /// Format time as MM:SS
  String _formatTime(int seconds) {
    if (seconds <= 0) return '00:00';
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  /// Calculates which of the opponent's pieces have been captured, based on FEN
  List<String> _getCapturedOpponentPieces() {
    // We want to count remaining opponent pieces in FEN
    final piecePositionPart = boardFen.split(' ').first;
    
    // Count active pieces
    final activeCounts = <String, int>{
      'p': 0, 'n': 0, 'b': 0, 'r': 0, 'q': 0, // black pieces (lowercase)
      'P': 0, 'N': 0, 'B': 0, 'R': 0, 'Q': 0, // white pieces (uppercase)
    };
    
    for (var i = 0; i < piecePositionPart.length; i++) {
      final char = piecePositionPart[i];
      if (activeCounts.containsKey(char)) {
        activeCounts[char] = activeCounts[char]! + 1;
      }
    }

    final captured = <String>[];
    
    if (isWhite) {
      // Opponent is Black. We count captured Black pieces.
      // Pawns (initial 8)
      final pDiff = 8 - (activeCounts['p'] ?? 0);
      for (var i = 0; i < pDiff; i++) {
        captured.add('p');
      }
      // Knights (initial 2)
      final nDiff = 2 - (activeCounts['n'] ?? 0);
      for (var i = 0; i < nDiff; i++) {
        captured.add('n');
      }
      // Bishops (initial 2)
      final bDiff = 2 - (activeCounts['b'] ?? 0);
      for (var i = 0; i < bDiff; i++) {
        captured.add('b');
      }
      // Rooks (initial 2)
      final rDiff = 2 - (activeCounts['r'] ?? 0);
      for (var i = 0; i < rDiff; i++) {
        captured.add('r');
      }
      // Queens (initial 1)
      final qDiff = 1 - (activeCounts['q'] ?? 0);
      for (var i = 0; i < qDiff; i++) {
        captured.add('q');
      }
    } else {
      // Opponent is White. We count captured White pieces.
      // Pawns (initial 8)
      final pDiff = 8 - (activeCounts['P'] ?? 0);
      for (var i = 0; i < pDiff; i++) {
        captured.add('p');
      }
      // Knights (initial 2)
      final nDiff = 2 - (activeCounts['N'] ?? 0);
      for (var i = 0; i < nDiff; i++) {
        captured.add('n');
      }
      // Bishops (initial 2)
      final bDiff = 2 - (activeCounts['B'] ?? 0);
      for (var i = 0; i < bDiff; i++) {
        captured.add('b');
      }
      // Rooks (initial 2)
      final rDiff = 2 - (activeCounts['R'] ?? 0);
      for (var i = 0; i < rDiff; i++) {
        captured.add('r');
      }
      // Queens (initial 1)
      final qDiff = 1 - (activeCounts['Q'] ?? 0);
      for (var i = 0; i < qDiff; i++) {
        captured.add('q');
      }
    }
    
    // Sort them by piece value to look nice: Queen, Rook, Bishop, Knight, Pawn
    final order = {'q': 0, 'r': 1, 'b': 2, 'n': 3, 'p': 4};
    captured.sort((a, b) => order[a]!.compareTo(order[b]!));
    
    return captured;
  }

  @override
  Widget build(BuildContext context) {
    final isUntimed = timeRemaining <= 0;
    final capturedPieces = _getCapturedOpponentPieces();

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
              if (capturedPieces.isNotEmpty)
                SizedBox(
                  height: 20,
                  child: Row(
                    children: capturedPieces.map((pieceType) {
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
                    }).toList(),
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
