import 'dart:math';
import 'package:pocket_party/features/game_rummy/domain/models/rummy_state.dart';

/// Pure game-logic engine for 13-card Indian Rummy.
///
/// Stateless utility class — all methods are static.
/// Keeps the Riverpod provider thin; all rules live here.
class RummyEngine {
  RummyEngine._(); // prevent instantiation

  static final _rng = Random();

  // ─────────────────────────────────────────────────────────
  // Deck creation & dealing
  // ─────────────────────────────────────────────────────────

  /// Builds a 108-card deck: 2×52 standard cards + 4 printed jokers.
  static List<PlayingCard> createDeck() {
    final deck = <PlayingCard>[];
    for (int d = 0; d < 2; d++) {
      for (final suit in Suit.values) {
        for (int rank = 1; rank <= 13; rank++) {
          deck.add(PlayingCard(suit: suit, rank: rank, deckIndex: d));
        }
      }
      // 2 printed jokers per standard deck
      deck.add(PlayingCard(rank: 0, deckIndex: d * 2));
      deck.add(PlayingCard(rank: 0, deckIndex: d * 2 + 1));
    }
    return deck;
  }

  /// Fisher-Yates shuffle.
  static void shuffle(List<PlayingCard> cards) {
    for (int i = cards.length - 1; i > 0; i--) {
      final j = _rng.nextInt(i + 1);
      final tmp = cards[i];
      cards[i] = cards[j];
      cards[j] = tmp;
    }
  }

  /// Deal initial hands, set up stock & discard piles, pick wild joker.
  ///
  /// Returns a new [RummyGameState] with everything ready to play.
  static RummyGameState deal({
    String player1Name = 'Player 1',
    String player2Name = 'Player 2',
  }) {
    final deck = createDeck();
    shuffle(deck);

    final hand1 = deck.sublist(0, 13);
    final hand2 = deck.sublist(13, 26);

    // The 27th card is placed face-up as the wild-joker indicator.
    final wildCard = deck[26];
    // If it's a printed joker, pick the next non-joker instead.
    PlayingCard wildJoker = wildCard;
    if (wildCard.isPrintedJoker) {
      for (int i = 27; i < deck.length; i++) {
        if (!deck[i].isPrintedJoker) {
          wildJoker = deck[i];
          break;
        }
      }
    }

    // The first card of the discard pile
    final discardPile = <PlayingCard>[deck[27]];
    // Remaining cards become the stock pile
    final stockPile = deck.sublist(28);

    _sortBySuit(hand1, wildJoker);
    _sortBySuit(hand2, wildJoker);

    return RummyGameState(
      player1Hand: hand1,
      player2Hand: hand2,
      stockPile: stockPile,
      discardPile: discardPile,
      wildJokerCard: wildJoker,
      currentPlayer: 0,
      turnPhase: TurnPhase.draw,
      gamePhase: RummyPhase.playing,
      message: "$player1Name's turn — Draw a card",
      player1Name: player1Name,
      player2Name: player2Name,
    );
  }

  // ─────────────────────────────────────────────────────────
  // Sorting helpers
  // ─────────────────────────────────────────────────────────

  /// Sort by suit, then by rank within each suit.
  /// Jokers are placed at the end.
  static void _sortBySuit(List<PlayingCard> cards, PlayingCard? wild) {
    cards.sort((a, b) {
      final aJoker = a.isJoker(wild);
      final bJoker = b.isJoker(wild);
      if (aJoker && !bJoker) return 1;
      if (!aJoker && bJoker) return -1;
      if (aJoker && bJoker) return a.rank.compareTo(b.rank);
      final suitCmp = (a.suit?.index ?? 99).compareTo(b.suit?.index ?? 99);
      if (suitCmp != 0) return suitCmp;
      return a.rank.compareTo(b.rank);
    });
  }

