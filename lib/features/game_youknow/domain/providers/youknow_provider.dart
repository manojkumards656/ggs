import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/youknow_card.dart';
import '../models/youknow_state.dart';

class YouKnowStateNotifier extends Notifier<YouKnowState> {
  @override
  YouKnowState build() {
    return const YouKnowState();
  }

  YouKnowState get gameState => state;

  final _uuid = const Uuid();
  final _random = Random();

  /// Resets and initializes a new game with the given list of player names.
  void initGame(List<Map<String, String>> playerInfo, {required bool isNetworked}) {
    // Generate a fresh deck of 108 cards
    final List<YouKnowCard> newDeck = [];
    
    // Numbered & Action Cards for Red, Green, Blue, Yellow
    for (final color in [YouKnowColor.red, YouKnowColor.green, YouKnowColor.blue, YouKnowColor.yellow]) {
      // One 0 card
      newDeck.add(YouKnowCard(id: _uuid.v4(), color: color, value: YouKnowValue.n0));
      
      // Two of each 1-9
      for (int i = 1; i <= 9; i++) {
        final val = YouKnowValue.values[i]; // n1 to n9 match index 1 to 9
        newDeck.add(YouKnowCard(id: _uuid.v4(), color: color, value: val));
        newDeck.add(YouKnowCard(id: _uuid.v4(), color: color, value: val));
      }
      
      // Two Skips, two Reverses, two Draw Twos
      for (int i = 0; i < 2; i++) {
        newDeck.add(YouKnowCard(id: _uuid.v4(), color: color, value: YouKnowValue.skip));
        newDeck.add(YouKnowCard(id: _uuid.v4(), color: color, value: YouKnowValue.reverse));
        newDeck.add(YouKnowCard(id: _uuid.v4(), color: color, value: YouKnowValue.drawTwo));
      }
    }
    
    // Four Wilds, four Wild Draw Fours
    for (int i = 0; i < 4; i++) {
      newDeck.add(YouKnowCard(id: _uuid.v4(), color: YouKnowColor.wild, value: YouKnowValue.wild));
      newDeck.add(YouKnowCard(id: _uuid.v4(), color: YouKnowColor.wild, value: YouKnowValue.wildDrawFour));
    }

    // Shuffle the deck
    newDeck.shuffle(_random);

    // Deal 7 cards to each player
    final List<YouKnowPlayer> dealtPlayers = [];
    for (final info in playerInfo) {
      final id = info['id'] ?? _uuid.v4();
      final name = info['name'] ?? 'Player';
      final List<YouKnowCard> hand = [];
      for (int i = 0; i < 7; i++) {
        if (newDeck.isNotEmpty) {
          hand.add(newDeck.removeLast());
        }
      }
      dealtPlayers.add(YouKnowPlayer(id: id, name: name, cards: hand));
    }

    // Setup discard pile with a non-wild top card to begin
    final List<YouKnowCard> discard = [];
    YouKnowCard startingCard = newDeck.removeLast();
    while (startingCard.isWild) {
      // Put it back in deck and reshuffle to avoid wild starting card complexity
      newDeck.insert(0, startingCard);
      newDeck.shuffle(_random);
      startingCard = newDeck.removeLast();
    }
    discard.add(startingCard);

    // Apply starting card action if applicable
    int startIndex = 0;
    bool startingClockwise = true;
    String actionMsg = 'Game started! ${dealtPlayers[startIndex].name}\'s turn.';

    if (startingCard.value == YouKnowValue.skip) {
      startIndex = 1 % dealtPlayers.length;
      actionMsg = '${dealtPlayers[0].name} was Skipped! ${dealtPlayers[startIndex].name}\'s turn.';
    } else if (startingCard.value == YouKnowValue.reverse) {
      startingClockwise = false;
      startIndex = dealtPlayers.length - 1; // reverses first turn
      actionMsg = 'Direction Reversed! ${dealtPlayers[startIndex].name}\'s turn.';
    } else if (startingCard.value == YouKnowValue.drawTwo) {
      // First player draws 2 cards and misses turn
      final firstPlayer = dealtPlayers[0];
      final newHand = List<YouKnowCard>.from(firstPlayer.cards);
      for (int i = 0; i < 2; i++) {
        if (newDeck.isNotEmpty) newHand.add(newDeck.removeLast());
      }
      dealtPlayers[0] = firstPlayer.copyWith(cards: newHand);
      startIndex = 1 % dealtPlayers.length;
      actionMsg = '${firstPlayer.name} drew 2 cards and was Skipped! ${dealtPlayers[startIndex].name}\'s turn.';
    }

    state = YouKnowState(
      players: dealtPlayers,
      discardPile: discard,
      deck: newDeck,
      currentPlayerIndex: startIndex,
      isClockwise: startingClockwise,
      status: isNetworked ? YouKnowStatus.playing : YouKnowStatus.revealingTurn,
      activeWildColor: null,
      winnerName: null,
      lastActionMessage: actionMsg,
      isNetworked: isNetworked,
      vulnerablePlayerId: null,
    );
  }

