import 'youknow_card.dart';

enum YouKnowStatus {
  lobby,
  playing,
  revealingTurn, // Turn change screen for pass-and-play to conceal hands
  gameOver;
}

class YouKnowPlayer {
  final String id;
  final String name;
  final List<YouKnowCard> cards;
  final bool hasDeclaredYouKnow;

  const YouKnowPlayer({
    required this.id,
    required this.name,
    this.cards = const [],
    this.hasDeclaredYouKnow = false,
  });

  YouKnowPlayer copyWith({
    String? id,
    String? name,
    List<YouKnowCard>? cards,
    bool? hasDeclaredYouKnow,
  }) {
    return YouKnowPlayer(
      id: id ?? this.id,
      name: name ?? this.name,
      cards: cards ?? this.cards,
      hasDeclaredYouKnow: hasDeclaredYouKnow ?? this.hasDeclaredYouKnow,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'cards': cards.map((c) => c.toJson()).toList(),
      'hasDeclaredYouKnow': hasDeclaredYouKnow,
    };
  }

  factory YouKnowPlayer.fromJson(Map<String, dynamic> json) {
    return YouKnowPlayer(
      id: json['id'] as String,
      name: json['name'] as String,
      cards: (json['cards'] as List)
          .map((c) => YouKnowCard.fromJson(c as Map<String, dynamic>))
          .toList(),
      hasDeclaredYouKnow: json['hasDeclaredYouKnow'] as bool? ?? false,
    );
  }
}

class YouKnowState {
  final List<YouKnowPlayer> players;
  final List<YouKnowCard> discardPile;
  final List<YouKnowCard> deck; // Kept in memory, usually hidden from clients
  final YouKnowColor? activeWildColor;
  final int currentPlayerIndex;
  final bool isClockwise;
  final YouKnowStatus status;
  final String? winnerName;
  final String lastActionMessage;
  final bool isNetworked;
  
  // Vulnerability tracker for forgetting to declare "Youknow!"
  // Stores the playerId of any player who has exactly 1 card but has not declared "YouKnow".
  final String? vulnerablePlayerId;

  const YouKnowState({
    this.players = const [],
    this.discardPile = const [],
    this.deck = const [],
    this.activeWildColor,
    this.currentPlayerIndex = 0,
    this.isClockwise = true,
    this.status = YouKnowStatus.lobby,
    this.winnerName,
    this.lastActionMessage = 'Welcome to YouKnow! Deal cards to start.',
    this.isNetworked = false,
    this.vulnerablePlayerId,
  });

  YouKnowPlayer get currentPlayer => players[currentPlayerIndex];

  YouKnowCard get topDiscardCard => discardPile.last;

  YouKnowState copyWith({
    List<YouKnowPlayer>? players,
    List<YouKnowCard>? discardPile,
    List<YouKnowCard>? deck,
    YouKnowColor? activeWildColor,
    bool clearActiveWildColor = false,
    int? currentPlayerIndex,
    bool? isClockwise,
    YouKnowStatus? status,
    String? winnerName,
    String? lastActionMessage,
    bool? isNetworked,
    String? vulnerablePlayerId,
  }) {
    return YouKnowState(
      players: players ?? this.players,
      discardPile: discardPile ?? this.discardPile,
      deck: deck ?? this.deck,
      activeWildColor: clearActiveWildColor ? null : (activeWildColor ?? this.activeWildColor),
      currentPlayerIndex: currentPlayerIndex ?? this.currentPlayerIndex,
      isClockwise: isClockwise ?? this.isClockwise,
      status: status ?? this.status,
      winnerName: winnerName ?? this.winnerName,
      lastActionMessage: lastActionMessage ?? this.lastActionMessage,
      isNetworked: isNetworked ?? this.isNetworked,
      vulnerablePlayerId: vulnerablePlayerId, // If omitted, resets to null
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'players': players.map((p) => p.toJson()).toList(),
      'discardPile': discardPile.map((c) => c.toJson()).toList(),
      // Clients don't need the entire deck, but we serialize it for the host state representation.
      'deck': deck.map((c) => c.toJson()).toList(),
      'activeWildColor': activeWildColor?.name,
      'currentPlayerIndex': currentPlayerIndex,
      'isClockwise': isClockwise,
      'status': status.name,
      'winnerName': winnerName,
      'lastActionMessage': lastActionMessage,
      'isNetworked': isNetworked,
      'vulnerablePlayerId': vulnerablePlayerId,
    };
  }

  factory YouKnowState.fromJson(Map<String, dynamic> json) {
    return YouKnowState(
      players: (json['players'] as List)
          .map((p) => YouKnowPlayer.fromJson(p as Map<String, dynamic>))
          .toList(),
      discardPile: (json['discardPile'] as List)
          .map((c) => YouKnowCard.fromJson(c as Map<String, dynamic>))
          .toList(),
      deck: json['deck'] != null
          ? (json['deck'] as List)
              .map((c) => YouKnowCard.fromJson(c as Map<String, dynamic>))
              .toList()
          : const [],
      activeWildColor: json['activeWildColor'] != null
          ? YouKnowColor.values.firstWhere((e) => e.name == json['activeWildColor'])
          : null,
      currentPlayerIndex: json['currentPlayerIndex'] as int? ?? 0,
      isClockwise: json['isClockwise'] as bool? ?? true,
      status: YouKnowStatus.values.firstWhere((e) => e.name == json['status'], orElse: () => YouKnowStatus.lobby),
      winnerName: json['winnerName'] as String?,
      lastActionMessage: json['lastActionMessage'] as String? ?? '',
      isNetworked: json['isNetworked'] as bool? ?? false,
      vulnerablePlayerId: json['vulnerablePlayerId'] as String?,
    );
  }
}
