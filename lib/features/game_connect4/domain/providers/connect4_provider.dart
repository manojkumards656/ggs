import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/connect4_state.dart';

class Connect4Notifier extends Notifier<Connect4State> {
  static const int rows = 6;
  static const int cols = 7;

  @override
  Connect4State build() {
    return Connect4State(
      board: List.generate(rows, (_) => List.filled(cols, 0)),
      currentPlayer: 1,
      winner: 0,
      winningCells: [],
      isNetworked: false, // Default to Pass & Play
      isHost: true,
    );
  }

  void setMode({required bool isNetworked, required bool isHost}) {
    state = state.copyWith(isNetworked: isNetworked, isHost: isHost);
  }

  void resetGame() {
    state = Connect4State(
      board: List.generate(rows, (_) => List.filled(cols, 0)),
      currentPlayer: 1,
      winner: 0,
      winningCells: [],
      isNetworked: state.isNetworked,
      isHost: state.isHost,
    );
  }

  void dropChecker(int col) {
    if (state.winner != 0) return; // Game over
    if (col < 0 || col >= cols) return;
    
    // In networked mode, only allow moves if it's our turn
    if (state.isNetworked) {
      bool myTurn = (state.isHost && state.currentPlayer == 1) || (!state.isHost && state.currentPlayer == 2);
      if (!myTurn) return;
    }

    _applyMove(col);
    
    if (state.isNetworked) {
      // Typically you would inject or read a networking provider here.
      // e.g. ref.read(tcpClientProvider).send({'type': 'connect4_move', 'col': col});
    }
  }

  void handleNetworkPayload(Map<String, dynamic> data) {
    if (data['type'] == 'connect4_move') {
      final col = data['col'];
      if (col is! int || col < 0 || col >= cols) return;
      _applyMove(col);
    } else if (data['type'] == 'connect4_reset') {
      resetGame();
    }
  }

  void _applyMove(int col) {
    List<List<int>> newBoard = List.generate(rows, (r) => List.from(state.board[r]));
    
    int targetRow = -1;
    for (int r = rows - 1; r >= 0; r--) {
      if (newBoard[r][col] == 0) {
        targetRow = r;
        break;
      }
    }
    
    if (targetRow == -1) return; // Column is full
    
    newBoard[targetRow][col] = state.currentPlayer;
    
    List<List<int>> winCells = _checkWin(newBoard, targetRow, col, state.currentPlayer);
    int nextWinner = 0;
    
    if (winCells.isNotEmpty) {
      nextWinner = state.currentPlayer;
    } else if (_isBoardFull(newBoard)) {
      nextWinner = -1; // Draw
    }
    
    state = state.copyWith(
      board: newBoard,
      currentPlayer: state.currentPlayer == 1 ? 2 : 1,
      winner: nextWinner,
      winningCells: winCells,
    );
  }
  
  bool _isBoardFull(List<List<int>> board) {
    for (int c = 0; c < cols; c++) {
      if (board[0][c] == 0) return false;
    }
    return true;
  }

  List<List<int>> _checkWin(List<List<int>> board, int row, int col, int player) {
    // Check horizontal
    int count = 1;
    List<List<int>> cells = [[row, col]];
    for (int c = col - 1; c >= 0; c--) {
      if (board[row][c] == player) { count++; cells.add([row, c]); } else {
        break;
      }
    }
    for (int c = col + 1; c < cols; c++) {
      if (board[row][c] == player) { count++; cells.add([row, c]); } else {
        break;
      }
    }
    if (count >= 4) return cells;

    // Check vertical
    count = 1;
    cells = [[row, col]];
    for (int r = row - 1; r >= 0; r--) {
      if (board[r][col] == player) { count++; cells.add([r, col]); } else {
        break;
      }
    }
    for (int r = row + 1; r < rows; r++) {
      if (board[r][col] == player) { count++; cells.add([r, col]); } else {
        break;
      }
    }
    if (count >= 4) return cells;

    // Check diagonal \
    count = 1;
    cells = [[row, col]];
    for (int i = 1; row - i >= 0 && col - i >= 0; i++) {
      if (board[row - i][col - i] == player) { count++; cells.add([row - i, col - i]); } else {
        break;
      }
    }
    for (int i = 1; row + i < rows && col + i < cols; i++) {
      if (board[row + i][col + i] == player) { count++; cells.add([row + i, col + i]); } else {
        break;
      }
    }
    if (count >= 4) return cells;

    // Check diagonal /
    count = 1;
    cells = [[row, col]];
    for (int i = 1; row - i >= 0 && col + i < cols; i++) {
      if (board[row - i][col + i] == player) { count++; cells.add([row - i, col + i]); } else {
        break;
      }
    }
    for (int i = 1; row + i < rows && col - i >= 0; i++) {
      if (board[row + i][col - i] == player) { count++; cells.add([row + i, col - i]); } else {
        break;
      }
    }
    if (count >= 4) return cells;

    return [];
  }
}

final connect4Provider = NotifierProvider<Connect4Notifier, Connect4State>(() {
  return Connect4Notifier();
});
