import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chess/chess.dart' as chess_logic;
import '../models/chess_state.dart';

class ChessNotifier extends Notifier<ChessState> {
  late chess_logic.Chess _chess;
  int _incrementSeconds = 0;

  @override
  ChessState build() {
    _chess = chess_logic.Chess();
    return ChessState.initial();
  }

  /// Initialize a new game
  void initGame({
    required String whitePlayerName,
    required String blackPlayerName,
    required int initialTimeSeconds,
    required int incrementSeconds,
  }) {
    _chess = chess_logic.Chess();
    _incrementSeconds = incrementSeconds;
    
    state = ChessState(
      boardFen: _chess.fen,
      whiteTimeRemaining: initialTimeSeconds,
      blackTimeRemaining: initialTimeSeconds,
      activeColor: 'w',
      isGameOver: false,
      gameOverReason: null,
      winnerColor: null,
      selectedSquare: null,
      validMovesForSelected: const [],
      moveHistory: const [],
      lastMoveFrom: null,
      lastMoveTo: null,
      isCheck: false,
      whitePlayerName: whitePlayerName,
      blackPlayerName: blackPlayerName,
      isPromotionPending: false,
      promotionSource: null,
      promotionTarget: null,
    );
  }

  /// Load a full state (useful for syncing on client)
  void syncState(ChessState newState) {
    state = newState;
    _chess.load(newState.boardFen);
  }

  /// Handles cell selection and move execution
  void selectSquare(String square, String localPlayerColor) {
    if (state.isGameOver || state.isPromotionPending) return;

    // Check if it's the local player's turn (if color is specified)
    if (localPlayerColor.isNotEmpty && localPlayerColor != state.activeColor) {
      return;
    }

    final selected = state.selectedSquare;
    final pieceOnSquare = _chess.get(square);

    if (selected != null) {
      // If tapping the same square, deselect
      if (selected == square) {
        state = state.copyWith(
          selectedSquare: null,
          validMovesForSelected: const [],
        );
        return;
      }

      // Check if tapping a valid move target
      if (state.validMovesForSelected.contains(square)) {
        // Check if this is a pawn promotion move
        final movingPiece = _chess.get(selected);
        final isPawn = movingPiece?.type == chess_logic.PieceType.PAWN;
        final targetRank = square[1];
        final isPromotion = isPawn && (targetRank == '8' || targetRank == '1');

        if (isPromotion) {
          state = state.copyWith(
            isPromotionPending: true,
            promotionSource: selected,
            promotionTarget: square,
          );
        } else {
          executeMove(selected, square);
        }
        return;
      }

      // If not a valid move target, check if tapping another of player's own pieces to select it
      if (pieceOnSquare != null && _getPieceColorString(pieceOnSquare.color) == state.activeColor) {
        _selectPiece(square);
      } else {
        // Tap empty/enemy square, deselect
        state = state.copyWith(
          selectedSquare: null,
          validMovesForSelected: const [],
        );
      }
    } else {
      // No square selected yet. Select if it is active player's piece
      if (pieceOnSquare != null && _getPieceColorString(pieceOnSquare.color) == state.activeColor) {
        _selectPiece(square);
      }
    }
  }

  /// Selects a piece and computes its legal moves
  void _selectPiece(String square) {
    // Generate legal moves for this square
    final verboseMoves = _chess.moves({'square': square, 'verbose': true});
    final validTargets = verboseMoves
        .map((m) => m['to'] as String)
        .toList();

    state = state.copyWith(
      selectedSquare: square,
      validMovesForSelected: validTargets,
    );
  }

  /// Executes a move and updates game state
  bool executeMove(String from, String to, [String? promotion]) {
    final moveMap = {
      'from': from,
      'to': to,
    };
    if (promotion != null) {
      moveMap['promotion'] = promotion;
    }

    final success = _chess.move(moveMap);
    if (!success) return false;

    // Apply Fisher Increment to the player who just moved
    int newWhiteTime = state.whiteTimeRemaining;
    int newBlackTime = state.blackTimeRemaining;
    
    // The active turn has already changed inside _chess.move()
    final nextTurn = _chess.turn == chess_logic.Color.WHITE ? 'w' : 'b';
    
    if (nextTurn == 'b') {
      // White just moved, add increment to White (if timers are active)
      if (newWhiteTime > 0) newWhiteTime += _incrementSeconds;
    } else {
      // Black just moved, add increment to Black (if timers are active)
      if (newBlackTime > 0) newBlackTime += _incrementSeconds;
    }

    // Get updated status
    final isGameOver = _chess.game_over;
    String? reason;
    String? winner;

    if (isGameOver) {
      if (_chess.in_checkmate) {
        reason = 'Checkmate';
        winner = nextTurn == 'w' ? 'b' : 'w'; // Turn has toggled, so loser is the new active player
      } else if (_chess.in_stalemate) {
        reason = 'Stalemate';
        winner = 'draw';
      } else if (_chess.in_threefold_repetition) {
        reason = 'Threefold Repetition';
        winner = 'draw';
      } else if (_chess.insufficient_material) {
        reason = 'Insufficient Material';
        winner = 'draw';
      } else {
        reason = 'Draw';
        winner = 'draw';
      }
    }

    // Get move history in SAN
    final history = _chess.getHistory();

    state = state.copyWith(
      boardFen: _chess.fen,
      activeColor: nextTurn,
      isGameOver: isGameOver,
      gameOverReason: reason,
      winnerColor: winner,
      whiteTimeRemaining: newWhiteTime,
      blackTimeRemaining: newBlackTime,
      selectedSquare: null,
      validMovesForSelected: const [],
      moveHistory: history.map((h) => h.toString()).toList(),
      lastMoveFrom: from,
      lastMoveTo: to,
      isCheck: _chess.in_check,
      isPromotionPending: false,
      promotionSource: null,
      promotionTarget: null,
    );

    return true;
  }

