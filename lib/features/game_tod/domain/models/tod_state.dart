enum TodMode {
  networked,
  passAndPlay,
}

enum PromptType {
  truth,
  dare,
  none,
}

class TodState {
  final TodMode mode;
  final String activePlayerId;
  final String activePlayerName;
  final PromptType currentPromptType;
  final String currentPromptText;
  final bool isSpinning;

  const TodState({
    this.mode = TodMode.passAndPlay,
    this.activePlayerId = '',
    this.activePlayerName = '',
    this.currentPromptType = PromptType.none,
    this.currentPromptText = '',
    this.isSpinning = false,
  });

  TodState copyWith({
    TodMode? mode,
    String? activePlayerId,
    String? activePlayerName,
    PromptType? currentPromptType,
    String? currentPromptText,
    bool? isSpinning,
  }) {
    return TodState(
      mode: mode ?? this.mode,
      activePlayerId: activePlayerId ?? this.activePlayerId,
      activePlayerName: activePlayerName ?? this.activePlayerName,
      currentPromptType: currentPromptType ?? this.currentPromptType,
      currentPromptText: currentPromptText ?? this.currentPromptText,
      isSpinning: isSpinning ?? this.isSpinning,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'mode': mode.name,
      'activePlayerId': activePlayerId,
      'activePlayerName': activePlayerName,
      'currentPromptType': currentPromptType.name,
      'currentPromptText': currentPromptText,
      'isSpinning': isSpinning,
    };
  }

  factory TodState.fromJson(Map<String, dynamic> json) {
    return TodState(
      mode: TodMode.values.firstWhere((e) => e.name == json['mode'], orElse: () => TodMode.passAndPlay),
      activePlayerId: json['activePlayerId'] ?? '',
      activePlayerName: json['activePlayerName'] ?? '',
      currentPromptType: PromptType.values.firstWhere((e) => e.name == json['currentPromptType'], orElse: () => PromptType.none),
      currentPromptText: json['currentPromptText'] ?? '',
      isSpinning: json['isSpinning'] ?? false,
    );
  }
}
