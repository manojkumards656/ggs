import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/spyfall_state.dart';

const List<String> _locations = [
  'Airplane',
  'Bank',
  'Beach',
  'Casino',
  'Hospital',
  'Hotel',
  'Pirate Ship',
  'Space Station',
  'Submarine',
  'Supermarket',
  'Theatre',
  'Restaurant',
  'School',
  'Police Station',
  'Military Base'
];

class SpyfallNotifier extends Notifier<SpyfallState> {
  final _random = Random();

  @override
  SpyfallState build() {
    return const SpyfallState();
  }

  void initializeLocalGame(List<String> players) {
    if (players.isEmpty) return;
    
    final location = _locations[_random.nextInt(_locations.length)];
    final spyIndex = _random.nextInt(players.length);
    final Map<String, String> roles = {};
    
    for (int i = 0; i < players.length; i++) {
      roles[players[i]] = (i == spyIndex) ? 'Spy' : location;
    }

    state = SpyfallState(
      mode: GameMode.localPassAndPlay,
      players: players,
      playerRoles: roles,
      location: location,
      currentPlayerIndex: 0,
      isRoleRevealed: false,
    );
  }

  void initializeNetworkGame(String localPlayerId, List<String> playerIds) {
    if (playerIds.isEmpty) return;
    
    // In a real network setup, the host would generate this and broadcast the state.
    // Assuming this is called by the host and state is synced, or called to setup locally.
    final location = _locations[_random.nextInt(_locations.length)];
    final spyIndex = _random.nextInt(playerIds.length);
    final Map<String, String> roles = {};
    
    for (int i = 0; i < playerIds.length; i++) {
      roles[playerIds[i]] = (i == spyIndex) ? 'Spy' : location;
    }

    state = SpyfallState(
      mode: GameMode.networked,
      players: playerIds,
      playerRoles: roles,
      location: location,
      localPlayerId: localPlayerId,
      isRoleRevealed: false,
    );
  }

  // Allow host to set the state directly from network sync
  void syncState(SpyfallState newState) {
    state = newState;
  }

  void toggleReveal() {
    state = state.copyWith(isRoleRevealed: !state.isRoleRevealed);
  }

  void nextPlayer() {
    if (state.mode == GameMode.localPassAndPlay) {
      if (state.currentPlayerIndex < state.players.length - 1) {
        state = state.copyWith(
          currentPlayerIndex: state.currentPlayerIndex + 1,
          isRoleRevealed: false,
        );
      } else {
        // Game starts
        state = state.copyWith(
          isGameOver: true, 
          isRoleRevealed: false,
        );
      }
    }
  }

  void restartLocalGame() {
    initializeLocalGame(state.players);
  }
}

final spyfallProvider = NotifierProvider<SpyfallNotifier, SpyfallState>(() {
  return SpyfallNotifier();
});
