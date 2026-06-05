// Shared enums used across multiple game modules.
//
// Why centralize: GameMode and PlayerColor were independently redefined
// in reversi_game_state.dart, spyfall_state.dart, and chess_game_state.dart.
// A single source of truth prevents subtle mismatches when comparing across modules.

/// The play mode for a game session.
enum GameMode {
  /// Both players use the same device, taking turns.
  localPassAndPlay,

  /// Players on separate devices connected via LAN TCP.
  networked,
}
