import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/player.dart';

class LobbyNotifier extends Notifier<List<Player>> {
  @override
  List<Player> build() {
    return [];
  }

  void resetLobby() {
    state = [];
  }

  void addPlayer(Player player) {
    if (!state.any((p) => p.id == player.id)) {
      state = [...state, player];
    }
  }

  void setPlayers(List<Player> players) {
    state = players;
  }

  void removePlayer(String playerId) {
    state = state.where((p) => p.id != playerId).toList();
  }

  void updateScore(String playerId, int points) {
    state = state.map((p) {
      if (p.id == playerId) {
        return p.copyWith(score: p.score + points);
      }
      return p;
    }).toList();
  }

  void setDrawer(String drawerId) {
    state = state.map((p) {
      return p.copyWith(
        isDrawing: p.id == drawerId,
        hasGuessedCorrectly: false, // Reset guesses for new round
      );
    }).toList();
  }

  void markGuessedCorrectly(String playerId) {
    state = state.map((p) {
      if (p.id == playerId) {
        return p.copyWith(hasGuessedCorrectly: true);
      }
      return p;
    }).toList();
  }
}

final lobbyProvider = NotifierProvider<LobbyNotifier, List<Player>>(() {
  return LobbyNotifier();
});