  /// Sets state directly (used by clients in network mode).
  void setState(YouKnowState newState) {
    state = newState;
  }

  /// Allows active player to declare "YouKnow!" (Uno) before playing their card.
  void declareYouKnow(String playerId) {
    state = state.copyWith(
      players: state.players.map((p) {
        if (p.id == playerId) {
          return p.copyWith(hasDeclaredYouKnow: true);
        }
        return p;
      }).toList(),
      lastActionMessage: '${state.players.firstWhere((p) => p.id == playerId).name} shouted "YOUKNOW!"',
    );
  }

  /// Catches a player who has exactly 1 card left but forgot to declare "YouKnow!".
  /// Adds 2 penalty cards to their hand.
  void catchPlayer(String catcherId) {
    final vulnerableId = state.vulnerablePlayerId;
    if (vulnerableId == null) return;

    final catcher = state.players.firstWhere((p) => p.id == catcherId, orElse: () => state.players[0]);
    final victimIndex = state.players.indexWhere((p) => p.id == vulnerableId);
    if (victimIndex == -1) return;

    final victim = state.players[victimIndex];
    final updatedHand = List<YouKnowCard>.from(victim.cards);
    
    // Draw 2 penalty cards
    final List<YouKnowCard> newDeck = List.from(state.deck);
    final List<YouKnowCard> newDiscard = List.from(state.discardPile);
    
    for (int i = 0; i < 2; i++) {
      final card = _drawCardFromDeck(newDeck, newDiscard);
      if (card != null) updatedHand.add(card);
    }

    final updatedPlayers = List<YouKnowPlayer>.from(state.players);
    updatedPlayers[victimIndex] = victim.copyWith(
      cards: updatedHand,
      hasDeclaredYouKnow: false,
    );

    state = state.copyWith(
      players: updatedPlayers,
      deck: newDeck,
      discardPile: newDiscard,
      vulnerablePlayerId: null, // Clear vulnerability
      lastActionMessage: '${catcher.name} caught ${victim.name} not declaring "YouKnow!" +2 cards penalty.',
    );
  }

  /// Active player draws a card.
  void drawCard(String playerId) {
    if (state.status == YouKnowStatus.gameOver) return;
    final activePlayer = state.currentPlayer;
    if (activePlayer.id != playerId) return;

    // Clear vulnerability of previous players as a new action has occurred
    String? vulnerableId = state.vulnerablePlayerId;
    if (vulnerableId != null) {
      vulnerableId = null;
    }

    final List<YouKnowCard> newDeck = List.from(state.deck);
    final List<YouKnowCard> newDiscard = List.from(state.discardPile);

    final card = _drawCardFromDeck(newDeck, newDiscard);
    if (card == null) return;

    final updatedHand = List<YouKnowCard>.from(activePlayer.cards)..add(card);

    final updatedPlayers = state.players.map((p) {
      if (p.id == playerId) {
        // Drawing cards cancels any early YouKnow declaration
        return p.copyWith(cards: updatedHand, hasDeclaredYouKnow: false);
      }
      return p;
    }).toList();

    // In standard Uno, after drawing, the card is playable or we pass.
    // To make it easy, we check if the drawn card is playable.
    // If it is playable, we let the player decide (we don't force immediate turn end).
    // If it is NOT playable, we automatically pass their turn to keep game speed snappy.
    final bool isPlayable = card.isPlayableOn(state.topDiscardCard, state.activeWildColor);

    if (isPlayable) {
      state = state.copyWith(
        players: updatedPlayers,
        deck: newDeck,
        discardPile: newDiscard,
        vulnerablePlayerId: vulnerableId,
        lastActionMessage: '${activePlayer.name} drew a card (playable).',
      );
    } else {
      // Auto-pass turn
      final tempState = state.copyWith(
        players: updatedPlayers,
        deck: newDeck,
        discardPile: newDiscard,
        vulnerablePlayerId: vulnerableId,
        lastActionMessage: '${activePlayer.name} drew a card and passed.',
      );
      _advanceTurn(tempState);
    }
  }

