import 'package:flutter/foundation.dart';

// ─────────────────────────────────────────────────────────────
// Enums
// ─────────────────────────────────────────────────────────────

/// Standard playing card suits.
enum Suit { spades, hearts, diamonds, clubs }

/// Overall phase of the rummy game.
enum RummyPhase { waitingToStart, dealing, playing, gameOver }

/// Sub-phase within a single player's turn.
enum TurnPhase { draw, discard }

// ─────────────────────────────────────────────────────────────
// PlayingCard
// ─────────────────────────────────────────────────────────────

/// Represents one card in a 108-card Indian Rummy deck
/// (2 standard decks of 52 + 4 printed jokers).
///
/// Printed jokers: [suit] is null, [rank] is 0.
/// Normal cards : [rank] 1 (Ace) through 13 (King).
@immutable
class PlayingCard {
  /// Null only for printed jokers.
  final Suit? suit;

  /// 0 = Printed Joker, 1 = Ace, 2–10, 11 = Jack, 12 = Queen, 13 = King.
  final int rank;

  /// Disambiguates duplicate cards across two decks (0 or 1).
  final int deckIndex;

  const PlayingCard({this.suit, required this.rank, this.deckIndex = 0});

  // ── Derived properties ──

  bool get isPrintedJoker => rank == 0;
  bool get isRed => suit == Suit.hearts || suit == Suit.diamonds;

  /// Whether this card acts as a joker (printed OR wild).
  bool isJoker(PlayingCard? wildCard) =>
      isPrintedJoker || isWildJoker(wildCard);

  /// Whether this card matches the wild-joker rank.
  bool isWildJoker(PlayingCard? wildCard) {
    if (wildCard == null || isPrintedJoker) return false;
    return rank == wildCard.rank;
  }

  /// Display symbol for rank: A, 2-10, J, Q, K, ★.
  String get rankSymbol {
    if (isPrintedJoker) return '★';
    return switch (rank) {
      1 => 'A',
      11 => 'J',
      12 => 'Q',
      13 => 'K',
      _ => '$rank',
    };
  }

  /// Display symbol for suit: ♠ ♥ ♦ ♣.
  String get suitSymbol => switch (suit) {
    Suit.spades => '♠',
    Suit.hearts => '♥',
    Suit.diamonds => '♦',
    Suit.clubs => '♣',
    null => '',
  };

  // ── Serialization ──

  Map<String, dynamic> toJson() => {
    's': suit?.index,
    'r': rank,
    'd': deckIndex,
  };

  factory PlayingCard.fromJson(Map<String, dynamic> json) => PlayingCard(
    suit: json['s'] != null ? Suit.values[json['s'] as int] : null,
    rank: json['r'] as int,
    deckIndex: (json['d'] as int?) ?? 0,
  );

  // ── Equality ──

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlayingCard &&
          suit == other.suit &&
          rank == other.rank &&
          deckIndex == other.deckIndex;

  @override
  int get hashCode => Object.hash(suit, rank, deckIndex);

  @override
  String toString() =>
      isPrintedJoker ? 'Joker#$deckIndex' : '$rankSymbol$suitSymbol#$deckIndex';
}

// ─────────────────────────────────────────────────────────────
// RummyGameState
// ─────────────────────────────────────────────────────────────

/// Complete, immutable snapshot of a rummy game.
@immutable
class RummyGameState {
  final List<PlayingCard> player1Hand;
  final List<PlayingCard> player2Hand;
  final List<PlayingCard> stockPile;
  final List<PlayingCard> discardPile;

  /// The randomly-drawn wild-joker card (all same-rank cards become jokers).
  final PlayingCard? wildJokerCard;

  /// 0 = Player 1, 1 = Player 2.
  final int currentPlayer;
  final TurnPhase turnPhase;
  final RummyPhase gamePhase;

  /// Index of the winning player (null while game is ongoing).
  final int? winner;

  /// Human-readable status / feedback message.
  final String message;

  /// Index of the card the current player has selected in their hand.
  final int? selectedCardIndex;

  /// True when we need to show the "pass the phone" screen between turns
  /// (single-phone pass-and-play mode only).
  final bool showPassScreen;

  /// Player names for display.
  final String player1Name;
  final String player2Name;

