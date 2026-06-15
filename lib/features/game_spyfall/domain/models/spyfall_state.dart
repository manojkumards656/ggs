enum SpyfallGameMode { localPassAndPlay, networked }

class SpyfallState {
  final SpyfallGameMode mode;
  final List<String> players;
  final Map<String, String> playerRoles;
  final String? location;
  final int currentPlayerIndex;
  final bool isRoleRevealed;
  final String? localPlayerId;
  final bool isGameOver;

  const SpyfallState({
    this.mode = SpyfallGameMode.localPassAndPlay,
    this.players = const [],
    this.playerRoles = const {},
    this.location,
    this.currentPlayerIndex = 0,
    this.isRoleRevealed = false,
    this.localPlayerId,
    this.isGameOver = false,
  });

  SpyfallState copyWith({
    SpyfallGameMode? mode,
    List<String>? players,
    Map<String, String>? playerRoles,
    String? location,
    int? currentPlayerIndex,
    bool? isRoleRevealed,
    String? localPlayerId,
    bool? isGameOver,
  }) {
    return SpyfallState(
      mode: mode ?? this.mode,
      players: players ?? this.players,
      playerRoles: playerRoles ?? this.playerRoles,
      location: location ?? this.location,
      currentPlayerIndex: currentPlayerIndex ?? this.currentPlayerIndex,
      isRoleRevealed: isRoleRevealed ?? this.isRoleRevealed,
      localPlayerId: localPlayerId ?? this.localPlayerId,
      isGameOver: isGameOver ?? this.isGameOver,
    );
  }
}
