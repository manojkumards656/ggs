import 'package:flutter/material.dart';

// ── Game Screen Imports ─────────────────────────────────────
// Each game has exactly ONE import here. Adding a game = add 1 import + 1 entry.
// Removing a game = delete 1 import + 1 entry + delete the game folder.
import 'package:pocket_party/features/game_chess/presentation/chess_board_screen.dart';
import 'package:pocket_party/features/game_connect4/presentation/connect4_screen.dart';
import 'package:pocket_party/features/game_dots/presentation/screens/dots_screen.dart';
import 'package:pocket_party/features/game_draw/presentation/game_screen.dart';
import 'package:pocket_party/features/game_draw/presentation/draw_guess_single_screen.dart';
import 'package:pocket_party/features/game_hangman/presentation/hangman_screen.dart';
import 'package:pocket_party/features/game_reversi/presentation/reversi_screen.dart';
import 'package:pocket_party/features/game_spyfall/presentation/spyfall_screen.dart';
import 'package:pocket_party/features/game_tod/presentation/screens/tod_screen.dart';
import 'package:pocket_party/features/game_youknow/presentation/screens/youknow_screen.dart';

// ─────────────────────────────────────────────────────────────
// Game Definition
// ─────────────────────────────────────────────────────────────

/// Describes a single game module: its metadata, capabilities, and screen builders.
///
/// This is the core of modularity — all routing, UI grid rendering, and mode
/// filtering throughout the app derive from this single list. No switch statements,
/// no hardcoded game names scattered across files.
class GameDefinition {
  /// Unique identifier used for serialization and lookup (e.g. 'chess', 'draw_guess').
  final String id;

  /// User-facing name shown in the game grid and lobby (e.g. 'Draw & Guess').
  final String displayName;

  /// Icon shown on the game card in the home screen grid.
  final IconData icon;

  /// Gradient for the game card — each game gets a distinct visual identity.
  final LinearGradient gradient;

  /// If true, the card shows "Coming Soon" and is non-interactive.
  final bool isComingSoon;

  /// Whether this game supports LAN multiplayer (host/join flow).
  final bool supportsNetwork;

  /// Whether this game supports single-phone pass-and-play mode.
  final bool supportsSinglePhone;

  /// Builds the screen for single-phone mode.
  /// Null if the game doesn't support single-phone play.
  final Widget Function()? singlePhoneScreenBuilder;

  /// Builds the screen for networked mode.
  /// [isHost] determines if this device is the host or a joining client.
  /// Null if the game doesn't support network play.
  final Widget Function({required bool isHost})? networkScreenBuilder;

  const GameDefinition({
    required this.id,
    required this.displayName,
    required this.icon,
    required this.gradient,
    this.isComingSoon = false,
    this.supportsNetwork = false,
    this.supportsSinglePhone = false,
    this.singlePhoneScreenBuilder,
    this.networkScreenBuilder,
  });
}

// ─────────────────────────────────────────────────────────────
// The Registry — Single Source of Truth
// ─────────────────────────────────────────────────────────────
//
// To ADD a game:
//   1. Create the game folder under lib/features/game_<name>/
//   2. Import the screen(s) at the top of this file
//   3. Add a GameDefinition entry below
//
// To REMOVE a game:
//   1. Delete the GameDefinition entry below
//   2. Remove the import at the top of this file
//   3. Delete the game folder
//
// That's it. No other files need editing.

