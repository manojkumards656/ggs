import 'package:flutter/material.dart';

class DrawPoint {
  final Offset? point;
  final Color color;
  final double strokeWidth;

  const DrawPoint({
    this.point,
    this.color = Colors.black,
    this.strokeWidth = 3.0,
  });

  Map<String, dynamic> toJson() {
    if (point == null) {
      return {'up': true};
    }
    return {
      'x': point!.dx,
      'y': point!.dy,
      'c': color.value,
      'w': strokeWidth,
    };
  }

  factory DrawPoint.fromJson(Map<String, dynamic> json) {
    if (json['up'] == true) {
      return const DrawPoint(point: null);
    }
    return DrawPoint(
      point: Offset((json['x'] as num).toDouble(), (json['y'] as num).toDouble()),
      color: Color(json['c'] as int),
      strokeWidth: (json['w'] as num).toDouble(),
    );
  }
}
