import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chess/chess.dart' as chess_lib;
import '../domain/chess_game_state.dart';

class ChessPiece {
  final String type; // 'p', 'n', 'b', 'r', 'q', 'k'
  final PlayerColor color;

  ChessPiece(this.type, this.color);
}

class ChessNotifier extends Notifier<ChessGameState> {
  late chess_lib.Chess _chessEngine;

  @override
  ChessGameState build() {
    _chessEngine = chess_lib.Chess();
    return ChessGameState(
      fen: _chessEngine.fen,
    );
  }

  /// Initialize a Single Phone (Pass & Play) game
  void initializeLocalGame() {
    _chessEngine = chess_lib.Chess();
    state = ChessGameState(
      fen: _chessEngine.fen,
      mode: GameMode.localPassAndPlay,
    );
  }

  /// Initialize a Networked game
  void initializeNetworkGame(PlayerColor localColor, String whiteId, String blackId) {
    _chessEngine = chess_lib.Chess();
    state = ChessGameState(
      fen: _chessEngine.fen,
      mode: GameMode.networked,
      localPlayerColor: localColor,
      whitePlayerId: whiteId,
      blackPlayerId: blackId,
    );
  }

  /// Exposes the current board as an 8x8 array.
  /// Ranks from 8 down to 1 (index 0 is rank 8).
  /// Files from 'a' to 'h' (index 0 is file 'a').
  List<List<ChessPiece?>> getBoardArray() {
    List<List<ChessPiece?>> board = [];
    List<String> files = ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h'];
    
    for (int rank = 8; rank >= 1; rank--) {
      List<ChessPiece?> row = [];
      for (String file in files) {
        final square = '$file$rank';
        final piece = _chessEngine.get(square);
        if (piece != null) {
          row.add(ChessPiece(
            piece.type.name, // e.g. 'p', 'n'
            piece.color == chess_lib.Color.WHITE ? PlayerColor.white : PlayerColor.black,
          ));
        } else {
          row.add(null);
        }
      }
      board.add(row);
    }
    return board;
  }

  /// Returns a list of valid destination squares (e.g., ['e4', 'e3']) for a given square (e.g., 'e2')
  List<String> getValidMovesForSquare(String square) {
    if (state.isGameOver) return [];
    
    // In network mode, we shouldn't show valid moves if it's not our turn
    if (state.mode == GameMode.networked) {
      if (state.localPlayerColor == PlayerColor.white && _chessEngine.turn != chess_lib.Color.WHITE) {
        return [];
      }
      if (state.localPlayerColor == PlayerColor.black && _chessEngine.turn != chess_lib.Color.BLACK) {
        return [];
      }
    }

    final moves = _chessEngine.generate_moves({'square': square});
    return moves.map((m) => m.toAlgebraic).toList();
  }

  /// Make a move. In network mode, this will validate locally and emit a network event.
  bool makeMove(String fromSquare, String toSquare, {String? promotionPiece}) {
    if (state.isGameOver) return false;

    // Validate turn in network mode
    if (state.mode == GameMode.networked) {
      if (state.localPlayerColor == PlayerColor.white && _chessEngine.turn != chess_lib.Color.WHITE) {
        return false;
      }
      if (state.localPlayerColor == PlayerColor.black && _chessEngine.turn != chess_lib.Color.BLACK) {
        return false;
      }
    }

    final moveDict = {'from': fromSquare, 'to': toSquare};
    if (promotionPiece != null) {
      moveDict['promotion'] = promotionPiece;
    }

    final moveResult = _chessEngine.move(moveDict);
    if (moveResult == false) {
      return false; // Invalid move
    }

    if (state.mode == GameMode.networked) {
      // TODO: (Integrator) Send this move via TCP to the Host/Clients.
      // Example: ref.read(tcpClientProvider).sendChessMove(fromSquare, toSquare, promotionPiece);
    }

    _updateStateFromEngine();
    return true;
  }

  /// Synchronize the local board with a FEN received from the Host (Network Mode)
  void syncStateFromNetwork(String fen) {
    _chessEngine.load(fen);
    _updateStateFromEngine();
  }

  void _updateStateFromEngine() {
    bool isCheckmate = _chessEngine.in_checkmate;
    bool isStalemate = _chessEngine.in_stalemate;
    bool isDraw = _chessEngine.in_draw;
    bool isGameOver = _chessEngine.game_over;

    String? message;
    if (isCheckmate) {
      message = _chessEngine.turn == chess_lib.Color.WHITE ? 'Black wins by Checkmate' : 'White wins by Checkmate';
    } else if (isStalemate) {
      message = 'Draw by Stalemate';
    } else if (isDraw) {
      message = 'Draw';
    }

    state = state.copyWith(
      fen: _chessEngine.fen,
      isGameOver: isGameOver,
      isCheckmate: isCheckmate,
      isStalemate: isStalemate,
      isDraw: isDraw,
      resultMessage: message,
    );
  }
}

final chessProvider = NotifierProvider<ChessNotifier, ChessGameState>(() {
  return ChessNotifier();
});
