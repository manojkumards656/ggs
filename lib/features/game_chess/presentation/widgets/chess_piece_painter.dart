import 'package:flutter/material.dart';

class ChessPieceWidget extends StatelessWidget {
  final String type; // 'p', 'n', 'b', 'r', 'q', 'k'
  final String color; // 'w', 'b'
  final double size;
  final bool isSelected;

  const ChessPieceWidget({
    super.key,
    required this.type,
    required this.color,
    required this.size,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: isSelected ? 1.15 : 1.0,
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOutBack,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: size,
        height: size,
        decoration: isSelected
            ? BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: color == 'w'
                        ? const Color(0xFFE2E2F0).withValues(alpha: 0.4)
                        : const Color(0xFF00F2FE).withValues(alpha: 0.6),
                    blurRadius: 16,
                    spreadRadius: 2,
                  ),
                ],
              )
            : null,
        child: CustomPaint(
          size: Size(size, size),
          painter: ChessPiecePainter(
            type: type.toLowerCase(),
            color: color.toLowerCase(),
          ),
        ),
      ),
    );
  }
}

class ChessPiecePainter extends CustomPainter {
  final String type; // 'p', 'n', 'b', 'r', 'q', 'k'
  final String color; // 'w', 'b'

  ChessPiecePainter({required this.type, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    // Scale canvas to 100x100 to make path definitions simple and responsive
    canvas.save();
    canvas.scale(size.width / 100, size.height / 100);

    final isWhite = color == 'w';

    // 1. Shadows & Glow Paint Setup (Uniform dark drop shadow)
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    // 2. Main Piece Fill Paint Setup (Frosted white glass vs Dark indigo glass)
    final Rect bounds = const Rect.fromLTWH(0, 0, 100, 100);
    final fillGradient = isWhite
        ? LinearGradient(
            colors: [
              Colors.white.withValues(alpha: 0.25),
              Colors.white.withValues(alpha: 0.10),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
        : LinearGradient(
            colors: [
              const Color(0xFF1B1B3A).withValues(alpha: 0.90),
              const Color(0xFF0A081A).withValues(alpha: 0.75),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          );

    final fillPaint = Paint()
      ..shader = fillGradient.createShader(bounds)
      ..style = PaintingStyle.fill;

    // 3. Border Stroke Paint Setup (Solid high-quality borders)
    final strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    if (isWhite) {
      strokePaint.color = Colors.white;
    } else {
      // Sleek uniform border for Black piece (highly visible slate grey)
      strokePaint.color = const Color(0xFF8E8EAF);
    }

    // 4. Accent detail lines stroke paint
    final detailStrokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..color = isWhite ? const Color(0xFF1E1E36).withValues(alpha: 0.3) : const Color(0xFF8E8EAF).withValues(alpha: 0.6)
      ..strokeCap = StrokeCap.round;

    // Build the piece paths
    final path = Path();
    final List<Path> accessories = [];
    final List<Path> details = [];

    switch (type) {
      case 'p': // Pawn
        _drawPawn(path, accessories);
        break;
      case 'r': // Rook
        _drawRook(path, accessories);
        break;
      case 'n': // Knight
        _drawKnight(path, accessories, details);
        break;
      case 'b': // Bishop
        _drawBishop(path, accessories);
        break;
      case 'q': // Queen
        _drawQueen(path, accessories);
        break;
      case 'k': // King
        _drawKing(path, accessories);
        break;
    }

    // Draw shadow first
    canvas.save();
    canvas.translate(0, 3);
    canvas.drawPath(path, shadowPaint);
    for (final acc in accessories) {
      canvas.drawPath(acc, shadowPaint);
    }
    canvas.restore();

    // Draw main filled piece
    canvas.drawPath(path, fillPaint);
    for (final acc in accessories) {
      canvas.drawPath(acc, fillPaint);
    }

    // Draw borders
    canvas.drawPath(path, strokePaint);
    for (final acc in accessories) {
      canvas.drawPath(acc, strokePaint);
    }

    // Draw detail lines (like Knight's eye/nostril/mane details)
    for (final detail in details) {
      canvas.drawPath(detail, detailStrokePaint);
    }

    canvas.restore();
  }

  /// Helper to draw the standard double-tiered base
  void _drawDoubleBase(Path path) {
    // Bottom rim
    path.addRRect(RRect.fromRectAndRadius(
      const Rect.fromLTRB(22, 84, 78, 90),
      const Radius.circular(3),
    ));
    // Top rim
    path.addRRect(RRect.fromRectAndRadius(
      const Rect.fromLTRB(28, 76, 72, 84),
      const Radius.circular(4),
    ));
  }

  /// Helper to draw a slender tapering column torso
  void _drawSlenderTorso(Path path, double bottomY, double topY) {
    final body = Path();
    body.moveTo(32, bottomY);
    body.quadraticBezierTo(43, (bottomY + topY) / 2 + 2, 36, topY);
    body.lineTo(64, topY);
    body.quadraticBezierTo(57, (bottomY + topY) / 2 + 2, 68, bottomY);
    body.close();
    path.addPath(body, Offset.zero);
  }

  void _drawPawn(Path path, List<Path> accessories) {
    _drawDoubleBase(path);
    _drawSlenderTorso(path, 76, 52);

    // Collar
    path.addOval(const Rect.fromLTRB(36, 48, 64, 52));

    // Head (Sphere)
    path.addOval(const Rect.fromLTRB(36, 22, 64, 48));
  }

  void _drawRook(Path path, List<Path> accessories) {
    _drawDoubleBase(path);
    _drawSlenderTorso(path, 76, 44);

    // Collar just below the head
    path.addOval(const Rect.fromLTRB(32, 40, 68, 44));

    // Head (Crenellations / Castle top)
    final head = Path();
    head.moveTo(26, 40);
    head.lineTo(26, 22);
    head.lineTo(35, 22);
    head.lineTo(35, 29);
    head.lineTo(45, 29);
    head.lineTo(45, 22);
    head.lineTo(55, 22);
    head.lineTo(55, 29);
    head.lineTo(65, 29);
    head.lineTo(65, 22);
    head.lineTo(74, 22);
    head.lineTo(74, 40);
    head.close();
    path.addPath(head, Offset.zero);
  }

  void _drawKnight(Path path, List<Path> accessories, List<Path> details) {
    // Double-tier base
    _drawDoubleBase(path);

    // Simple classic Staunton horse silhouette matching the reference image
    final head = Path();
    head.moveTo(30, 76); // bottom-left chest/belly start
    head.quadraticBezierTo(28, 60, 40, 40); // convex belly curve and deep throat
    head.lineTo(14, 50); // jaw line to chin corner
    head.lineTo(10, 40); // snout front (sloping up-left to nose tip)
    head.lineTo(24, 26); // nose bridge
    head.lineTo(36, 20); // forehead curve
    head.lineTo(30, 10); // single ear tip pointing up-left
    head.lineTo(42, 14); // ear back
    head.quadraticBezierTo(80, 15, 70, 76); // smooth C-shaped mane back down to base
    head.close();
    path.addPath(head, Offset.zero);

    // Clear any details to match the clean solid silhouette of the reference image
    details.clear();
  }

  void _drawBishop(Path path, List<Path> accessories) {
    _drawDoubleBase(path);
    _drawSlenderTorso(path, 76, 52);

    // Collar
    path.addOval(const Rect.fromLTRB(34, 48, 66, 52));

    // Mitre Head (Droplet / oval point)
    final head = Path();
    head.moveTo(32, 48);
    head.quadraticBezierTo(30, 26, 50, 22); // left curve
    head.quadraticBezierTo(70, 26, 68, 48); // right curve
    head.close();
    path.addPath(head, Offset.zero);

    // Finial (circle on top)
    final finial = Path();
    finial.addOval(const Rect.fromLTRB(47, 14, 53, 20));
    accessories.add(finial);

    // Slit (diagonal mitre cut)
    final slit = Path();
    slit.moveTo(42, 28);
    slit.lineTo(50, 38);
    accessories.add(slit);
  }

  void _drawQueen(Path path, List<Path> accessories) {
    _drawDoubleBase(path);
    _drawSlenderTorso(path, 76, 40); // Torso starts higher to reduce crown size

    // Collar
    path.addOval(const Rect.fromLTRB(36, 36, 64, 40));

    // Dome inside the coronet (starts at Y=36, peak is at Y=10)
    final dome = Path();
    dome.moveTo(36, 36);
    dome.quadraticBezierTo(38, 12, 50, 10);
    dome.quadraticBezierTo(62, 12, 64, 36);
    dome.close();
    path.addPath(dome, Offset.zero);

    // Finial bead on top of the dome (reaches up to Y=4, same as King's cross top)
    final centerBead = Path();
    centerBead.addOval(const Rect.fromLTRB(47, 4, 53, 10));
    accessories.add(centerBead);

    // Pointy coronet crown (starts at Y=36, peaks at Y=16 & 13)
    final crown = Path();
    crown.moveTo(30, 36);
    crown.lineTo(28, 16); // Point 1 (left)
    crown.lineTo(39, 25);
    crown.lineTo(50, 13); // Point 2 (center)
    crown.lineTo(61, 25);
    crown.lineTo(72, 16); // Point 3 (right)
    crown.lineTo(70, 36);
    crown.close();
    path.addPath(crown, Offset.zero);

    // Crown circle tips (raised to match new tall crown peaks)
    final c1 = Path()..addOval(const Rect.fromLTRB(25.5, 13.5, 30.5, 18.5));
    final c2 = Path()..addOval(const Rect.fromLTRB(47.5, 10.5, 52.5, 15.5));
    final c3 = Path()..addOval(const Rect.fromLTRB(69.5, 13.5, 74.5, 18.5));
    accessories.addAll([c1, c2, c3]);
  }

  void _drawKing(Path path, List<Path> accessories) {
    _drawDoubleBase(path);
    _drawSlenderTorso(path, 76, 48);

    // Collar
    path.addOval(const Rect.fromLTRB(36, 44, 64, 48));

    // Goblet/chalice head
    final head = Path();
    head.moveTo(36, 44);
    head.quadraticBezierTo(28, 38, 26, 32); // left expand
    head.lineTo(74, 32);
    head.quadraticBezierTo(72, 38, 64, 44); // right expand
    head.close();
    path.addPath(head, Offset.zero);

    // Dome crown inside the goblet (squarish top instead of oval)
    final dome = Path();
    dome.moveTo(26, 32);
    dome.quadraticBezierTo(27, 22, 36, 22); // squarish left corner
    dome.lineTo(64, 22); // flat top
    dome.quadraticBezierTo(73, 22, 74, 32); // squarish right corner
    dome.close();
    path.addPath(dome, Offset.zero);

    // Large prominent cross on top (base aligned to the flat squarish top at Y=22)
    final cross = Path();
    // Vertical bar
    cross.addRect(const Rect.fromLTRB(47, 4, 53, 22));
    // Horizontal bar
    cross.addRect(const Rect.fromLTRB(40, 9, 60, 15));
    accessories.add(cross);
  }

  @override
  bool shouldRepaint(covariant ChessPiecePainter oldDelegate) {
    return oldDelegate.type != type || oldDelegate.color != color;
  }
}