  /// If a player draws a card and decides to pass instead of playing it.
  void passTurn(String playerId) {
    if (state.status == YouKnowStatus.gameOver) return;
    final activePlayer = state.currentPlayer;
    if (activePlayer.id != playerId) return;

    state = state.copyWith(
      lastActionMessage: '${activePlayer.name} passed.',
    );
    _advanceTurn(state);
  }

  /// Active player plays a valid card.
  void playCard(String playerId, String cardId, {YouKnowColor? chosenWildColor}) {
    if (state.status == YouKnowStatus.gameOver) return;
    
    final activePlayer = state.currentPlayer;
    if (activePlayer.id != playerId) return;

    final cardIndex = activePlayer.cards.indexWhere((c) => c.id == cardId);
    if (cardIndex == -1) return;

    final card = activePlayer.cards[cardIndex];
    if (!card.isPlayableOn(state.topDiscardCard, state.activeWildColor)) return;

    // Wild Draw Four can only be played if no other cards match the active color
    if (card.value == YouKnowValue.wildDrawFour) {
      final activeColor = state.activeWildColor ?? state.topDiscardCard.color;
      final hasMatchingColor = activePlayer.cards.any((c) =>
        c.id != cardId && !c.isWild && c.color == activeColor
      );
      if (hasMatchingColor) return; // Illegal play
    }

    // Check if the card is wild and requires color selection
    if (card.isWild && chosenWildColor == null) {
      // Return and wait for color picker popup, which will call playCard again with color.
      return;
    }

    // Clear vulnerability of previous players as a new action has occurred
    String? vulnerableId = state.vulnerablePlayerId;
    if (vulnerableId != null) {
      vulnerableId = null;
    }

    // Remove card from player hand
    final updatedHand = List<YouKnowCard>.from(activePlayer.cards)..removeAt(cardIndex);

    // Check declaration rules
    final bool hadDeclared = activePlayer.hasDeclaredYouKnow;
    final int newHandSize = updatedHand.length;
    
    if (newHandSize == 1 && !hadDeclared) {
      // Player is now vulnerable to being caught!
      vulnerableId = activePlayer.id;
    }

    final updatedPlayers = state.players.map((p) {
      if (p.id == playerId) {
        return p.copyWith(
          cards: updatedHand,
          // Reset declaration flag for their next hand transition
          hasDeclaredYouKnow: false,
        );
      }
      return p;
    }).toList();

    final newDiscard = List<YouKnowCard>.from(state.discardPile)..add(card);
    
    String actionMsg = '${activePlayer.name} played ${card.color.displayName} ${card.value.displayName}';
    if (card.isWild && chosenWildColor != null) {
      actionMsg = '${activePlayer.name} played ${card.value.displayName} (Color set to ${chosenWildColor.displayName})';
    }

    // Check game over
    if (newHandSize == 0) {
      state = state.copyWith(
        players: updatedPlayers,
        discardPile: newDiscard,
        status: YouKnowStatus.gameOver,
        winnerName: activePlayer.name,
        lastActionMessage: '${activePlayer.name} wins the game!',
        vulnerablePlayerId: null,
      );
      return;
    }

    // Build temporary state to compute next turn indices
    var nextState = state.copyWith(
      players: updatedPlayers,
      discardPile: newDiscard,
      activeWildColor: card.isWild ? chosenWildColor : null,
      clearActiveWildColor: !card.isWild,
      lastActionMessage: actionMsg,
      vulnerablePlayerId: vulnerableId,
    );

    // Apply card effects
    int stepsToAdvance = 1;
    final int numPlayers = nextState.players.length;

    switch (card.value) {
      case YouKnowValue.skip:
        stepsToAdvance = 2;
        final skippedPlayer = _getPlayerAtSteps(nextState, 1);
        nextState = nextState.copyWith(
          lastActionMessage: '$actionMsg. ${skippedPlayer.name} was Skipped!',
        );
        break;

      case YouKnowValue.reverse:
        if (numPlayers == 2) {
          // In 2-player games, Reverse behaves exactly like a Skip card
          stepsToAdvance = 2;
          final skippedPlayer = _getPlayerAtSteps(nextState, 1);
          nextState = nextState.copyWith(
            lastActionMessage: '$actionMsg. ${skippedPlayer.name} was Skipped!',
          );
        } else {
          nextState = nextState.copyWith(
            isClockwise: !nextState.isClockwise,
            lastActionMessage: '$actionMsg. Direction reversed!',
          );
        }
        break;

      case YouKnowValue.drawTwo:
        // Next player draws 2 cards and skips turn
        final victimIndex = _getPlayerIndexAtSteps(nextState, 1);
        final victim = nextState.players[victimIndex];
        final victimHand = List<YouKnowCard>.from(victim.cards);
        
        final List<YouKnowCard> tempDeck = List.from(nextState.deck);
        final List<YouKnowCard> tempDiscard = List.from(nextState.discardPile);
        
        for (int i = 0; i < 2; i++) {
          final c = _drawCardFromDeck(tempDeck, tempDiscard);
          if (c != null) victimHand.add(c);
        }

        final playersWithDrawnCards = List<YouKnowPlayer>.from(nextState.players);
        playersWithDrawnCards[victimIndex] = victim.copyWith(cards: victimHand, hasDeclaredYouKnow: false);

        nextState = nextState.copyWith(
          players: playersWithDrawnCards,
          deck: tempDeck,
          discardPile: tempDiscard,
          lastActionMessage: '$actionMsg. ${victim.name} drew 2 cards and was Skipped!',
        );
        stepsToAdvance = 2; // skip their turn
        break;

      case YouKnowValue.wildDrawFour:
        // Next player draws 4 cards and skips turn
        final victimIndex = _getPlayerIndexAtSteps(nextState, 1);
        final victim = nextState.players[victimIndex];
        final victimHand = List<YouKnowCard>.from(victim.cards);
        
        final List<YouKnowCard> tempDeck = List.from(nextState.deck);
        final List<YouKnowCard> tempDiscard = List.from(nextState.discardPile);
        
        for (int i = 0; i < 4; i++) {
          final c = _drawCardFromDeck(tempDeck, tempDiscard);
          if (c != null) victimHand.add(c);
        }

        final playersWithDrawnCards = List<YouKnowPlayer>.from(nextState.players);
        playersWithDrawnCards[victimIndex] = victim.copyWith(cards: victimHand, hasDeclaredYouKnow: false);

        nextState = nextState.copyWith(
          players: playersWithDrawnCards,
          deck: tempDeck,
          discardPile: tempDiscard,
          lastActionMessage: '$actionMsg. ${victim.name} drew 4 cards and was Skipped!',
        );
        stepsToAdvance = 2; // skip their turn
        break;

      default:
        break;
    }

    _advanceTurn(nextState, steps: stepsToAdvance);
  }

