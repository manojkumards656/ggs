import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_party/features/game_youknow/domain/models/youknow_card.dart';
import 'package:pocket_party/features/game_youknow/domain/models/youknow_state.dart';
import 'package:pocket_party/features/game_youknow/domain/providers/youknow_provider.dart';

void main() {
  group('YouKnow Game Engine Tests', () {
    late YouKnowStateNotifier notifier;

    setUp(() {
      notifier = YouKnowStateNotifier();
    });

    test('Initializes game with correct player count and hand sizes', () {
      final players = [
        {'id': 'p1', 'name': 'Player 1'},
        {'id': 'p2', 'name': 'Player 2'},
        {'id': 'p3', 'name': 'Player 3'},
      ];

      notifier.initGame(players, isNetworked: false);
      final state = notifier.gameState;

      expect(state.players.length, equals(3));
      expect(state.players[0].cards.length, equals(7));
      expect(state.players[1].cards.length, equals(7));
      expect(state.players[2].cards.length, equals(7));
      expect(state.discardPile.length, equals(1));
      expect(state.deck.length, equals(108 - (3 * 7) - 1)); // 108 - 21 dealt - 1 starting discard
      expect(state.status, equals(YouKnowStatus.revealingTurn));
      expect(state.isClockwise, isTrue);
    });

    test('Card playability validation works correctly', () {
      const topCard = YouKnowCard(id: 'c1', color: YouKnowColor.red, value: YouKnowValue.n5);

      // Match color
      const matchingColor = YouKnowCard(id: 'c2', color: YouKnowColor.red, value: YouKnowValue.n9);
      expect(matchingColor.isPlayableOn(topCard, null), isTrue);

      // Match value
      const matchingValue = YouKnowCard(id: 'c3', color: YouKnowColor.blue, value: YouKnowValue.n5);
      expect(matchingValue.isPlayableOn(topCard, null), isTrue);

      // Wild card is always playable
      const wildCard = YouKnowCard(id: 'c4', color: YouKnowColor.wild, value: YouKnowValue.wild);
      expect(wildCard.isPlayableOn(topCard, null), isTrue);

      // Mismatch
      const mismatch = YouKnowCard(id: 'c5', color: YouKnowColor.green, value: YouKnowValue.n2);
      expect(mismatch.isPlayableOn(topCard, null), isFalse);

      // Play on wild with active color choice
      const topWild = YouKnowCard(id: 'c6', color: YouKnowColor.wild, value: YouKnowValue.wild);
      const blueCard = YouKnowCard(id: 'c7', color: YouKnowColor.blue, value: YouKnowValue.n3);
      expect(blueCard.isPlayableOn(topWild, YouKnowColor.blue), isTrue);
      expect(blueCard.isPlayableOn(topWild, YouKnowColor.red), isFalse);
    });

    test('Declare YouKnow and catch player penalty works', () {
      final players = [
        {'id': 'p1', 'name': 'Player 1'},
        {'id': 'p2', 'name': 'Player 2'},
      ];
      notifier.initGame(players, isNetworked: false);

      // Setup state where Player 1 has 2 cards and plays 1 down to 1 card
      final p1 = notifier.gameState.players[0];
      final playableCard = YouKnowCard(id: 'p1_c1', color: notifier.gameState.topDiscardCard.color, value: YouKnowValue.n1);
      final extraCard = const YouKnowCard(id: 'p1_c2', color: YouKnowColor.green, value: YouKnowValue.n8);
      
      // Force Player 1 hand
      final updatedPlayers = List<YouKnowPlayer>.from(notifier.gameState.players);
      updatedPlayers[0] = p1.copyWith(cards: [playableCard, extraCard], hasDeclaredYouKnow: false);
      notifier.setState(notifier.gameState.copyWith(players: updatedPlayers));

      // Play card without declaring YouKnow!
      notifier.playCard('p1', 'p1_c1');

      // Player 1 should now be vulnerable
      expect(notifier.gameState.vulnerablePlayerId, equals('p1'));

      // Player 2 catches Player 1
      notifier.catchPlayer('p2');

      // Player 1 should draw 2 penalty cards, meaning they now have 3 cards (1 remaining + 2 penalty)
      expect(notifier.gameState.players[0].cards.length, equals(3));
      // Vulnerability should be cleared
      expect(notifier.gameState.vulnerablePlayerId, isNull);
    });

    test('Safe play down to 1 card when declaring YouKnow early', () {
      final players = [
        {'id': 'p1', 'name': 'Player 1'},
        {'id': 'p2', 'name': 'Player 2'},
      ];
      notifier.initGame(players, isNetworked: false);

      // Setup state where Player 1 has 2 cards
      final p1 = notifier.gameState.players[0];
      final playableCard = YouKnowCard(id: 'p1_c1', color: notifier.gameState.topDiscardCard.color, value: YouKnowValue.n1);
      final extraCard = const YouKnowCard(id: 'p1_c2', color: YouKnowColor.green, value: YouKnowValue.n8);
      
      final updatedPlayers = List<YouKnowPlayer>.from(notifier.gameState.players);
      updatedPlayers[0] = p1.copyWith(cards: [playableCard, extraCard], hasDeclaredYouKnow: false);
      notifier.setState(notifier.gameState.copyWith(players: updatedPlayers));

      // Shout YouKnow first
      notifier.declareYouKnow('p1');
      expect(notifier.gameState.players[0].hasDeclaredYouKnow, isTrue);

      // Play the card down to 1 card
      notifier.playCard('p1', 'p1_c1');

      // Should NOT be vulnerable because they shouted beforehand
      expect(notifier.gameState.vulnerablePlayerId, isNull);
    });
  });
}
