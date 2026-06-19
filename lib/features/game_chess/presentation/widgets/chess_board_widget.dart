import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'chess_piece_painter.dart';

class ChessBoardWidget extends StatelessWidget {
  final String boardFen;
  final String? selectedSquare;
  final List<String> validMoves;
  final String? lastMoveFrom;
  final String? lastMoveTo;
  final bool isCheck;
  final bool isFlipped;
  final String activeColor; // 'w' or 'b'
  final bool rotateOpponentPieces;
  final Function(String square) onSquareTap;

  const ChessBoardWidget({
    super.key,
    required this.boardFen,
    this.selectedSquare,
    required this.validMoves,
    this.lastMoveFrom,
    this.lastMoveTo,
    required this.isCheck,
    required this.isFlipped,
    required this.activeColor,
    required this.rotateOpponentPieces,
    required this.onSquareTap,
  });

  /// Parse the FEN string to get piece locations
  Map<String, Map<String, String>> _parseFen(String fen) {
    final board = <String, Map<String, String>>{};
    final parts = fen.split(' ');
    if (parts.isEmpty) return board;

    final ranks = parts[0].split('/');
    for (int r = 0; r < 8; r++) {
      final rankNum = 8 - r;
      final rankStr = ranks[r];
      int fileIndex = 0;

      for (int i = 0; i < rankStr.length; i++) {
        final char = rankStr[i];
        final emptyCount = int.tryParse(char);

        if (emptyCount != null) {
          fileIndex += emptyCount;
        } else {
          final fileChar = String.fromCharCode('a'.codeUnitAt(0) + fileIndex);
          final square = '$fileChar$rankNum';

          final isWhite = char == char.toUpperCase();
          final type = char.toLowerCase();
          board[square] = {
            'type': type,
            'color': isWhite ? 'w' : 'b',
          };
          fileIndex++;
        }
      }
    }
    return board;
  }

  @override
  Widget build(BuildContext context) {
    final board = _parseFen(boardFen);

    // Grid visual ordering of squares
    final List<String> squaresOrder = [];
    for (int rankIndex = 0; rankIndex < 8; rankIndex++) {
      for (int fileIndex = 0; fileIndex < 8; fileIndex++) {
        final r = isFlipped ? (rankIndex + 1) : (8 - rankIndex);
        final f = isFlipped ? (8 - fileIndex) : (fileIndex + 1);
        final fileChar = String.fromCharCode('a'.codeUnitAt(0) + f - 1);
        squaresOrder.add('$fileChar$r');
      }
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        // Board is a square, so height = width
        final cellSize = width / 8;

        return Container(
          width: width,
          height: width,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.1),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              )
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              // 8x8 Grid of Squares
              GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                itemCount: 64,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 8,
                ),
                itemBuilder: (context, index) {
                  final square = squaresOrder[index];
                  
                  // Compute rank & file indices relative to visual grid
                  final visualRow = index ~/ 8;
                  final visualCol = index % 8;
                  
                  // Coordinate indices for chess grid coloring
                  final r = isFlipped ? (visualRow + 1) : (8 - visualRow);
                  final f = isFlipped ? (8 - visualCol) : (visualCol + 1);
                  final isLight = (r + f) % 2 == 1;

                  // 1. Base cell decoration
                  final cellColor = isLight
                      ? const Color(0xFFE2E2F0).withValues(alpha: 0.22)
                      : const Color(0xFF070515).withValues(alpha: 0.85);

                  // 2. Cell states
                  final isSelected = square == selectedSquare;
                  final isLastMove = square == lastMoveFrom || square == lastMoveTo;
                  final isValidMove = validMoves.contains(square);
                  final hasPieceOnSquare = board.containsKey(square);

                  // 3. Check status
                  final piece = board[square];
                  final isKingInCheck = isCheck &&
                      piece != null &&
                      piece['type'] == 'k' &&
                      piece['color'] == activeColor;

                  return GestureDetector(
                    onTap: () => onSquareTap(square),
                    child: Stack(
                      children: [
                        // Standard cell background
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          decoration: BoxDecoration(
                            color: cellColor,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.03),
                              width: 0.5,
                            ),
                          ),
                        ),

                        // Last move highlight
                        if (isLastMove)
                          Container(
                            color: const Color(0xFFFFD700).withValues(alpha: 0.12),
                          ),

                        // King in check highlight (red pulsing overlay)
                        if (isKingInCheck)
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.25),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.red.withValues(alpha: 0.35),
                                  blurRadius: 8,
                                  spreadRadius: 1,
                                )
                              ],
                            ),
                          )
                              .animate(onPlay: (c) => c.repeat(reverse: true))
                              .fade(duration: 800.ms, begin: 0.4, end: 1.0),

                        // Selected square glow
                        if (isSelected)
                          Container(
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: activeColor == 'w'
                                    ? Colors.white
                                    : const Color(0xFF00F2FE),
                                width: 2.0,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: (activeColor == 'w'
                                          ? Colors.white
                                          : const Color(0xFF00F2FE))
                                      .withValues(alpha: 0.3),
                                  blurRadius: 6,
                                )
                              ],
                            ),
                          ),

                        // Piece display
                        if (piece != null)
                          Center(
                            child: rotateOpponentPieces && piece['color'] != (isFlipped ? 'b' : 'w')
                                ? RotatedBox(
                                    quarterTurns: 2,
                                    child: ChessPieceWidget(
                                      type: piece['type']!,
                                      color: piece['color']!,
                                      size: cellSize * 0.85,
                                      isSelected: isSelected,
                                    ),
                                  )
                                : ChessPieceWidget(
                                    type: piece['type']!,
                                    color: piece['color']!,
                                    size: cellSize * 0.85,
                                    isSelected: isSelected,
                                  ),
                          ),

                        // Valid Move indicator
                        if (isValidMove)
                          Center(
                            child: hasPieceOnSquare
                                // Glowing capturing ring
                                ? Container(
                                    width: cellSize * 0.72,
                                    height: cellSize * 0.72,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.redAccent.withValues(alpha: 0.8),
                                        width: 3,
                                      ),
                                    ),
                                  )
                                // Standard empty target dot
                                : Container(
                                    width: cellSize * 0.25,
                                    height: cellSize * 0.25,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: const Color(0xFF00F2FE).withValues(alpha: 0.6),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFF00F2FE).withValues(alpha: 0.3),
                                          blurRadius: 4,
                                        )
                                      ],
                                    ),
                                  ),
                          ),

                        // Coordinates labels (Ranks 1-8 on left-most column, Files a-h on bottom-most row)
                        if (visualCol == 0)
                          Positioned(
                            top: 2,
                            left: 4,
                            child: Text(
                              r.toString(),
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: Colors.white.withValues(alpha: 0.35),
                              ),
                            ),
                          ),
                        if (visualRow == 7)
                          Positioned(
                            bottom: 2,
                            right: 4,
                            child: Text(
                              String.fromCharCode('a'.codeUnitAt(0) + f - 1),
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: Colors.white.withValues(alpha: 0.35),
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
