import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/reversi_game_state.dart';

class ReversiNotifier extends Notifier<ReversiGameState> {
  @override
  ReversiGameState build() {
    return _createInitialState(GameMode.localPassAndPlay);
  }

  void initializeLocalGame() {
    state = _createInitialState(GameMode.localPassAndPlay);
  }

  void initializeNetworkGame(PlayerColor localColor, String whiteId, String blackId) {
    state = _createInitialState(
      GameMode.networked,
      localColor: localColor,
      whiteId: whiteId,
      blackId: blackId,
    );
  }

  ReversiGameState _createInitialState(
    GameMode mode, {
    PlayerColor? localColor,
    String? whiteId,
    String? blackId,
  }) {
    // 8x8 empty board
    List<List<ReversiPiece?>> board = List.generate(8, (_) => List.generate(8, (_) => null));
    
    // Initial setup
    board[3][3] = const ReversiPiece(color: PlayerColor.white);
    board[3][4] = const ReversiPiece(color: PlayerColor.black);
    board[4][3] = const ReversiPiece(color: PlayerColor.black);
    board[4][4] = const ReversiPiece(color: PlayerColor.white);

    return ReversiGameState(
      board: board,
      mode: mode,
      localPlayerColor: localColor,
      whitePlayerId: whiteId,
      blackPlayerId: blackId,
      currentTurn: PlayerColor.black, // Black goes first in Reversi
      blackScore: 2,
      whiteScore: 2,
    );
  }

  bool makeMove(int r, int c) {
    if (state.isGameOver) return false;

    // Validate turn in network mode
    if (state.mode == GameMode.networked) {
      if (state.localPlayerColor != state.currentTurn) {
        return false;
      }
    }

    if (state.board[r][c] != null) return false;

    final flips = _getFlips(r, c, state.currentTurn, state.board);
    if (flips.isEmpty) return false;

    // Apply move
    final newBoard = _copyBoard(state.board);
    final newTurnCount = state.turnCount + 1;
    
    // Place new piece
    newBoard[r][c] = ReversiPiece(
      color: state.currentTurn,
      lastFlippedTurn: newTurnCount,
      delayMs: 0,
    );

    // Flip pieces
    for (var flip in flips) {
      final flipR = flip[0];
      final flipC = flip[1];
      
      // Calculate delay based on distance from placed piece
      final int distR = (flipR - r).abs();
      final int distC = (flipC - c).abs();
      final distance = distR > distC ? distR : distC;
      
      newBoard[flipR][flipC] = ReversiPiece(
        color: state.currentTurn,
        lastFlippedTurn: newTurnCount,
        delayMs: distance * 150, // Slight delay for chain reaction effect
      );
    }

    // Switch turn
    PlayerColor nextTurn = state.currentTurn == PlayerColor.black ? PlayerColor.white : PlayerColor.black;
    bool nextPlayerCanMove = _hasValidMove(nextTurn, newBoard);
    
    // If next player has no moves, skip turn. If neither can move, game over.
    bool isGameOver = false;
    if (!nextPlayerCanMove) {
      nextTurn = state.currentTurn;
      if (!_hasValidMove(nextTurn, newBoard)) {
        isGameOver = true;
      }
    }

    // Calculate score
    int black = 0;
    int white = 0;
    for (int i = 0; i < 8; i++) {
      for (int j = 0; j < 8; j++) {
        if (newBoard[i][j]?.color == PlayerColor.black) black++;
        if (newBoard[i][j]?.color == PlayerColor.white) white++;
      }
    }

    PlayerColor? winner;
    if (isGameOver) {
      if (black > white) {
        winner = PlayerColor.black;
      } else if (white > black) {
        winner = PlayerColor.white;
      }
    }

    state = state.copyWith(
      board: newBoard,
      currentTurn: nextTurn,
      isGameOver: isGameOver,
      winner: winner,
      blackScore: black,
      whiteScore: white,
      turnCount: newTurnCount,
    );

    if (state.mode == GameMode.networked) {
      // TODO: (Integrator) Send move (r, c) via TCP to Host/Clients
    }

    return true;
  }

  List<List<int>> _getFlips(int r, int c, PlayerColor color, List<List<ReversiPiece?>> board) {
    List<List<int>> flips = [];
    final directions = [
      [-1, -1], [-1, 0], [-1, 1],
      [ 0, -1],          [ 0, 1],
      [ 1, -1], [ 1, 0], [ 1, 1]
    ];

    for (var dir in directions) {
      int dr = dir[0];
      int dc = dir[1];
      int curR = r + dr;
      int curC = c + dc;
      List<List<int>> potentialFlips = [];

      while (curR >= 0 && curR < 8 && curC >= 0 && curC < 8) {
        final piece = board[curR][curC];
        if (piece == null) break;
        if (piece.color == color) {
          flips.addAll(potentialFlips);
          break;
        } else {
          potentialFlips.add([curR, curC]);
        }
        curR += dr;
        curC += dc;
      }
    }
    return flips;
  }

  bool _hasValidMove(PlayerColor color, List<List<ReversiPiece?>> board) {
    for (int r = 0; r < 8; r++) {
      for (int c = 0; c < 8; c++) {
        if (board[r][c] == null && _getFlips(r, c, color, board).isNotEmpty) {
          return true;
        }
      }
    }
    return false;
  }

  List<List<ReversiPiece?>> _copyBoard(List<List<ReversiPiece?>> board) {
    return board.map((row) => List<ReversiPiece?>.from(row)).toList();
  }
}

final reversiProvider = NotifierProvider<ReversiNotifier, ReversiGameState>(() {
  return ReversiNotifier();
});