final List<GameDefinition> gameRegistry = [
  GameDefinition(
    id: 'youknow',
    displayName: 'YouKnow',
    icon: Icons.layers,
    gradient: const LinearGradient(
      colors: [Color(0xFFE65C00), Color(0xFFF9D423)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    supportsNetwork: true,
    supportsSinglePhone: true,
    singlePhoneScreenBuilder: () => const YouKnowScreen(isNetworked: false),
    networkScreenBuilder: ({required bool isHost}) =>
        YouKnowScreen(isNetworked: true, isHost: isHost),
  ),

  GameDefinition(
    id: 'draw_guess',
    displayName: 'Draw & Guess',
    icon: Icons.brush,
    gradient: const LinearGradient(
      colors: [Color(0xFFFF0844), Color(0xFFFFB199)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    supportsNetwork: true,
    supportsSinglePhone: true,
    singlePhoneScreenBuilder: () => const DrawGuessSingleScreen(),
    networkScreenBuilder: ({required bool isHost}) =>
        GameScreen(isHost: isHost),
  ),

  GameDefinition(
    id: 'chess',
    displayName: 'Chess',
    icon: Icons.grid_on,
    gradient: const LinearGradient(
      colors: [Color(0xFF43E97B), Color(0xFF38F9D7)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    supportsNetwork: false, // Network integration is a TODO stub
    supportsSinglePhone: true,
    singlePhoneScreenBuilder: () => const ChessBoardScreen(),
  ),

  GameDefinition(
    id: 'connect4',
    displayName: 'Connect 4',
    icon: Icons.view_comfy,
    gradient: const LinearGradient(
      colors: [Color(0xFFF9D423), Color(0xFFFF4E50)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    supportsNetwork: false, // Has mode toggle in-screen, but no TCP integration yet
    supportsSinglePhone: true,
    singlePhoneScreenBuilder: () => const Connect4Screen(),
  ),

  GameDefinition(
    id: 'hangman',
    displayName: 'Hangman',
    icon: Icons.abc,
    gradient: const LinearGradient(
      colors: [Color(0xFF00C9FF), Color(0xFF92FE9D)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    supportsNetwork: true,
    supportsSinglePhone: true,
    singlePhoneScreenBuilder: () =>
        const HangmanScreen(isNetworked: false),
    networkScreenBuilder: ({required bool isHost}) =>
        HangmanScreen(isNetworked: true, isHost: isHost),
  ),

  GameDefinition(
    id: 'dots',
    displayName: 'Dots & Boxes',
    icon: Icons.timeline,
    gradient: const LinearGradient(
      colors: [Color(0xFF8A2387), Color(0xFFE94057)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    supportsNetwork: false, // Has dual-sub issue, deferred to Phase 3
    supportsSinglePhone: true,
    singlePhoneScreenBuilder: () => const DotsScreen(),
  ),

  GameDefinition(
    id: 'reversi',
    displayName: 'Reversi',
    icon: Icons.tonality,
    gradient: const LinearGradient(
      colors: [Color(0xFF232526), Color(0xFF414345)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    supportsNetwork: false, // TCP integration is a TODO stub
    supportsSinglePhone: true,
    singlePhoneScreenBuilder: () => const ReversiScreen(),
  ),

  GameDefinition(
    id: 'spyfall',
    displayName: 'Spyfall',
    icon: Icons.search,
    gradient: const LinearGradient(
      colors: [Color(0xFF141E30), Color(0xFF243B55)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    supportsNetwork: false, // Has mode flag but no TCP integration
    supportsSinglePhone: true,
    singlePhoneScreenBuilder: () => const SpyfallScreen(),
  ),

  GameDefinition(
    id: 'tod',
    displayName: 'Truth or Dare',
    icon: Icons.local_fire_department,
    gradient: const LinearGradient(
      colors: [Color(0xFFFF416C), Color(0xFFFF4B2B)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    supportsNetwork: false, // Has mode flag but dual-sub issue, deferred
    supportsSinglePhone: true,
    singlePhoneScreenBuilder: () => const TodScreen(),
  ),

  // ── Coming Soon ──────────────────────────────────────────
  const GameDefinition(
    id: 'trivia',
    displayName: 'Trivia',
    icon: Icons.quiz,
    gradient: LinearGradient(
      colors: [Color(0xFF424242), Color(0xFF212121)],
    ),
    isComingSoon: true,
  ),

  const GameDefinition(
    id: 'memory',
    displayName: 'Memory',
    icon: Icons.dashboard,
    gradient: LinearGradient(
      colors: [Color(0xFF424242), Color(0xFF212121)],
    ),
    isComingSoon: true,
  ),
];

// ─────────────────────────────────────────────────────────────
// Lookup helper
// ─────────────────────────────────────────────────────────────

/// Finds a game by its displayName (used for routing from lobby screens).
/// Returns null if not found.
GameDefinition? findGameByName(String displayName) {
  try {
    return gameRegistry.firstWhere((g) => g.displayName == displayName);
  } catch (_) {
    return null;
  }
}
