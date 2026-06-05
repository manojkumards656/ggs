import 'dart:async';
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ──────────────────────────────────────────────────────────────
// Word bank — 60 common, easy-to-draw words
// ──────────────────────────────────────────────────────────────
const List<String> _wordBank = [
  'apple', 'banana', 'cat', 'dog', 'elephant', 'fish', 'guitar',
  'house', 'ice cream', 'jellyfish', 'kite', 'lion', 'moon',
  'noodles', 'octopus', 'pizza', 'queen', 'rainbow', 'sun',
  'tree', 'umbrella', 'volcano', 'whale', 'xylophone', 'yacht',
  'zebra', 'airplane', 'bicycle', 'camera', 'dragon', 'egg',
  'flower', 'ghost', 'hat', 'island', 'jacket', 'key', 'lamp',
  'mountain', 'nest', 'owl', 'penguin', 'robot', 'star',
  'train', 'unicorn', 'violin', 'waterfall', 'rocket', 'sword',
  'castle', 'diamond', 'feather', 'globe', 'heart', 'snowflake',
  'butterfly', 'mushroom', 'tornado', 'treasure',
];

// ──────────────────────────────────────────────────────────────
// Game phase enum
// ──────────────────────────────────────────────────────────────
enum DrawGuessPhase {
  /// Show the word to the drawer privately
  wordReveal,

  /// Drawer is drawing
  drawing,

  /// Guesser types their guess
  guessing,

  /// Show round result
  result,

  /// Game over — all rounds complete
  gameOver,
}

// ──────────────────────────────────────────────────────────────
// State model
// ──────────────────────────────────────────────────────────────
class DrawGuessState {
  final DrawGuessPhase phase;
  final int currentRound;
  final int maxRounds; // total rounds (each player draws maxRounds/2 times)
  final int remainingSeconds;
  final String currentWord;

  /// Index 0 = Player 1, Index 1 = Player 2
  final int drawerIndex;
  final List<String> playerNames;
  final List<int> scores;

  /// Number of guess attempts remaining for current guesser
  final int guessAttemptsLeft;

  /// Whether the guesser got it right this round
  final bool guessedCorrectly;

  /// Last wrong guess (to display feedback)
  final String? lastWrongGuess;

  const DrawGuessState({
    this.phase = DrawGuessPhase.wordReveal,
    this.currentRound = 1,
    this.maxRounds = 6,
    this.remainingSeconds = 60,
    this.currentWord = '',
    this.drawerIndex = 0,
    this.playerNames = const ['Player 1', 'Player 2'],
    this.scores = const [0, 0],
    this.guessAttemptsLeft = 3,
    this.guessedCorrectly = false,
    this.lastWrongGuess,
  });

  int get guesserIndex => drawerIndex == 0 ? 1 : 0;
  String get drawerName => playerNames[drawerIndex];
  String get guesserName => playerNames[guesserIndex];

  DrawGuessState copyWith({
    DrawGuessPhase? phase,
    int? currentRound,
    int? maxRounds,
    int? remainingSeconds,
    String? currentWord,
    int? drawerIndex,
    List<String>? playerNames,
    List<int>? scores,
    int? guessAttemptsLeft,
    bool? guessedCorrectly,
    String? lastWrongGuess,
  }) {
    return DrawGuessState(
      phase: phase ?? this.phase,
      currentRound: currentRound ?? this.currentRound,
      maxRounds: maxRounds ?? this.maxRounds,
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      currentWord: currentWord ?? this.currentWord,
      drawerIndex: drawerIndex ?? this.drawerIndex,
      playerNames: playerNames ?? this.playerNames,
      scores: scores ?? this.scores,
      guessAttemptsLeft: guessAttemptsLeft ?? this.guessAttemptsLeft,
      guessedCorrectly: guessedCorrectly ?? this.guessedCorrectly,
      lastWrongGuess: lastWrongGuess,
    );
  }
}

// ──────────────────────────────────────────────────────────────
// Notifier
// ──────────────────────────────────────────────────────────────
class DrawGuessNotifier extends Notifier<DrawGuessState> {
  Timer? _timer;
  final _rng = Random();
  final List<String> _usedWords = [];

