class Room {
  final String id;
  final String name;
  final String hostName;
  final String gameType;
  final int playersCount;
  final int maxPlayers;
  final int tcpPort;
  final String hostIp;

  const Room({
    required this.id,
    required this.name,
    required this.hostName,
    required this.gameType,
    required this.playersCount,
    required this.maxPlayers,
    required this.tcpPort,
    required this.hostIp,
  });

  Room copyWith({
    String? id,
    String? name,
    String? hostName,
    String? gameType,
    int? playersCount,
    int? maxPlayers,
    int? tcpPort,
    String? hostIp,
  }) {
    return Room(
      id: id ?? this.id,
      name: name ?? this.name,
      hostName: hostName ?? this.hostName,
      gameType: gameType ?? this.gameType,
      playersCount: playersCount ?? this.playersCount,
      maxPlayers: maxPlayers ?? this.maxPlayers,
      tcpPort: tcpPort ?? this.tcpPort,
      hostIp: hostIp ?? this.hostIp,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': 'discovery',
      'id': id,
      'name': name,
      'hostName': hostName,
      'gameType': gameType,
      'playersCount': playersCount,
      'maxPlayers': maxPlayers,
      'tcpPort': tcpPort,
      'hostIp': hostIp,
    };
  }

  factory Room.fromJson(Map<String, dynamic> json) {
    return Room(
      id: json['id'] as String,
      name: json['name'] as String,
      hostName: json['hostName'] as String,
      gameType: json['gameType'] as String,
      playersCount: json['playersCount'] as int,
      maxPlayers: json['maxPlayers'] as int,
      tcpPort: json['tcpPort'] as int,
      hostIp: json['hostIp'] as String,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Room &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          hostName == other.hostName &&
          gameType == other.gameType &&
          playersCount == other.playersCount &&
          maxPlayers == other.maxPlayers &&
          tcpPort == other.tcpPort &&
          hostIp == other.hostIp;

  @override
  int get hashCode =>
      id.hashCode ^
      name.hashCode ^
      hostName.hashCode ^
      gameType.hashCode ^
      playersCount.hashCode ^
      maxPlayers.hashCode ^
      tcpPort.hashCode ^
      hostIp.hashCode;
}