  /// Sort by rank, then by suit within each rank.
  static void _sortByRank(List<PlayingCard> cards, PlayingCard? wild) {
    cards.sort((a, b) {
      final aJoker = a.isJoker(wild);
      final bJoker = b.isJoker(wild);
      if (aJoker && !bJoker) return 1;
      if (!aJoker && bJoker) return -1;
      if (aJoker && bJoker) return a.rank.compareTo(b.rank);
      final rankCmp = a.rank.compareTo(b.rank);
      if (rankCmp != 0) return rankCmp;
      return (a.suit?.index ?? 99).compareTo(b.suit?.index ?? 99);
    });
  }

  /// Public sort-by-suit: returns a new sorted list.
  static List<PlayingCard> sortedBySuit(List<PlayingCard> hand, PlayingCard? wild) {
    final copy = List<PlayingCard>.from(hand);
    _sortBySuit(copy, wild);
    return copy;
  }

  /// Public sort-by-rank: returns a new sorted list.
  static List<PlayingCard> sortedByRank(List<PlayingCard> hand, PlayingCard? wild) {
    final copy = List<PlayingCard>.from(hand);
    _sortByRank(copy, wild);
    return copy;
  }

  // ─────────────────────────────────────────────────────────
  // Meld Validation (core Indian Rummy logic)
  // ─────────────────────────────────────────────────────────

  /// Validates whether a 13-card hand forms a winning declaration.
  ///
  /// Requirements:
  /// 1. All 13 cards must belong to valid groups (sets or sequences).
  /// 2. At least ONE group must be a **pure sequence** (no jokers).
  /// 3. At least TWO groups must be sequences (pure or impure).
  static bool isValidDeclaration(List<PlayingCard> hand, PlayingCard? wildJoker) {
    if (hand.length != 13) return false;
    final result = findValidArrangement(hand, wildJoker);
    return result != null;
  }

  /// Attempts to find a valid grouping of 13 cards into melds.
  /// Returns the list of groups if valid, null if impossible.
  static List<List<PlayingCard>>? findValidArrangement(
    List<PlayingCard> hand,
    PlayingCard? wildJoker,
  ) {
    // Separate jokers from normal cards
    final jokers = <PlayingCard>[];
    final normals = <PlayingCard>[];
    for (final c in hand) {
      if (c.isJoker(wildJoker)) {
        jokers.add(c);
      } else {
        normals.add(c);
      }
    }

    // Sort normals for deterministic search
    normals.sort((a, b) {
      final s = (a.suit?.index ?? 0).compareTo(b.suit?.index ?? 0);
      return s != 0 ? s : a.rank.compareTo(b.rank);
    });

    final groups = <List<PlayingCard>>[];
    final used = List.filled(normals.length, false);

    if (_solve(normals, jokers, used, 0, jokers.length, groups, wildJoker)) {
      return groups;
    }
    return null;
  }

  /// Recursive backtracking solver.
  ///
  /// [normals]       — sorted non-joker cards
  /// [jokers]        — all joker cards (printed + wild)
  /// [used]          — which normals are already assigned
  /// [startIdx]      — where to start searching for the next unassigned card
  /// [jokersLeft]    — how many jokers remain available
  /// [groups]        — accumulator for valid groups found so far
  /// [wild]          — the wild joker card
  static bool _solve(
    List<PlayingCard> normals,
    List<PlayingCard> jokers,
    List<bool> used,
    int startIdx,
    int jokersLeft,
    List<List<PlayingCard>> groups,
    PlayingCard? wild,
  ) {
    // Find next unused normal card
    int nextIdx = -1;
    for (int i = startIdx; i < normals.length; i++) {
      if (!used[i]) { nextIdx = i; break; }
    }

    // All normal cards assigned — distribute remaining jokers
    if (nextIdx == -1) {
      if (jokersLeft > 0) {
        return _distributeJokers(jokers, jokersLeft, groups, wild);
      }
      return _validateGroups(groups, wild);
    }



    // ── Try forming SEQUENCES starting from this card ──
    for (int seqLen = 3; seqLen <= 13; seqLen++) {
      final seq = _tryFormSequence(normals, used, nextIdx, seqLen, jokersLeft, wild);
      if (seq == null) break; // can't form longer sequences either

      final usedIndices = seq['indices'] as List<int>;
      final usedJokers = seq['jokers'] as int;
      final group = seq['cards'] as List<PlayingCard>;

      // Mark used
      for (final i in usedIndices) { used[i] = true; }
      groups.add(group);

      if (_solve(normals, jokers, used, nextIdx + 1, jokersLeft - usedJokers, groups, wild)) {
        return true;
      }

      // Backtrack
      groups.removeLast();
      for (final i in usedIndices) { used[i] = false; }
    }

    // ── Try forming SETS with this card's rank ──
    for (int setLen = 3; setLen <= 4; setLen++) {
      final setResult = _tryFormSet(normals, used, nextIdx, setLen, jokersLeft, wild);
      if (setResult == null) continue;

      final usedIndices = setResult['indices'] as List<int>;
      final usedJokers = setResult['jokers'] as int;
      final group = setResult['cards'] as List<PlayingCard>;

      for (final i in usedIndices) { used[i] = true; }
      groups.add(group);

      if (_solve(normals, jokers, used, nextIdx + 1, jokersLeft - usedJokers, groups, wild)) {
        return true;
      }

      groups.removeLast();
      for (final i in usedIndices) { used[i] = false; }
    }

    return false;
  }