  @override
  DrawGuessState build() {
    ref.onDispose(() => _timer?.cancel());
    return const DrawGuessState();
  }

  String _pickWord() {
    final available = _wordBank.where((w) => !_usedWords.contains(w)).toList();
    if (available.isEmpty) {
      _usedWords.clear();
      return _wordBank[_rng.nextInt(_wordBank.length)];
    }
    final word = available[_rng.nextInt(available.length)];
    _usedWords.add(word);
    return word;
  }

  /// Called once at the start to configure player names
  void initGame({String player1 = 'Player 1', String player2 = 'Player 2'}) {
    _usedWords.clear();
    _timer?.cancel();
    final word = _pickWord();
    state = DrawGuessState(
      phase: DrawGuessPhase.wordReveal,
      currentRound: 1,
      maxRounds: 6,
      remainingSeconds: 60,
      currentWord: word,
      drawerIndex: 0,
      playerNames: [player1, player2],
      scores: [0, 0],
      guessAttemptsLeft: 3,
      guessedCorrectly: false,
    );
  }

  /// Drawer has seen the word — start the drawing phase
  void startDrawing() {
    state = state.copyWith(
      phase: DrawGuessPhase.drawing,
      remainingSeconds: 60,
    );
    _startTimer();
  }

  /// Drawer finishes (or timer runs out) — move to guessing
  void finishDrawing() {
    _timer?.cancel();
    state = state.copyWith(
      phase: DrawGuessPhase.guessing,
      guessAttemptsLeft: 3,
      guessedCorrectly: false,
      lastWrongGuess: null,
    );
  }

  /// Guesser submits a guess
  void submitGuess(String guess) {
    if (state.phase != DrawGuessPhase.guessing) return;

    final correct =
        guess.trim().toLowerCase() == state.currentWord.toLowerCase();

    if (correct) {
      // Award points based on remaining attempts
      final bonus = state.guessAttemptsLeft * 100; // 300/200/100
      final timeBonus = state.remainingSeconds * 5;
      final newScores = List<int>.from(state.scores);
      newScores[state.guesserIndex] += bonus + timeBonus;
      // Drawer also gets a smaller bonus
      newScores[state.drawerIndex] += 50;

      state = state.copyWith(
        phase: DrawGuessPhase.result,
        guessedCorrectly: true,
        scores: newScores,
      );
    } else {
      final attemptsLeft = state.guessAttemptsLeft - 1;
      if (attemptsLeft <= 0) {
        // Out of attempts
        state = state.copyWith(
          phase: DrawGuessPhase.result,
          guessedCorrectly: false,
          guessAttemptsLeft: 0,
          lastWrongGuess: guess.trim(),
        );
      } else {
        state = state.copyWith(
          guessAttemptsLeft: attemptsLeft,
          lastWrongGuess: guess.trim(),
        );
      }
    }
  }

  /// Move to the next round (or game over)
  void nextRound() {
    if (state.currentRound >= state.maxRounds) {
      state = state.copyWith(phase: DrawGuessPhase.gameOver);
      return;
    }

    final newDrawer = state.guesserIndex; // swap drawer and guesser
    final word = _pickWord();
    state = state.copyWith(
      phase: DrawGuessPhase.wordReveal,
      currentRound: state.currentRound + 1,
      drawerIndex: newDrawer,
      currentWord: word,
      remainingSeconds: 60,
      guessAttemptsLeft: 3,
      guessedCorrectly: false,
      lastWrongGuess: null,
    );
  }

  void resetGame() {
    _timer?.cancel();
    _usedWords.clear();
    state = const DrawGuessState();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (state.remainingSeconds > 0) {
        state = state.copyWith(remainingSeconds: state.remainingSeconds - 1);
      } else {
        finishDrawing();
      }
    });
  }
}

final drawGuessProvider =
    NotifierProvider<DrawGuessNotifier, DrawGuessState>(() {
  return DrawGuessNotifier();
});
