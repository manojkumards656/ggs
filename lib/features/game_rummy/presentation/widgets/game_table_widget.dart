import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:pocket_party/features/game_rummy/domain/models/rummy_state.dart';
import 'package:pocket_party/features/game_rummy/presentation/widgets/card_widget.dart';

/// Central table area — stock pile, discard pile, and wild joker.
///
/// Optimised for **landscape** layout (horizontal Row).
/// The discard pile is a [DragTarget<int>] that accepts cards from the hand.
class GameTableWidget extends StatefulWidget {
  final List<PlayingCard> stockPile;
  final List<PlayingCard> discardPile;
  final PlayingCard? wildJokerCard;
  final bool canDraw;
  final bool canDiscard;
  final VoidCallback onDrawFromStock;
  final VoidCallback onDrawFromDiscard;
  final ValueChanged<int>? onCardDiscarded;
  final double cardWidth;

  const GameTableWidget({
    super.key,
    required this.stockPile,
    required this.discardPile,
    this.wildJokerCard,
    required this.canDraw,
    this.canDiscard = false,
    required this.onDrawFromStock,
    required this.onDrawFromDiscard,
    this.onCardDiscarded,
    this.cardWidth = 60,
  });

  @override
  State<GameTableWidget> createState() => _GameTableWidgetState();
}

class _GameTableWidgetState extends State<GameTableWidget> {
  bool _discardHovering = false;

  @override
  Widget build(BuildContext context) {
    final cardHeight = widget.cardWidth * 1.4;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF1A1A2E).withValues(alpha: 0.6),
            const Color(0xFF16213E).withValues(alpha: 0.6),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF00F2FE).withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Wild Joker indicator ──
          _WildJokerIndicator(
            wildCard: widget.wildJokerCard,
            cardWidth: widget.cardWidth * 0.55,
          ),
          const SizedBox(width: 12),

          // ── Stock pile (face-down, tap to draw) ──
          _PileWidget(
            label: 'STOCK',
            count: widget.stockPile.length,
            cardWidth: widget.cardWidth,
            cardHeight: cardHeight,
            canTap: widget.canDraw && widget.stockPile.isNotEmpty,
            onTap: widget.onDrawFromStock,
            child: _buildStockPile(widget.cardWidth, cardHeight),
          ),
          const SizedBox(width: 12),

          // ── Discard pile (DragTarget) ──
          _buildDiscardPileTarget(widget.cardWidth, cardHeight),
        ],
      ),
    ).animate().fade(duration: 300.ms).scale(
      begin: const Offset(0.97, 0.97),
      duration: 300.ms,
      curve: Curves.easeOut,
    );
  }

  Widget _buildStockPile(double w, double h) {
    if (widget.stockPile.isEmpty) {
      return _EmptyPileSlot(width: w, height: h);
    }
    return SizedBox(
      width: w + 4,
      height: h + 4,
      child: Stack(
        children: [
          if (widget.stockPile.length > 2)
            Positioned(
              left: 3, top: 3,
              child: PlayingCardWidget(isFaceDown: true, width: w),
            ),
          if (widget.stockPile.length > 1)
            Positioned(
              left: 1.5, top: 1.5,
              child: PlayingCardWidget(isFaceDown: true, width: w),
            ),
          Positioned(
            left: 0, top: 0,
            child: PlayingCardWidget(isFaceDown: true, width: w),
          ),
        ],
      ),
    );
  }

  Widget _buildDiscardPileTarget(double w, double h) {
    return DragTarget<int>(
      onWillAcceptWithDetails: (details) {
        if (!widget.canDiscard) return false;
        setState(() => _discardHovering = true);
        return true;
      },
      onLeave: (_) => setState(() => _discardHovering = false),
      onAcceptWithDetails: (details) {
        setState(() => _discardHovering = false);
        widget.onCardDiscarded?.call(details.data);
      },
      builder: (context, candidateData, rejectedData) {
        return _PileWidget(
          label: 'DISCARD',
          count: widget.discardPile.length,
          cardWidth: w,
          cardHeight: h,
          canTap: widget.canDraw && widget.discardPile.isNotEmpty,
          onTap: widget.onDrawFromDiscard,
          isHighlighted: _discardHovering,
          child: _buildDiscardPileContent(w, h),
        );
      },
    );
  }

  Widget _buildDiscardPileContent(double w, double h) {
    if (widget.discardPile.isEmpty) {
      return _EmptyPileSlot(
        width: w,
        height: h,
        isHighlighted: _discardHovering,
        label: widget.canDiscard ? 'Drop here' : null,
      );
    }
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: _discardHovering
          ? BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF00F2FE).withValues(alpha: 0.5),
                  blurRadius: 18,
                  spreadRadius: 3,
                ),
              ],
            )
          : null,
      child: PlayingCardWidget(
        card: widget.discardPile.last,
        width: w,
        isWildJoker: widget.wildJokerCard != null &&
            widget.discardPile.last.isWildJoker(widget.wildJokerCard),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Sub-widgets
// ─────────────────────────────────────────────────────────────

class _WildJokerIndicator extends StatelessWidget {
  final PlayingCard? wildCard;
  final double cardWidth;

  const _WildJokerIndicator({this.wildCard, required this.cardWidth});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'WILD',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF00F2FE).withValues(alpha: 0.9),
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 3),
        if (wildCard != null)
          PlayingCardWidget(
            card: wildCard,
            width: cardWidth,
            isWildJoker: true,
          ).animate(
            onPlay: (c) => c.repeat(reverse: true),
          ).shimmer(
            duration: 2000.ms,
            color: const Color(0xFF00F2FE).withValues(alpha: 0.2),
          )
        else
          SizedBox(
            width: cardWidth,
            height: cardWidth * 1.4,
            child: const Center(
              child: Text('?', style: TextStyle(color: Colors.white38, fontSize: 16)),
            ),
          ),
      ],
    );
  }
}

