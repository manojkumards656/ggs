import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/hangman_state.dart';

class HangmanNotifier extends Notifier<HangmanState> {
  @override
  HangmanState build() {
    return HangmanState(secretWord: '', guessedLetters: const []);
  }

  void setWord(String word) {
    state = state.copyWith(secretWord: word.toUpperCase(), guessedLetters: const []);
  }

  void guessLetter(String letter) {
    if (state.isGameOver || state.isGameWon) return;
    
    final upperLetter = letter.toUpperCase();
    if (!state.guessedLetters.contains(upperLetter)) {
      state = state.copyWith(
        guessedLetters: [...state.guessedLetters, upperLetter],
      );
    }
  }

  void setState(HangmanState newState) {
    state = newState;
  }
  
  void reset() {
    state = HangmanState(secretWord: '', guessedLetters: const []);
  }
}

final hangmanProvider = NotifierProvider<HangmanNotifier, HangmanState>(() {
  return HangmanNotifier();
});
