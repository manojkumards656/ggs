import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocket_party/features/game_rummy/domain/models/rummy_state.dart';
import 'package:pocket_party/features/game_rummy/domain/engine/rummy_engine.dart';

/// Global provider for the rummy game state.
final rummyProvider =
    NotifierProvider<RummyNotifier, RummyGameState>(() => RummyNotifier());

/// Manages all rummy game state transitions.
///
/// Every mutation returns a new immutable [RummyGameState] via copyWith.
/// The engine ([RummyEngine]) holds the pure rules; this notifier
/// orchestrates them and owns the state lifecycle.
class RummyNotifier extends Notifier<RummyGameState> {
  @override
  RummyGameState build() => RummyGameState.initial();

  // ─────────────────────────────────────────────────────────
  // Game lifecycle
  // ─────────────────────────────────────────────────────────

  /// Deal cards and begin a new game.
  void startGame({
    String player1Name = 'Player 1',
    String player2Name = 'Player 2',
  }) {
    state = RummyEngine.deal(
      player1Name: player1Name,
      player2Name: player2Name,
    );
  }

  /// Reset everything back to initial.
  void resetGame() {
    state = RummyGameState.initial();
  }

  /// Replace the entire state (used for network sync from host).
  void syncState(RummyGameState newState) {
    state = newState;
  }

  // ─────────────────────────────────────────────────────────
  // Draw phase
  // ─────────────────────────────────────────────────────────

  /// Draw the top card from the stock pile.
  bool drawFromStock() {
    if (!state.canDraw) return false;
    if (state.stockPile.isEmpty) {
      // Reshuffle discard pile into stock (keep top card)
      if (state.discardPile.length <= 1) {
        state = state.copyWith(message: 'No cards left to draw!');
        return false;
      }
      final topDiscard = state.discardPile.last;
      final reshuffled = List<PlayingCard>.from(
        state.discardPile.sublist(0, state.discardPile.length - 1),
      );
      RummyEngine.shuffle(reshuffled);
      state = state.copyWith(
        stockPile: reshuffled,
        discardPile: [topDiscard],
      );
    }

    final newStock = List<PlayingCard>.from(state.stockPile);
    final drawn = newStock.removeLast();
    final newHand = List<PlayingCard>.from(state.currentHand)..add(drawn);

    state = _updateCurrentHand(newHand).copyWith(
      stockPile: newStock,
      turnPhase: TurnPhase.discard,
      message: '${state.currentPlayerName} drew from stock — Discard a card',
      clearSelectedCard: true,
    );
    return true;
  }

  /// Draw the top card from the discard pile.
  bool drawFromDiscard() {
    if (!state.canDraw) return false;
    if (state.discardPile.isEmpty) return false;

    final newDiscard = List<PlayingCard>.from(state.discardPile);
    final drawn = newDiscard.removeLast();
    final newHand = List<PlayingCard>.from(state.currentHand)..add(drawn);

    state = _updateCurrentHand(newHand).copyWith(
      discardPile: newDiscard,
      turnPhase: TurnPhase.discard,
      message: '${state.currentPlayerName} picked from discard — Discard a card',
      clearSelectedCard: true,
    );
    return true;
  }

  // ─────────────────────────────────────────────────────────
  // Discard phase
  // ─────────────────────────────────────────────────────────

  /// Discard the card at [index] from the current player's hand.
  bool discardCard(int index) {
    if (!state.canDiscard) return false;
    final hand = List<PlayingCard>.from(state.currentHand);
    if (index < 0 || index >= hand.length) return false;

    final discarded = hand.removeAt(index);
    final newDiscard = List<PlayingCard>.from(state.discardPile)..add(discarded);

    final nextPlayer = 1 - state.currentPlayer;
    final nextName = nextPlayer == 0 ? state.player1Name : state.player2Name;

    state = _updateCurrentHand(hand).copyWith(
      discardPile: newDiscard,
      currentPlayer: nextPlayer,
      turnPhase: TurnPhase.draw,
      message: "$nextName's turn — Draw a card",
      clearSelectedCard: true,
      showPassScreen: true, // show pass screen in single-phone mode
    );
    return true;
  }

