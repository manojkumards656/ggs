import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chess/chess.dart' as chess_lib;

// ──────────────────────────────────────────────────────────
//  Data models
// ──────────────────────────────────────────────────────────

enum ChessPieceColor { white, black }

enum ChessPieceType { pawn, knight, bishop, rook, queen, king }

class ChessPiece {
  final ChessPieceColor color;
  final ChessPieceType type;

  const ChessPiece(this.color, this.type);

  /// Returns distinct Unicode symbols for white vs black pieces.
  /// White pieces use outline glyphs, black pieces use filled glyphs.
  String get symbol {
    if (color == ChessPieceColor.white) {
      switch (type) {
        case ChessPieceType.king:
          return '♔';
        case ChessPieceType.queen:
          return '♕';
        case ChessPieceType.rook:
          return '♖';
        case ChessPieceType.bishop:
          return '♗';
        case ChessPieceType.knight:
          return '♘';
        case ChessPieceType.pawn:
          return '♙';
      }
    } else {
      switch (type) {
        case ChessPieceType.king:
          return '♚';
        case ChessPieceType.queen:
          return '♛';
        case ChessPieceType.rook:
          return '♜';
        case ChessPieceType.bishop:
          return '♝';
        case ChessPieceType.knight:
          return '♞';
        case ChessPieceType.pawn:
          return '♟';
      }
    }
  }
}

class ChessPosition {
  final int row; // 0 = rank 8 (top), 7 = rank 1 (bottom)
  final int col; // 0 = file a, 7 = file h

  const ChessPosition(this.row, this.col);

  /// Convert to algebraic notation (e.g. "e2")
  String toAlgebraic() {
    final file = String.fromCharCode('a'.codeUnitAt(0) + col);
    final rank = (8 - row).toString();
    return '$file$rank';
  }

  /// Create from algebraic notation (e.g. "e2")
  factory ChessPosition.fromAlgebraic(String algebraic) {
    final col = algebraic.codeUnitAt(0) - 'a'.codeUnitAt(0);
    final row = 8 - int.parse(algebraic[1]);
    return ChessPosition(row, col);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChessPosition &&
          runtimeType == other.runtimeType &&
          row == other.row &&
          col == other.col;

  @override
  int get hashCode => row.hashCode ^ (col.hashCode * 31);
}

// ──────────────────────────────────────────────────────────
//  Game state
// ──────────────────────────────────────────────────────────

class ChessGameState {
  final Map<ChessPosition, ChessPiece> board;
  final ChessPieceColor currentTurn;
  final bool isCheck;
  final bool isCheckmate;
  final bool isStalemate;
  final bool isDraw;
  final bool isGameOver;
  final String? resultMessage;
  final ChessPosition? lastMoveFrom;
  final ChessPosition? lastMoveTo;

  const ChessGameState({
    required this.board,
    required this.currentTurn,
    this.isCheck = false,
    this.isCheckmate = false,
    this.isStalemate = false,
    this.isDraw = false,
    this.isGameOver = false,
    this.resultMessage,
    this.lastMoveFrom,
    this.lastMoveTo,
  });
}

// ──────────────────────────────────────────────────────────
//  Helper: convert chess_lib types to our types
// ──────────────────────────────────────────────────────────

ChessPieceType _mapPieceType(chess_lib.PieceType type) {
  if (type == chess_lib.PieceType.PAWN) return ChessPieceType.pawn;
  if (type == chess_lib.PieceType.KNIGHT) return ChessPieceType.knight;
  if (type == chess_lib.PieceType.BISHOP) return ChessPieceType.bishop;
  if (type == chess_lib.PieceType.ROOK) return ChessPieceType.rook;
  if (type == chess_lib.PieceType.QUEEN) return ChessPieceType.queen;
  if (type == chess_lib.PieceType.KING) return ChessPieceType.king;
  return ChessPieceType.pawn; // fallback
}

ChessPieceColor _mapColor(chess_lib.Color color) {
  return color == chess_lib.Color.WHITE
      ? ChessPieceColor.white
      : ChessPieceColor.black;
}

// ──────────────────────────────────────────────────────────
//  Notifier – wraps the chess engine
// ──────────────────────────────────────────────────────────

class ChessGameStateNotifier extends Notifier<ChessGameState> {
  late chess_lib.Chess _engine;

  @override
  ChessGameState build() {
    _engine = chess_lib.Chess();
    return _buildStateFromEngine();
  }

  /// Reset the game.
  void resetGame() {
    _engine = chess_lib.Chess();
    state = _buildStateFromEngine();
  }

