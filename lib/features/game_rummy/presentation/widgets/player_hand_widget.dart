import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:pocket_party/features/game_rummy/domain/models/rummy_state.dart';
import 'package:pocket_party/features/game_rummy/presentation/widgets/card_widget.dart';

/// Displays a player's hand as a horizontally scrollable, overlapping fan of cards.
///
/// Cards overlap so all 13-14 fit on screen. Tapping a card selects it
/// (pops it up); tapping another card swaps them.
class PlayerHandWidget extends StatelessWidget {
  final List<PlayingCard> hand;
  final int? selectedIndex;
  final PlayingCard? wildJokerCard;
  final bool isInteractive;
  final bool isFaceDown;
  final ValueChanged<int>? onCardTap;
  final double cardWidth;

  const PlayerHandWidget({
    super.key,
    required this.hand,
    this.selectedIndex,
    this.wildJokerCard,
    this.isInteractive = true,
    this.isFaceDown = false,
    this.onCardTap,
    this.cardWidth = 52,
  });

  @override
  Widget build(BuildContext context) {
    if (hand.isEmpty) {
      return const SizedBox(
        height: 80,
        child: Center(
          child: Text(
            'No cards',
            style: TextStyle(color: Colors.white38, fontSize: 14),
          ),
        ),
      );
    }

    final cardHeight = cardWidth * 1.4;
    // Calculate overlap: show ~40% of each card except the last
    final visiblePortion = cardWidth * 0.42;
    final totalWidth = visiblePortion * (hand.length - 1) + cardWidth;

    return SizedBox(
      height: cardHeight + 16, // extra space for pop-up on selection
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        physics: const BouncingScrollPhysics(),
        child: SizedBox(
          width: totalWidth,
          height: cardHeight + 16,
          child: Stack(
            clipBehavior: Clip.none,
            children: List.generate(hand.length, (i) {
              final isSelected = selectedIndex == i;
              final card = hand[i];
              final xOffset = visiblePortion * i;
              final yOffset = isSelected ? 0.0 : 12.0;

              return Positioned(
                left: xOffset,
                top: yOffset,
                child: GestureDetector(
                  onTap: isInteractive ? () => onCardTap?.call(i) : null,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOut,
                    transform: Matrix4.translationValues(0.0, isSelected ? -4.0 : 0.0, 0.0),
                    child: PlayingCardWidget(
                      card: isFaceDown ? null : card,
                      isFaceDown: isFaceDown,
                      isSelected: isSelected,
                      isWildJoker: !isFaceDown &&
                          wildJokerCard != null &&
                          card.isWildJoker(wildJokerCard),
                      width: cardWidth,
                    ).animate(delay: (i * 30).ms).fade(duration: 200.ms).slideY(
                      begin: isFaceDown ? -0.3 : 0.3,
                      duration: 250.ms,
                      curve: Curves.easeOut,
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

/// Compact view of opponent's face-down hand shown at the top of the screen.
class OpponentHandWidget extends StatelessWidget {
  final int cardCount;
  final double cardWidth;

  const OpponentHandWidget({
    super.key,
    required this.cardCount,
    this.cardWidth = 32,
  });

  @override
  Widget build(BuildContext context) {
    final visiblePortion = cardWidth * 0.3;
    final totalWidth = visiblePortion * (cardCount - 1) + cardWidth;
    final cardHeight = cardWidth * 1.4;

    return SizedBox(
      height: cardHeight + 4,
      child: Center(
        child: SizedBox(
          width: totalWidth,
          height: cardHeight,
          child: Stack(
            children: List.generate(cardCount, (i) {
              return Positioned(
                left: visiblePortion * i,
                child: PlayingCardWidget(
                  isFaceDown: true,
                  width: cardWidth,
                ).animate(delay: (i * 20).ms).fade(duration: 150.ms).slideY(
                  begin: -0.2,
                  duration: 200.ms,
                  curve: Curves.easeOut,
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
