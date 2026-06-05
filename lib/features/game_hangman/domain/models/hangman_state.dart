
class HangmanState {
  final String secretWord;
  final List<String> guessedLetters;
  final int maxLives;

  HangmanState({
    required this.secretWord,
    required this.guessedLetters,
    this.maxLives = 6,
  });

  int get remainingLives {
    int incorrectGuesses = guessedLetters
        .where((letter) => !secretWord.toUpperCase().contains(letter.toUpperCase()))
        .length;
    return maxLives - incorrectGuesses;
  }
  
  bool get isGameOver => remainingLives <= 0;
  
  bool get isGameWon {
    if (secretWord.isEmpty) return false;
    return secretWord.toUpperCase().split('').every((char) {
      if (char == ' ') return true;
      return guessedLetters.contains(char);
    });
  }

  HangmanState copyWith({
    String? secretWord,
    List<String>? guessedLetters,
    int? maxLives,
  }) {
    return HangmanState(
      secretWord: secretWord ?? this.secretWord,
      guessedLetters: guessedLetters ?? this.guessedLetters,
      maxLives: maxLives ?? this.maxLives,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'secretWord': secretWord,
      'guessedLetters': guessedLetters,
      'maxLives': maxLives,
    };
  }

  factory HangmanState.fromJson(Map<String, dynamic> json) {
    return HangmanState(
      secretWord: json['secretWord'] ?? '',
      guessedLetters: List<String>.from(json['guessedLetters'] ?? []),
      maxLives: json['maxLives'] ?? 6,
    );
  }
}
