enum GameMode { localPassAndPlay, networked }
enum PlayerColor { white, black }

class ReversiPiece {
  final PlayerColor color;
  final int lastFlippedTurn;
  final int delayMs;

  const ReversiPiece({
    required this.color,
    this.lastFlippedTurn = 0,
    this.delayMs = 0,
  });

  ReversiPiece copyWith({
    PlayerColor? color,
    int? lastFlippedTurn,
    int? delayMs,
  }) {
    return ReversiPiece(
      color: color ?? this.color,
      lastFlippedTurn: lastFlippedTurn ?? this.lastFlippedTurn,
      delayMs: delayMs ?? this.delayMs,
    );
  }
}

class ReversiGameState {
  final List<List<ReversiPiece?>> board;
  final GameMode mode;
  final PlayerColor? localPlayerColor; // Which color local device controls in network
  final String? whitePlayerId;
  final String? blackPlayerId;
  final PlayerColor currentTurn;
  final bool isGameOver;
  final PlayerColor? winner;
  final int blackScore;
  final int whiteScore;
  final int turnCount;

  const ReversiGameState({
    required this.board,
    this.mode = GameMode.localPassAndPlay,
    this.localPlayerColor,
    this.whitePlayerId,
    this.blackPlayerId,
    required this.currentTurn,
    this.isGameOver = false,
    this.winner,
    required this.blackScore,
    required this.whiteScore,
    this.turnCount = 0,
  });

  ReversiGameState copyWith({
    List<List<ReversiPiece?>>? board,
    GameMode? mode,
    PlayerColor? localPlayerColor,
    String? whitePlayerId,
    String? blackPlayerId,
    PlayerColor? currentTurn,
    bool? isGameOver,
    PlayerColor? winner,
    int? blackScore,
    int? whiteScore,
    int? turnCount,
  }) {
    return ReversiGameState(
      board: board ?? this.board,
      mode: mode ?? this.mode,
      localPlayerColor: localPlayerColor ?? this.localPlayerColor,
      whitePlayerId: whitePlayerId ?? this.whitePlayerId,
      blackPlayerId: blackPlayerId ?? this.blackPlayerId,
      currentTurn: currentTurn ?? this.currentTurn,
      isGameOver: isGameOver ?? this.isGameOver,
      winner: winner ?? this.winner,
      blackScore: blackScore ?? this.blackScore,
      whiteScore: whiteScore ?? this.whiteScore,
      turnCount: turnCount ?? this.turnCount,
    );
  }
}