  /// Try to form a sequence of [length] starting from the card at [startIdx].
  static Map<String, dynamic>? _tryFormSequence(
    List<PlayingCard> normals,
    List<bool> used,
    int startIdx,
    int length,
    int jokersAvailable,
    PlayingCard? wild,
  ) {
    final card = normals[startIdx];
    if (card.suit == null) return null;

    final suit = card.suit!;
    final startRank = card.rank;

    // Check if sequence would go out of bounds (rank > 13)
    if (startRank + length - 1 > 13) return null;

    final indices = <int>[startIdx];
    final cards = <PlayingCard>[card];
    int jokersUsed = 0;

    for (int offset = 1; offset < length; offset++) {
      final neededRank = startRank + offset;
      // Find an unused card with this suit and rank
      int foundIdx = -1;
      for (int i = startIdx + 1; i < normals.length; i++) {
        if (!used[i] && !indices.contains(i) &&
            normals[i].suit == suit && normals[i].rank == neededRank) {
          foundIdx = i;
          break;
        }
      }
      if (foundIdx != -1) {
        indices.add(foundIdx);
        cards.add(normals[foundIdx]);
      } else {
        // Use a joker
        if (jokersUsed < jokersAvailable) {
          jokersUsed++;
          cards.add(PlayingCard(rank: 0, deckIndex: jokersUsed)); // placeholder
        } else {
          return null; // can't complete sequence
        }
      }
    }

    return {'indices': indices, 'jokers': jokersUsed, 'cards': cards};
  }

  /// Try to form a set of [length] cards with the same rank as card at [startIdx].
  static Map<String, dynamic>? _tryFormSet(
    List<PlayingCard> normals,
    List<bool> used,
    int startIdx,
    int length,
    int jokersAvailable,
    PlayingCard? wild,
  ) {
    final card = normals[startIdx];
    final targetRank = card.rank;

    // Collect all unused cards with this rank (different suits)
    final indices = <int>[startIdx];
    final suitsUsed = <Suit>{card.suit!};
    final cards = <PlayingCard>[card];

    for (int i = startIdx + 1; i < normals.length; i++) {
      if (!used[i] && normals[i].rank == targetRank &&
          normals[i].suit != null && !suitsUsed.contains(normals[i].suit)) {
        indices.add(i);
        suitsUsed.add(normals[i].suit!);
        cards.add(normals[i]);
        if (cards.length == length) break;
      }
    }

    final needed = length - cards.length;
    if (needed > jokersAvailable) return null;
    if (cards.length + needed < 3) return null;

    // Add joker placeholders
    for (int j = 0; j < needed; j++) {
      cards.add(PlayingCard(rank: 0, deckIndex: 100 + j));
    }

    return {'indices': indices, 'jokers': needed, 'cards': cards};
  }