  /// Get valid destination positions for the piece at [position].
  List<ChessPosition> getValidMoves(ChessPosition position) {
    if (state.isGameOver) return [];

    final square = position.toAlgebraic();
    final piece = _engine.get(square);
    if (piece == null) return [];

    // Only allow moves for the current turn's pieces.
    final currentEngineColor = _engine.turn;
    if (piece.color != currentEngineColor) return [];

    // Generate legal moves from the given square.
    final moves = _engine.generate_moves({'square': square});
    return moves.map((m) => ChessPosition.fromAlgebraic(m.toAlgebraic)).toList();
  }

  /// Attempt to make a move from [from] to [to].
  /// [promotionPiece] is the piece type name (e.g. 'q','r','b','n') if promoting.
  /// Returns true if the move was successful.
  bool makeMove(ChessPosition from, ChessPosition to, {String? promotionPiece}) {
    if (state.isGameOver) return false;

    final fromStr = from.toAlgebraic();
    final toStr = to.toAlgebraic();

    // Check if this is a pawn promotion move
    final piece = _engine.get(fromStr);
    if (piece != null && piece.type == chess_lib.PieceType.PAWN) {
      final targetRank = to.row;
      final isWhite = piece.color == chess_lib.Color.WHITE;
      if ((isWhite && targetRank == 0) || (!isWhite && targetRank == 7)) {
        // It's a promotion
        final promoChar = promotionPiece ?? 'q'; // default to queen
        final moveMap = {'from': fromStr, 'to': toStr, 'promotion': promoChar};
        final success = _engine.move(moveMap);
        if (success) {
          state = _buildStateFromEngine(lastFrom: from, lastTo: to);
          return true;
        }
        return false;
      }
    }

    final moveMap = {'from': fromStr, 'to': toStr};
    final success = _engine.move(moveMap);
    if (!success) return false;

    state = _buildStateFromEngine(lastFrom: from, lastTo: to);
    return true;
  }

  /// Check if a move from [from] to [to] would be a pawn promotion.
  bool isPromotionMove(ChessPosition from, ChessPosition to) {
    final square = from.toAlgebraic();
    final piece = _engine.get(square);
    if (piece == null || piece.type != chess_lib.PieceType.PAWN) return false;

    final isWhite = piece.color == chess_lib.Color.WHITE;
    return (isWhite && to.row == 0) || (!isWhite && to.row == 7);
  }

  ChessGameState _buildStateFromEngine({ChessPosition? lastFrom, ChessPosition? lastTo}) {
    final board = <ChessPosition, ChessPiece>{};
    const files = ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h'];

    for (int rank = 8; rank >= 1; rank--) {
      for (int fileIdx = 0; fileIdx < 8; fileIdx++) {
        final square = '${files[fileIdx]}$rank';
        final piece = _engine.get(square);
        if (piece != null) {
          final row = 8 - rank;
          final col = fileIdx;
          board[ChessPosition(row, col)] = ChessPiece(
            _mapColor(piece.color),
            _mapPieceType(piece.type),
          );
        }
      }
    }

    final isCheck = _engine.in_check;
    final isCheckmate = _engine.in_checkmate;
    final isStalemate = _engine.in_stalemate;
    final isDraw = _engine.in_draw;
    final isGameOver = _engine.game_over;

    String? message;
    if (isCheckmate) {
      message = _engine.turn == chess_lib.Color.WHITE
          ? 'Black wins by Checkmate!'
          : 'White wins by Checkmate!';
    } else if (isStalemate) {
      message = 'Draw by Stalemate';
    } else if (isDraw) {
      message = 'Draw';
    }

    return ChessGameState(
      board: board,
      currentTurn: _engine.turn == chess_lib.Color.WHITE
          ? ChessPieceColor.white
          : ChessPieceColor.black,
      isCheck: isCheck,
      isCheckmate: isCheckmate,
      isStalemate: isStalemate,
      isDraw: isDraw,
      isGameOver: isGameOver,
      resultMessage: message,
      lastMoveFrom: lastFrom,
      lastMoveTo: lastTo,
    );
  }
}

// ──────────────────────────────────────────────────────────
//  Providers
// ──────────────────────────────────────────────────────────

final chessGameStateProvider =
    NotifierProvider<ChessGameStateNotifier, ChessGameState>(() {
  return ChessGameStateNotifier();
});

/// Provider that returns valid moves for a given position.
final validMovesProvider =
    Provider.family<List<ChessPosition>, ChessPosition>((ref, position) {
  final notifier = ref.read(chessGameStateProvider.notifier);
  return notifier.getValidMoves(position);
});

/// Provider that exposes the move action.
final chessMoveActionProvider = Provider((ref) {
  return (ChessPosition from, ChessPosition to, {String? promotionPiece}) {
    return ref
        .read(chessGameStateProvider.notifier)
        .makeMove(from, to, promotionPiece: promotionPiece);
  };
});
