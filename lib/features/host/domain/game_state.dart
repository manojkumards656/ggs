enum GameStatus { lobby, playing, roundEnd, gameOver }

class GameState {
  final GameStatus status;
  final int currentRound;
  final int maxRounds;
  final int remainingSeconds;
  final String? currentWord;
  final String? currentDrawerId;

  const GameState({
    this.status = GameStatus.lobby,
    this.currentRound = 1,
    this.maxRounds = 3,
    this.remainingSeconds = 60,
    this.currentWord,
    this.currentDrawerId,
  });

  GameState copyWith({
    GameStatus? status,
    int? currentRound,
    int? maxRounds,
    int? remainingSeconds,
    String? currentWord,
    String? currentDrawerId,
  }) {
    return GameState(
      status: status ?? this.status,
      currentRound: currentRound ?? this.currentRound,
      maxRounds: maxRounds ?? this.maxRounds,
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      currentWord: currentWord ?? this.currentWord,
      currentDrawerId: currentDrawerId ?? this.currentDrawerId,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'status': status.name,
      'currentRound': currentRound,
      'maxRounds': maxRounds,
      'remainingSeconds': remainingSeconds,
      'currentWord': currentWord,
      'currentDrawerId': currentDrawerId,
    };
  }

  factory GameState.fromJson(Map<String, dynamic> json) {
    return GameState(
      status: GameStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => GameStatus.lobby,
      ),
      currentRound: json['currentRound'] as int? ?? 1,
      maxRounds: json['maxRounds'] as int? ?? 3,
      remainingSeconds: json['remainingSeconds'] as int? ?? 60,
      currentWord: json['currentWord'] as String?,
      currentDrawerId: json['currentDrawerId'] as String?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GameState &&
          runtimeType == other.runtimeType &&
          status == other.status &&
          currentRound == other.currentRound &&
          maxRounds == other.maxRounds &&
          remainingSeconds == other.remainingSeconds &&
          currentWord == other.currentWord &&
          currentDrawerId == other.currentDrawerId;

  @override
  int get hashCode =>
      status.hashCode ^
      currentRound.hashCode ^
      maxRounds.hashCode ^
      remainingSeconds.hashCode ^
      currentWord.hashCode ^
      currentDrawerId.hashCode;
}