  /// Toggles pawn promotion choice
  void selectPromotion(String pieceType) {
    final from = state.promotionSource;
    final to = state.promotionTarget;
    if (from != null && to != null) {
      executeMove(from, to, pieceType);
    }
  }

  /// Cancels a pending promotion selection
  void cancelPromotion() {
    state = state.copyWith(
      isPromotionPending: false,
      promotionSource: null,
      promotionTarget: null,
      selectedSquare: null,
      validMovesForSelected: const [],
    );
  }

  /// Tick clock by 1 second (battery-efficient timer ticks)
  void tickClock() {
    if (state.isGameOver) return;
    
    // Check if timers are active (0 or -1 means untimed)
    if (state.whiteTimeRemaining <= 0 && state.blackTimeRemaining <= 0) return;

    if (state.activeColor == 'w') {
      final newTime = state.whiteTimeRemaining - 1;
      if (newTime <= 0) {
        state = state.copyWith(
          whiteTimeRemaining: 0,
          isGameOver: true,
          winnerColor: 'b',
          gameOverReason: 'Timeout',
        );
      } else {
        state = state.copyWith(whiteTimeRemaining: newTime);
      }
    } else {
      final newTime = state.blackTimeRemaining - 1;
      if (newTime <= 0) {
        state = state.copyWith(
          blackTimeRemaining: 0,
          isGameOver: true,
          winnerColor: 'w',
          gameOverReason: 'Timeout',
        );
      } else {
        state = state.copyWith(blackTimeRemaining: newTime);
      }
    }
  }

  /// Resign from the game
  void resign(String resigningColor) {
    if (state.isGameOver) return;
    state = state.copyWith(
      isGameOver: true,
      winnerColor: resigningColor == 'w' ? 'b' : 'w',
      gameOverReason: 'Resignation',
    );
  }

  /// Offer and accept draw
  void declareDraw(String reason) {
    if (state.isGameOver) return;
    state = state.copyWith(
      isGameOver: true,
      winnerColor: 'draw',
      gameOverReason: reason,
    );
  }

  /// Undo the last move (local pass-and-play only)
  bool undoMove() {
    if (state.moveHistory.isEmpty) return false;
    
    // Undo in engine
    final undone = _chess.undo();
    if (undone == null) return false;

    // Recalculate turn, check, and move history
    final nextTurn = _chess.turn == chess_logic.Color.WHITE ? 'w' : 'b';
    final history = _chess.getHistory();
    
    // Get last move coordinates from history if possible
    String? lastFrom;
    String? lastTo;
    
    // Unfortunately, _chess doesn't expose the move log directly in standard format,
    // but we can query it or set them to null on undo. Setting them to null is safe.
    
    state = state.copyWith(
      boardFen: _chess.fen,
      activeColor: nextTurn,
      isGameOver: false,
      gameOverReason: null,
      winnerColor: null,
      selectedSquare: null,
      validMovesForSelected: const [],
      moveHistory: history.map((h) => h.toString()).toList(),
      lastMoveFrom: lastFrom,
      lastMoveTo: lastTo,
      isCheck: _chess.in_check,
      isPromotionPending: false,
      promotionSource: null,
      promotionTarget: null,
    );

    return true;
  }

  /// Helper to check if a square contains a pawn
  bool isPawn(String square) {
    final piece = _chess.get(square);
    return piece != null && piece.type == chess_logic.PieceType.PAWN;
  }

  String _getPieceColorString(chess_logic.Color c) {
    return c == chess_logic.Color.WHITE ? 'w' : 'b';
  }
}

final chessProvider = NotifierProvider<ChessNotifier, ChessState>(() {
  return ChessNotifier();
});
