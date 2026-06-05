class Connect4State {
  final List<List<int>> board;
  final int currentPlayer;
  final int winner;
  final List<List<int>> winningCells;
  final bool isNetworked;
  final bool isHost;

  Connect4State({
    required this.board,
    required this.currentPlayer,
    required this.winner,
    required this.winningCells,
    required this.isNetworked,
    required this.isHost,
  });

  Connect4State copyWith({
    List<List<int>>? board,
    int? currentPlayer,
    int? winner,
    List<List<int>>? winningCells,
    bool? isNetworked,
    bool? isHost,
  }) {
    return Connect4State(
      board: board ?? this.board,
      currentPlayer: currentPlayer ?? this.currentPlayer,
      winner: winner ?? this.winner,
      winningCells: winningCells ?? this.winningCells,
      isNetworked: isNetworked ?? this.isNetworked,
      isHost: isHost ?? this.isHost,
    );
  }
}
