class Player {
  final String id;
  final String name;
  final int score;
  final bool isHost;
  final bool isDrawing;
  final bool hasGuessedCorrectly;

  const Player({
    required this.id,
    required this.name,
    this.score = 0,
    this.isHost = false,
    this.isDrawing = false,
    this.hasGuessedCorrectly = false,
  });

  Player copyWith({
    String? id,
    String? name,
    int? score,
    bool? isHost,
    bool? isDrawing,
    bool? hasGuessedCorrectly,
  }) {
    return Player(
      id: id ?? this.id,
      name: name ?? this.name,
      score: score ?? this.score,
      isHost: isHost ?? this.isHost,
      isDrawing: isDrawing ?? this.isDrawing,
      hasGuessedCorrectly: hasGuessedCorrectly ?? this.hasGuessedCorrectly,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'score': score,
      'isHost': isHost,
      'isDrawing': isDrawing,
      'hasGuessedCorrectly': hasGuessedCorrectly,
    };
  }

  factory Player.fromJson(Map<String, dynamic> json) {
    return Player(
      id: json['id'] as String,
      name: json['name'] as String,
      score: json['score'] as int? ?? 0,
      isHost: json['isHost'] as bool? ?? false,
      isDrawing: json['isDrawing'] as bool? ?? false,
      hasGuessedCorrectly: json['hasGuessedCorrectly'] as bool? ?? false,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Player &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          score == other.score &&
          isHost == other.isHost &&
          isDrawing == other.isDrawing &&
          hasGuessedCorrectly == other.hasGuessedCorrectly;

  @override
  int get hashCode =>
      id.hashCode ^
      name.hashCode ^
      score.hashCode ^
      isHost.hashCode ^
      isDrawing.hashCode ^
      hasGuessedCorrectly.hashCode;
}