class _PileWidget extends StatelessWidget {
  final String label;
  final int count;
  final double cardWidth;
  final double cardHeight;
  final bool canTap;
  final VoidCallback onTap;
  final Widget child;
  final bool isHighlighted;

  const _PileWidget({
    required this.label,
    required this.count,
    required this.cardWidth,
    required this.cardHeight,
    required this.canTap,
    required this.onTap,
    required this.child,
    this.isHighlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: isHighlighted
                ? const Color(0xFF00F2FE).withValues(alpha: 0.95)
                : Colors.white.withValues(alpha: 0.65),
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 4),
        GestureDetector(
          onTap: canTap ? onTap : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: canTap || isHighlighted
                ? BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: isHighlighted
                            ? const Color(0xFF00F2FE).withValues(alpha: 0.4)
                            : const Color(0xFF00F2FE).withValues(alpha: 0.12),
                        blurRadius: isHighlighted ? 16 : 10,
                        spreadRadius: isHighlighted ? 3 : 1,
                      ),
                    ],
                  )
                : null,
            child: child,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '$count',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.white.withValues(alpha: 0.75),
          ),
        ),
      ],
    );
  }
}

class _EmptyPileSlot extends StatelessWidget {
  final double width;
  final double height;
  final bool isHighlighted;
  final String? label;

  const _EmptyPileSlot({
    required this.width,
    required this.height,
    this.isHighlighted = false,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isHighlighted
              ? const Color(0xFF00F2FE).withValues(alpha: 0.6)
              : Colors.white.withValues(alpha: 0.1),
          width: isHighlighted ? 2 : 1.5,
        ),
        color: isHighlighted
            ? const Color(0xFF00F2FE).withValues(alpha: 0.08)
            : Colors.white.withValues(alpha: 0.03),
      ),
      child: Center(
        child: label != null
            ? Text(
                label!,
                style: TextStyle(
                  fontSize: 12,
                  color: const Color(0xFF00F2FE).withValues(alpha: 0.85),
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              )
            : Icon(
                Icons.layers_clear,
                size: 18,
                color: Colors.white.withValues(alpha: 0.25),
              ),
      ),
    );
  }
}
