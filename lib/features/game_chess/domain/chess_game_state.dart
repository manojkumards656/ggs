enum GameMode { localPassAndPlay, networked }
enum PlayerColor { white, black }

class ChessGameState {
  final String fen;
  final GameMode mode;
  final PlayerColor? localPlayerColor; // Defines which side the current device controls in network mode
  final String? whitePlayerId;
  final String? blackPlayerId;
  final bool isGameOver;
  final bool isCheckmate;
  final bool isStalemate;
  final bool isDraw;
  final String? resultMessage;

  const ChessGameState({
    required this.fen,
    this.mode = GameMode.localPassAndPlay,
    this.localPlayerColor,
    this.whitePlayerId,
    this.blackPlayerId,
    this.isGameOver = false,
    this.isCheckmate = false,
    this.isStalemate = false,
    this.isDraw = false,
    this.resultMessage,
  });

  ChessGameState copyWith({
    String? fen,
    GameMode? mode,
    PlayerColor? localPlayerColor,
    String? whitePlayerId,
    String? blackPlayerId,
    bool? isGameOver,
    bool? isCheckmate,
    bool? isStalemate,
    bool? isDraw,
    String? resultMessage,
  }) {
    return ChessGameState(
      fen: fen ?? this.fen,
      mode: mode ?? this.mode,
      localPlayerColor: localPlayerColor ?? this.localPlayerColor,
      whitePlayerId: whitePlayerId ?? this.whitePlayerId,
      blackPlayerId: blackPlayerId ?? this.blackPlayerId,
      isGameOver: isGameOver ?? this.isGameOver,
      isCheckmate: isCheckmate ?? this.isCheckmate,
      isStalemate: isStalemate ?? this.isStalemate,
      isDraw: isDraw ?? this.isDraw,
      resultMessage: resultMessage ?? this.resultMessage,
    );
  }
}