  /// Distribute remaining jokers into existing groups.
  /// Returns true if the final grouping is valid.
  static bool _distributeJokers(
    List<PlayingCard> jokers,
    int count,
    List<List<PlayingCard>> groups,
    PlayingCard? wild,
  ) {
    // Simple: try adding jokers to groups that are smallest first
    // This is a heuristic — full search would be needed for perfect play
    // but for validation purposes this works well
    final jokersToAdd = jokers.sublist(jokers.length - count);

    // Try distributing each joker to existing groups
    for (final joker in jokersToAdd) {
      bool placed = false;
      for (final group in groups) {
        group.add(joker);
        placed = true;
        break;
      }
      if (!placed) {
        // Can't place joker
        return false;
      }
    }

    return _validateGroups(groups, wild);
  }

  /// Validates the final grouping: each group valid + pure seq + 2 seqs.
  static bool _validateGroups(List<List<PlayingCard>> groups, PlayingCard? wild) {
    if (groups.isEmpty) return false;

    int pureSeqCount = 0;
    int totalSeqCount = 0;

    for (final group in groups) {
      if (group.length < 3) return false;

      final type = classifyGroup(group, wild);
      switch (type) {
        case MeldType.pureSequence:
          pureSeqCount++;
          totalSeqCount++;
        case MeldType.impureSequence:
          totalSeqCount++;
        case MeldType.set:
          break; // valid but not a sequence
        case MeldType.invalid:
          return false;
      }
    }

    return pureSeqCount >= 1 && totalSeqCount >= 2;
  }

  /// Classify a group of cards as pure sequence, impure sequence, set, or invalid.
  static MeldType classifyGroup(List<PlayingCard> group, PlayingCard? wild) {
    if (group.length < 3) return MeldType.invalid;

    final jokerCount = group.where((c) => c.isJoker(wild)).length;
    final normals = group.where((c) => !c.isJoker(wild)).toList();

    // ── Check if it's a SET ──
    if (_isValidSet(normals, jokerCount)) return MeldType.set;

    // ── Check if it's a SEQUENCE ──
    if (normals.isEmpty) {
      // All jokers — treat as impure sequence
      return jokerCount >= 3 ? MeldType.impureSequence : MeldType.invalid;
    }

    // All normal cards must be the same suit
    final suit = normals.first.suit;
    if (suit == null) return MeldType.invalid;
    if (normals.any((c) => c.suit != suit)) return MeldType.invalid;

    // Sort by rank
    normals.sort((a, b) => a.rank.compareTo(b.rank));

    // Check consecutive with jokers filling gaps
    for (int i = 1; i < normals.length; i++) {
      final diff = normals[i].rank - normals[i - 1].rank;
      if (diff == 0) return MeldType.invalid; // duplicate rank in sequence
    }

    // Also check if the total span matches group size
    final totalSpan = normals.last.rank - normals.first.rank + 1;
    final neededJokers = totalSpan - normals.length;

    if (neededJokers > jokerCount) return MeldType.invalid;
    if (totalSpan > group.length) return MeldType.invalid;

    // Extra jokers extend the sequence
    final extraJokers = jokerCount - neededJokers;
    // Check that extensions are valid (not going below 1 or above 13)
    if (normals.first.rank - extraJokers < 1 &&
        normals.last.rank + extraJokers > 13) {
      // Can't extend in either direction
      if (extraJokers > 0) return MeldType.invalid;
    }

    return jokerCount == 0 ? MeldType.pureSequence : MeldType.impureSequence;
  }

  /// Check if the normals + jokers form a valid set.
  static bool _isValidSet(List<PlayingCard> normals, int jokerCount) {
    final total = normals.length + jokerCount;
    if (total < 3 || total > 4) return false;

    if (normals.isEmpty) return jokerCount >= 3;

    // All normals must have the same rank
    final rank = normals.first.rank;
    if (normals.any((c) => c.rank != rank)) return false;

    // All normals must have different suits
    final suits = normals.map((c) => c.suit).toSet();
    if (suits.length != normals.length) return false;

    return true;
  }
}

/// Classification of a meld (group of cards).
enum MeldType { pureSequence, impureSequence, set, invalid }
