import 'package:flutter/material.dart';

// ── Game Screen Imports ─────────────────────────────────────
// Each game has exactly ONE import here. Adding a game = add 1 import + 1 entry.
// Removing a game = delete 1 import + 1 entry + delete the game folder.
import 'package:pocket_party/features/game_chess/presentation/screens/chess_screen.dart';
import 'package:pocket_party/features/game_rummy/presentation/screens/rummy_screen.dart';


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
  // ── Add your GameDefinition entries here ──
  GameDefinition(
    id: 'chess',
    displayName: 'Chess',
    icon: Icons.person,
    gradient: const LinearGradient(
      colors: [Color(0xFF6B11FF), Color(0xFF00F2FE)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    supportsNetwork: true,
    supportsSinglePhone: true,
    singlePhoneScreenBuilder: () => const ChessScreen(isNetworked: false),
    networkScreenBuilder: ({required bool isHost}) =>
        ChessScreen(isNetworked: true, isHost: isHost),
  ),
  GameDefinition(
    id: 'rummy',
    displayName: 'Indian Rummy',
    icon: Icons.style,
    gradient: const LinearGradient(
      colors: [Color(0xFFFF8008), Color(0xFFFFC837)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    supportsNetwork: true,
    supportsSinglePhone: true,
    singlePhoneScreenBuilder: () => const RummyScreen(isNetworked: false),
    networkScreenBuilder: ({required bool isHost}) =>
        RummyScreen(isNetworked: true, isHost: isHost),
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
