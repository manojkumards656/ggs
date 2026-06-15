import 'package:flutter/material.dart';

enum YouKnowColor {
  red,
  green,
  blue,
  yellow,
  wild;

  String get displayName {
    switch (this) {
      case YouKnowColor.red:
        return 'Red';
      case YouKnowColor.green:
        return 'Green';
      case YouKnowColor.blue:
        return 'Blue';
      case YouKnowColor.yellow:
        return 'Yellow';
      case YouKnowColor.wild:
        return 'Wild';
    }
  }

  Color get colorValue {
    switch (this) {
      case YouKnowColor.red:
        return const Color(0xFFE53935); // Modern Vibrant Red
      case YouKnowColor.green:
        return const Color(0xFF43A047); // Modern Vibrant Green
      case YouKnowColor.blue:
        return const Color(0xFF1E88E5); // Modern Vibrant Blue
      case YouKnowColor.yellow:
        return const Color(0xFFFFB300); // Modern Vibrant Yellow
      case YouKnowColor.wild:
        return const Color(0xFF121212); // Sleek Dark Gray for Wild card face
    }
  }
}

enum YouKnowValue {
  n0,
  n1,
  n2,
  n3,
  n4,
  n5,
  n6,
  n7,
  n8,
  n9,
  skip,
  reverse,
  drawTwo,
  wild,
  wildDrawFour;

  String get displayName {
    switch (this) {
      case YouKnowValue.n0: return '0';
      case YouKnowValue.n1: return '1';
      case YouKnowValue.n2: return '2';
      case YouKnowValue.n3: return '3';
      case YouKnowValue.n4: return '4';
      case YouKnowValue.n5: return '5';
      case YouKnowValue.n6: return '6';
      case YouKnowValue.n7: return '7';
      case YouKnowValue.n8: return '8';
      case YouKnowValue.n9: return '9';
      case YouKnowValue.skip: return 'Skip';
      case YouKnowValue.reverse: return 'Reverse';
      case YouKnowValue.drawTwo: return '+2';
      case YouKnowValue.wild: return 'Wild';
      case YouKnowValue.wildDrawFour: return '+4';
    }
  }

  bool get isAction {
    return this == YouKnowValue.skip ||
        this == YouKnowValue.reverse ||
        this == YouKnowValue.drawTwo ||
        this == YouKnowValue.wild ||
        this == YouKnowValue.wildDrawFour;
  }
}

class YouKnowCard {
  final String id;
  final YouKnowColor color;
  final YouKnowValue value;

  const YouKnowCard({
    required this.id,
    required this.color,
    required this.value,
  });

  bool get isWild => color == YouKnowColor.wild;

  /// Checks if this card can be played on top of the given discard pile card.
  bool isPlayableOn(YouKnowCard topCard, YouKnowColor? activeWildColor) {
    // Wild cards can always be played
    if (isWild) return true;

    // If top card is wild, we must match the chosen active wild color
    if (topCard.isWild) {
      return color == activeWildColor;
    }

    // Match color or match value
    return color == topCard.color || value == topCard.value;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'color': color.name,
      'value': value.name,
    };
  }

  factory YouKnowCard.fromJson(Map<String, dynamic> json) {
    return YouKnowCard(
      id: json['id'] as String,
      color: YouKnowColor.values.byName(json['color'] as String),
      value: YouKnowValue.values.byName(json['value'] as String),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is YouKnowCard &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          color == other.color &&
          value == other.value;

  @override
  int get hashCode => id.hashCode ^ color.hashCode ^ value.hashCode;

  @override
  String toString() => '${color.name}_${value.name}';
}