  /// Advances turn and toggles concealment status for pass and play
  void _advanceTurn(YouKnowState currentState, {int steps = 1}) {
    int nextIndex = currentState.currentPlayerIndex;
    final int numPlayers = currentState.players.length;

    for (int i = 0; i < steps; i++) {
      if (currentState.isClockwise) {
        nextIndex = (nextIndex + 1) % numPlayers;
      } else {
        nextIndex = (nextIndex - 1 + numPlayers) % numPlayers;
      }
    }

    state = currentState.copyWith(
      currentPlayerIndex: nextIndex,
      status: currentState.isNetworked
          ? YouKnowStatus.playing
          : YouKnowStatus.revealingTurn, // Shows transition reveal overlay for next player
    );
  }

  /// Reveal hand on Pass & Play screen transition
  void revealHand() {
    state = state.copyWith(status: YouKnowStatus.playing);
  }

  // ── Helper Math Methods ──

  int _getPlayerIndexAtSteps(YouKnowState s, int steps) {
    final int numPlayers = s.players.length;
    int index = s.currentPlayerIndex;
    for (int i = 0; i < steps; i++) {
      if (s.isClockwise) {
        index = (index + 1) % numPlayers;
      } else {
        index = (index - 1 + numPlayers) % numPlayers;
      }
    }
    return index;
  }

  YouKnowPlayer _getPlayerAtSteps(YouKnowState s, int steps) {
    return s.players[_getPlayerIndexAtSteps(s, steps)];
  }

  /// Draws a card from deck, recycling discard pile if deck runs empty.
  YouKnowCard? _drawCardFromDeck(List<YouKnowCard> deckList, List<YouKnowCard> discardList) {
    if (deckList.isEmpty) {
      if (discardList.length <= 1) return null; // Only top card left, can't draw
      
      // Shuffle discard back into deck (keeping top card)
      final YouKnowCard top = discardList.removeLast();
      deckList.addAll(discardList);
      deckList.shuffle(_random);
      
      discardList.clear();
      discardList.add(top);
    }
    
    if (deckList.isNotEmpty) {
      return deckList.removeLast();
    }
    return null;
  }
}

final youknowStateProvider = NotifierProvider<YouKnowStateNotifier, YouKnowState>(() {
  return YouKnowStateNotifier();
});
