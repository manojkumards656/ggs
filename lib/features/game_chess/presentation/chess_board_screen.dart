import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/providers/chess_providers.dart';

class ChessBoardScreen extends ConsumerStatefulWidget {
  const ChessBoardScreen({super.key});

  @override
  ConsumerState<ChessBoardScreen> createState() => _ChessBoardScreenState();
}

class _ChessBoardScreenState extends ConsumerState<ChessBoardScreen> {
  ChessPosition? _selectedPosition;

  void _onSquareTapped(ChessPosition position, ChessGameState state) {
    if (_selectedPosition != null) {
      if (_selectedPosition == position) {
        // Tapped same piece, deselect
        setState(() {
          _selectedPosition = null;
        });
        return;
      }
      
      // Attempt move
      final moveAction = ref.read(chessMoveActionProvider);
      moveAction(_selectedPosition!, position);
      
      setState(() {
        _selectedPosition = null;
      });
    } else {
      // Select a piece if it belongs to the current player
      final piece = state.board[position];
      if (piece != null && piece.color == state.currentTurn) {
        setState(() {
          _selectedPosition = position;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final gameState = ref.watch(chessGameStateProvider);
    final isBlackTurn = gameState.currentTurn == ChessPieceColor.black;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pass & Play Chess'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Opponent's perspective indicator (Upside down so they can read it)
            Transform.rotate(
              angle: math.pi,
              child: _buildStatusIndicator(
                gameState, 
                forBlackPlayer: true,
              ),
            ),
            
            // The Board Container
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: AspectRatio(
                aspectRatio: 1.0,
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(
                    begin: isBlackTurn ? 0.0 : math.pi,
                    end: isBlackTurn ? math.pi : 0.0,
                  ),
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeInOutBack,
                  builder: (context, value, child) {
                    return Transform.rotate(
                      angle: value,
                      child: Container(
                        decoration: BoxDecoration(
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha:0.3),
                              blurRadius: 15,
                              offset: const Offset(0, 10),
                            ),
                          ],
                          border: Border.all(color: Colors.black87, width: 4),
                        ),
                        child: _buildBoard(gameState),
                      ),
                    );
                  },
                ),
              ),
            ),
            
            // Current player's perspective indicator
            _buildStatusIndicator(
              gameState, 
              forBlackPlayer: false,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIndicator(ChessGameState state, {required bool forBlackPlayer}) {
    final isWhiteTurn = state.currentTurn == ChessPieceColor.white;
    
    // Determine if this indicator represents the currently active player
    final isActive = (forBlackPlayer && isBlackTurn(state)) || 
                     (!forBlackPlayer && isWhiteTurn);
                     
    final color = forBlackPlayer ? Colors.black87 : Colors.white;
    final textColor = forBlackPlayer ? Colors.white : Colors.black87;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 300),
      opacity: isActive ? 1.0 : 0.3,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(24),
          boxShadow: isActive ? [
            BoxShadow(
              color: color.withValues(alpha:0.5), 
              blurRadius: 12, 
              spreadRadius: 2
            )
          ] : null,
          border: Border.all(color: Colors.grey.shade400, width: 1),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              forBlackPlayer ? "Black Player" : "White Player",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            if (isActive)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  state.isCheck ? "CHECK!" : "YOUR TURN",
                  style: TextStyle(
                    color: state.isCheck ? Colors.redAccent : (forBlackPlayer ? Colors.white70 : Colors.black54),
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                    fontSize: 16,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  bool isBlackTurn(ChessGameState state) => state.currentTurn == ChessPieceColor.black;

  Widget _buildBoard(ChessGameState state) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate the ideal size for a font character so it fits in the square
        final squareSize = constraints.maxWidth / 8;
        final pieceSize = squareSize * 0.75;
        
        return GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 8,
          ),
          itemCount: 64,
          itemBuilder: (context, index) {
            final row = index ~/ 8;
            final col = index % 8;
            final position = ChessPosition(row, col);
            final piece = state.board[position];
            
            final isLightSquare = (row + col) % 2 == 0;
            final isSelected = _selectedPosition == position;
            
            // Highlight color logic
            Color squareColor;
            if (isSelected) {
              squareColor = Colors.yellow.withValues(alpha:0.7);
            } else if (isLightSquare) {
              squareColor = const Color(0xFFF0D9B5);
            } else {
              squareColor = const Color(0xFFB58863);
            }
            
            return GestureDetector(
              onTap: () => _onSquareTapped(position, state),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                color: squareColor,
                child: piece != null
                    ? Center(
                        child: Text(
                          piece.symbol,
                          style: TextStyle(
                            fontSize: pieceSize,
                            height: 1.0,
                            // Use solid characters and color them explicitly
                            color: piece.color == ChessPieceColor.white 
                                ? Colors.white 
                                : Colors.black87,
                            shadows: [
                              Shadow(
                                color: piece.color == ChessPieceColor.white 
                                    ? Colors.black54 
                                    : Colors.white54,
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ]
                          ),
                        ),
                      )
                    : null,
              ),
            );
          },
        );
      },
    );
  }
}
