import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:pocket_party/features/game_rummy/domain/models/rummy_state.dart';
import 'package:pocket_party/features/game_rummy/presentation/widgets/card_widget.dart';

/// Displays the player's hand as an overlapping fan of cards
/// with full **drag-and-drop** support.
///
/// • Long-press a card to start dragging (80ms quick delay).
/// • Drop on another card to reorder (inserts at that position).
/// • Drop on the discard pile (handled by [GameTableWidget]) to discard.
/// • Tap a card to select it (visual pop-up); double-tap to discard.
class PlayerHandWidget extends StatefulWidget {
  final List<PlayingCard> hand;
  final int? selectedIndex;
  final PlayingCard? wildJokerCard;
  final bool isInteractive;
  final ValueChanged<int>? onCardTap;
  final void Function(int from, int to)? onReorder;
  final double cardWidth;

  const PlayerHandWidget({
    super.key,
    required this.hand,
    this.selectedIndex,
    this.wildJokerCard,
    this.isInteractive = true,
    this.onCardTap,
    this.onReorder,
    this.cardWidth = 52,
  });

  @override
  State<PlayerHandWidget> createState() => _PlayerHandWidgetState();
}

class _PlayerHandWidgetState extends State<PlayerHandWidget> {
  int? _hoverIndex;

  @override
  Widget build(BuildContext context) {
    if (widget.hand.isEmpty) {
      return SizedBox(
        height: 80,
        child: Center(
          child: Text(
            'No cards',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.25), fontSize: 14),
          ),
        ),
      );
    }

    final cardHeight = widget.cardWidth * 1.4;

    return Container(
      height: cardHeight + 24,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            const Color(0xFF1E1E36).withValues(alpha: 0.4),
          ],
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(vertical: 6),
            physics: const BouncingScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: constraints.maxWidth,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      widget.hand.length,
                      (i) => _buildCardSlot(i, cardHeight),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCardSlot(int i, double cardHeight) {
    final card = widget.hand[i];
    final isSelected = widget.selectedIndex == i;
    final isHovered = _hoverIndex == i;
    final isWild = widget.wildJokerCard != null &&
        card.isWildJoker(widget.wildJokerCard);

    final cardWidget = PlayingCardWidget(
      card: card,
      width: widget.cardWidth,
      isSelected: isSelected,
      isWildJoker: isWild,
    );

    final isLast = i == widget.hand.length - 1;

    if (!widget.isInteractive) {
      return Align(
        widthFactor: isLast ? 1.0 : 0.65,
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 1),
          child: cardWidget,
        ),
      );
    }

    return DragTarget<int>(
      onWillAcceptWithDetails: (details) {
        if (details.data == i) return false;
        setState(() => _hoverIndex = i);
        return true;
      },
      onLeave: (_) {
        if (_hoverIndex == i) setState(() => _hoverIndex = null);
      },
      onAcceptWithDetails: (details) {
        HapticFeedback.mediumImpact();
        widget.onReorder?.call(details.data, i);
        setState(() {
          _hoverIndex = null;
        });
      },
      builder: (context, candidateData, rejectedData) {
        return Align(
          widthFactor: isHovered || isLast ? 1.0 : 0.65,
          alignment: Alignment.centerLeft,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
            margin: const EdgeInsets.symmetric(horizontal: 1),
            child: LongPressDraggable<int>(
              data: i,
              delay: const Duration(milliseconds: 80),
              hapticFeedbackOnStart: true,
              maxSimultaneousDrags: 1,
              feedback: SizedBox(
                width: widget.cardWidth * 1.12,
                height: cardHeight * 1.12,
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF00F2FE).withValues(alpha: 0.35),
                          blurRadius: 16,
                          spreadRadius: 2,
                        ),
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.5),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: PlayingCardWidget(
                      card: card,
                      width: widget.cardWidth,
                      isSelected: true,
                      isWildJoker: isWild,
                    ),
                  ),
                ),
              ),
              childWhenDragging: Opacity(
                opacity: 0.25,
                child: Container(
                  width: widget.cardWidth,
                  height: cardHeight,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: const Color(0xFF00F2FE).withValues(alpha: 0.4),
                      width: 1.5,
                    ),
                    color: const Color(0xFF00F2FE).withValues(alpha: 0.08),
                  ),
                ),
              ),
              child: GestureDetector(
                onTap: () => widget.onCardTap?.call(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  transform: Matrix4.translationValues(
                    0,
                    isSelected ? -8.0 : 0.0,
                    0,
                  ),
                  child: cardWidget,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Compact opponent hand for landscape — shows face-down cards in a tight row.
class OpponentHandWidget extends StatelessWidget {
  final int cardCount;
  final double cardWidth;

  const OpponentHandWidget({
    super.key,
    required this.cardCount,
    this.cardWidth = 28,
  });

  @override
  Widget build(BuildContext context) {
    final cardHeight = cardWidth * 1.4;
    final overlap = cardWidth * 0.55;
    final totalWidth = overlap * (cardCount - 1) + cardWidth;

    return SizedBox(
      height: cardHeight + 4,
      child: Center(
        child: SizedBox(
          width: totalWidth,
          height: cardHeight,
          child: Stack(
            children: List.generate(cardCount, (i) {
              return Positioned(
                left: overlap * i,
                child: PlayingCardWidget(
                  isFaceDown: true,
                  width: cardWidth,
                ).animate(delay: (i * 15).ms).fade(duration: 120.ms),
              );
            }),
          ),
        ),
      ),
    );
  }
}