  const RummyGameState({
    this.player1Hand = const [],
    this.player2Hand = const [],
    this.stockPile = const [],
    this.discardPile = const [],
    this.wildJokerCard,
    this.currentPlayer = 0,
    this.turnPhase = TurnPhase.draw,
    this.gamePhase = RummyPhase.waitingToStart,
    this.winner,
    this.message = 'Tap Start to deal cards',
    this.selectedCardIndex,
    this.showPassScreen = false,
    this.player1Name = 'Player 1',
    this.player2Name = 'Player 2',
  });

  factory RummyGameState.initial() => const RummyGameState();

  // ── Convenience getters ──

  List<PlayingCard> get currentHand =>
      currentPlayer == 0 ? player1Hand : player2Hand;

  List<PlayingCard> get opponentHand =>
      currentPlayer == 0 ? player2Hand : player1Hand;

  String get currentPlayerName =>
      currentPlayer == 0 ? player1Name : player2Name;

  String get opponentPlayerName =>
      currentPlayer == 0 ? player2Name : player1Name;

  PlayingCard? get topDiscard =>
      discardPile.isNotEmpty ? discardPile.last : null;

  bool get canDraw => turnPhase == TurnPhase.draw && gamePhase == RummyPhase.playing;
  bool get canDiscard => turnPhase == TurnPhase.discard && gamePhase == RummyPhase.playing;

  // ── copyWith ──

  RummyGameState copyWith({
    List<PlayingCard>? player1Hand,
    List<PlayingCard>? player2Hand,
    List<PlayingCard>? stockPile,
    List<PlayingCard>? discardPile,
    PlayingCard? wildJokerCard,
    bool clearWildJoker = false,
    int? currentPlayer,
    TurnPhase? turnPhase,
    RummyPhase? gamePhase,
    int? winner,
    bool clearWinner = false,
    String? message,
    int? selectedCardIndex,
    bool clearSelectedCard = false,
    bool? showPassScreen,
    String? player1Name,
    String? player2Name,
  }) {
    return RummyGameState(
      player1Hand: player1Hand ?? this.player1Hand,
      player2Hand: player2Hand ?? this.player2Hand,
      stockPile: stockPile ?? this.stockPile,
      discardPile: discardPile ?? this.discardPile,
      wildJokerCard: clearWildJoker ? null : (wildJokerCard ?? this.wildJokerCard),
      currentPlayer: currentPlayer ?? this.currentPlayer,
      turnPhase: turnPhase ?? this.turnPhase,
      gamePhase: gamePhase ?? this.gamePhase,
      winner: clearWinner ? null : (winner ?? this.winner),
      message: message ?? this.message,
      selectedCardIndex: clearSelectedCard ? null : (selectedCardIndex ?? this.selectedCardIndex),
      showPassScreen: showPassScreen ?? this.showPassScreen,
      player1Name: player1Name ?? this.player1Name,
      player2Name: player2Name ?? this.player2Name,
    );
  }

  // ── JSON serialization ──

  Map<String, dynamic> toJson() => {
    'p1': player1Hand.map((c) => c.toJson()).toList(),
    'p2': player2Hand.map((c) => c.toJson()).toList(),
    'st': stockPile.map((c) => c.toJson()).toList(),
    'dp': discardPile.map((c) => c.toJson()).toList(),
    'wj': wildJokerCard?.toJson(),
    'cp': currentPlayer,
    'tp': turnPhase.index,
    'gp': gamePhase.index,
    'w': winner,
    'msg': message,
    'sel': selectedCardIndex,
    'ps': showPassScreen,
    'p1n': player1Name,
    'p2n': player2Name,
  };

  factory RummyGameState.fromJson(Map<String, dynamic> json) {
    List<PlayingCard> parseCards(dynamic list) =>
        (list as List).map((e) => PlayingCard.fromJson(e as Map<String, dynamic>)).toList();

    return RummyGameState(
      player1Hand: parseCards(json['p1']),
      player2Hand: parseCards(json['p2']),
      stockPile: parseCards(json['st']),
      discardPile: parseCards(json['dp']),
      wildJokerCard: json['wj'] != null
          ? PlayingCard.fromJson(json['wj'] as Map<String, dynamic>)
          : null,
      currentPlayer: json['cp'] as int,
      turnPhase: TurnPhase.values[json['tp'] as int],
      gamePhase: RummyPhase.values[json['gp'] as int],
      winner: json['w'] as int?,
      message: json['msg'] as String? ?? '',
      selectedCardIndex: json['sel'] as int?,
      showPassScreen: json['ps'] as bool? ?? false,
      player1Name: json['p1n'] as String? ?? 'Player 1',
      player2Name: json['p2n'] as String? ?? 'Player 2',
    );
  }
}
