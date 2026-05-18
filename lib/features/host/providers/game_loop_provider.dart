import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/game_state.dart';
import 'lobby_provider.dart';

class GameLoopNotifier extends Notifier<GameState> {
  Timer? _timer;

  @override
  GameState build() {
    // Make sure to clean up the timer if the provider is destroyed
    ref.onDispose(() {
      _timer?.cancel();
    });
    return const GameState();
  }

  void setState(GameState newState) {
    state = newState;
  }

  void startGame(String firstDrawerId, String word) {
    state = state.copyWith(
      status: GameStatus.playing,
      currentRound: 1,
      remainingSeconds: 60,
      currentWord: word,
      currentDrawerId: firstDrawerId,
    );
    ref.read(lobbyProvider.notifier).setDrawer(firstDrawerId);
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (state.remainingSeconds > 0) {
        state = state.copyWith(remainingSeconds: state.remainingSeconds - 1);
      } else {
        _endRound();
      }
    });
  }

  void _endRound() {
    _timer?.cancel();
    state = state.copyWith(status: GameStatus.roundEnd);
    // At this point, the UI can show round results, and the host can trigger the next round
  }

  void startNextRound(String nextDrawerId, String word) {
    if (state.currentRound >= state.maxRounds) {
      state = state.copyWith(status: GameStatus.gameOver);
    } else {
      state = state.copyWith(
        status: GameStatus.playing,
        currentRound: state.currentRound + 1,
        remainingSeconds: 60,
        currentWord: word,
        currentDrawerId: nextDrawerId,
      );
      ref.read(lobbyProvider.notifier).setDrawer(nextDrawerId);
      _startTimer();
    }
  }

  void handleCorrectGuess(String playerId) {
    // Award points based on remaining time (e.g., max 600 points)
    final points = state.remainingSeconds * 10;
    ref.read(lobbyProvider.notifier).updateScore(playerId, points);
    ref.read(lobbyProvider.notifier).markGuessedCorrectly(playerId);

    // Check if everyone has guessed correctly
    final players = ref.read(lobbyProvider);
    final guessers = players.where((p) => !p.isDrawing);
    
    // If all guessers have guessed correctly, end the round early
    if (guessers.isNotEmpty && guessers.every((p) => p.hasGuessedCorrectly)) {
      _endRound();
    }
  }
}

final gameLoopProvider = NotifierProvider<GameLoopNotifier, GameState>(() {
  return GameLoopNotifier();
});