  // ─────────────────────────────────────────────────────────
  // Card selection & arrangement
  // ─────────────────────────────────────────────────────────

  /// Toggle selection of a card at [index].
  void selectCard(int index) {
    if (state.selectedCardIndex == index) {
      state = state.copyWith(clearSelectedCard: true);
    } else if (state.selectedCardIndex != null) {
      // Swap the two cards
      swapCards(state.selectedCardIndex!, index);
    } else {
      state = state.copyWith(selectedCardIndex: index);
    }
  }

  /// Swap two cards in the current player's hand.
  void swapCards(int from, int to) {
    final hand = List<PlayingCard>.from(state.currentHand);
    if (from < 0 || from >= hand.length || to < 0 || to >= hand.length) return;

    final temp = hand[from];
    hand[from] = hand[to];
    hand[to] = temp;

    state = _updateCurrentHand(hand).copyWith(clearSelectedCard: true);
  }

  /// Move a card from [from] to [to] in the current player's hand.
  /// Used by drag-and-drop reordering.
  void moveCard(int from, int to) {
    final hand = List<PlayingCard>.from(state.currentHand);
    if (from < 0 || from >= hand.length || to < 0 || to >= hand.length) return;
    if (from == to) return;

    final card = hand.removeAt(from);
    hand.insert(to, card);

    state = _updateCurrentHand(hand).copyWith(clearSelectedCard: true);
  }

  /// Sort current player's hand by suit, then rank.
  void sortBySuit() {
    final sorted = RummyEngine.sortedBySuit(state.currentHand, state.wildJokerCard);
    state = _updateCurrentHand(sorted).copyWith(clearSelectedCard: true);
  }

  /// Sort current player's hand by rank, then suit.
  void sortByRank() {
    final sorted = RummyEngine.sortedByRank(state.currentHand, state.wildJokerCard);
    state = _updateCurrentHand(sorted).copyWith(clearSelectedCard: true);
  }

  // ─────────────────────────────────────────────────────────
  // Declaration
  // ─────────────────────────────────────────────────────────

  /// Attempt to declare a win for the current player.
  ///
  /// Returns true if the declaration is valid and the player wins.
  bool declareWin() {
    if (state.gamePhase != RummyPhase.playing) return false;
    // Must have exactly 13 cards (i.e., in discard phase with 14 OR already discarded)
    final hand = state.currentHand;

    if (hand.length == 14) {
      state = state.copyWith(
        message: 'Discard a card before declaring!',
      );
      return false;
    }

    if (hand.length != 13) return false;

    final valid = RummyEngine.isValidDeclaration(hand, state.wildJokerCard);

    if (valid) {
      state = state.copyWith(
        winner: state.currentPlayer,
        gamePhase: RummyPhase.gameOver,
        message: '${state.currentPlayerName} wins! 🎉',
        showPassScreen: false,
      );
      return true;
    } else {
      state = state.copyWith(
        message: 'Invalid declaration! Need at least 1 pure sequence & 2 total sequences.',
      );
      return false;
    }
  }

  // ─────────────────────────────────────────────────────────
  // Pass-and-play helpers
  // ─────────────────────────────────────────────────────────

  /// Dismiss the pass screen to show the next player's hand.
  void dismissPassScreen() {
    state = state.copyWith(showPassScreen: false);
  }

  // ─────────────────────────────────────────────────────────
  // Private helpers
  // ─────────────────────────────────────────────────────────

  /// Update the current player's hand in the state.
  RummyGameState _updateCurrentHand(List<PlayingCard> newHand) {
    if (state.currentPlayer == 0) {
      return state.copyWith(player1Hand: newHand);
    } else {
      return state.copyWith(player2Hand: newHand);
    }
  }
}
