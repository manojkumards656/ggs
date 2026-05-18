import 'package:flutter_riverpod/flutter_riverpod.dart';

enum ChessPieceColor { white, black }
enum ChessPieceType { pawn, knight, bishop, rook, queen, king }

class ChessPiece {
  final ChessPieceColor color;
  final ChessPieceType type;

  const ChessPiece(this.color, this.type);

  String get symbol {
    switch (type) {
      case ChessPieceType.king: return '♚';
      case ChessPieceType.queen: return '♛';
      case ChessPieceType.rook: return '♜';
      case ChessPieceType.bishop: return '♝';
      case ChessPieceType.knight: return '♞';
      case ChessPieceType.pawn: return '♟';
    }
  }
}

class ChessPosition {
  final int row;
  final int col;

  const ChessPosition(this.row, this.col);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChessPosition &&
          runtimeType == other.runtimeType &&
          row == other.row &&
          col == other.col;

  @override
  int get hashCode => row.hashCode ^ col.hashCode;
}

// Mock state class representing the game state
class ChessGameState {
  final Map<ChessPosition, ChessPiece> board;
  final ChessPieceColor currentTurn;
  final bool isCheck;
  final bool isCheckmate;

  const ChessGameState({
    required this.board,
    required this.currentTurn,
    this.isCheck = false,
    this.isCheckmate = false,
  });
}

// MOCK PROVIDERS for the UI to consume
class ChessGameStateNotifier extends Notifier<ChessGameState> {
  @override
  ChessGameState build() {
    // Initial board setup
    final board = <ChessPosition, ChessPiece>{};
    
    // Setup pawns
    for (int i = 0; i < 8; i++) {
      board[ChessPosition(1, i)] = const ChessPiece(ChessPieceColor.black, ChessPieceType.pawn);
      board[ChessPosition(6, i)] = const ChessPiece(ChessPieceColor.white, ChessPieceType.pawn);
    }

    // Setup pieces
    final backRankTypes = [
      ChessPieceType.rook, ChessPieceType.knight, ChessPieceType.bishop, ChessPieceType.queen,
      ChessPieceType.king, ChessPieceType.bishop, ChessPieceType.knight, ChessPieceType.rook
    ];

    for (int i = 0; i < 8; i++) {
      board[ChessPosition(0, i)] = ChessPiece(ChessPieceColor.black, backRankTypes[i]);
      board[ChessPosition(7, i)] = ChessPiece(ChessPieceColor.white, backRankTypes[i]);
    }

    return ChessGameState(board: board, currentTurn: ChessPieceColor.white);
  }

  void updateState(ChessGameState newState) {
    state = newState;
  }
}

final chessGameStateProvider = NotifierProvider<ChessGameStateNotifier, ChessGameState>(() {
  return ChessGameStateNotifier();
});

// Provides valid moves for a given position
final validMovesProvider = Provider.family<List<ChessPosition>, ChessPosition>((ref, position) {
  // Mock: Just return an empty list or some dummy moves for demonstration
  return [];
});

final chessMoveActionProvider = Provider((ref) {
  return (ChessPosition from, ChessPosition to) {
    // Mock: handle move action
    final state = ref.read(chessGameStateProvider);
    final piece = state.board[from];
    if (piece != null) {
      final newBoard = Map<ChessPosition, ChessPiece>.from(state.board);
      newBoard.remove(from);
      newBoard[to] = piece;
      ref.read(chessGameStateProvider.notifier).updateState(ChessGameState(
        board: newBoard,
        currentTurn: state.currentTurn == ChessPieceColor.white 
            ? ChessPieceColor.black 
            : ChessPieceColor.white,
      ));
    }
  };
});
