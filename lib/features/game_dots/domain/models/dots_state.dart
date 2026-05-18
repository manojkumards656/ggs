enum DotsMode { networked, passAndPlay }

class DotsState {
  final DotsMode mode;
  final Set<String> horizontalLines; // format: "row_col" e.g. "0_0"
  final Set<String> verticalLines;   // format: "row_col" e.g. "0_0"
  final Map<String, String> boxes;   // format: "row_col" -> playerId
  final Map<String, int> scores;     // playerId -> score
  final String activePlayerId;
  final String activePlayerName;
  final String? winnerId;
  final bool isGameOver;
  final int gridRows; // number of box rows
  final int gridCols; // number of box cols

  const DotsState({
    this.mode = DotsMode.passAndPlay,
    this.horizontalLines = const {},
    this.verticalLines = const {},
    this.boxes = const {},
    this.scores = const {},
    this.activePlayerId = 'player1',
    this.activePlayerName = 'Player 1',
    this.winnerId,
    this.isGameOver = false,
    this.gridRows = 4,
    this.gridCols = 4,
  });

  DotsState copyWith({
    DotsMode? mode,
    Set<String>? horizontalLines,
    Set<String>? verticalLines,
    Map<String, String>? boxes,
    Map<String, int>? scores,
    String? activePlayerId,
    String? activePlayerName,
    String? winnerId,
    bool? isGameOver,
    int? gridRows,
    int? gridCols,
  }) {
    return DotsState(
      mode: mode ?? this.mode,
      horizontalLines: horizontalLines ?? this.horizontalLines,
      verticalLines: verticalLines ?? this.verticalLines,
      boxes: boxes ?? this.boxes,
      scores: scores ?? this.scores,
      activePlayerId: activePlayerId ?? this.activePlayerId,
      activePlayerName: activePlayerName ?? this.activePlayerName,
      winnerId: winnerId ?? this.winnerId,
      isGameOver: isGameOver ?? this.isGameOver,
      gridRows: gridRows ?? this.gridRows,
      gridCols: gridCols ?? this.gridCols,
    );
  }
}
