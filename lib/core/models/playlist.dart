class MusicPlaylist {
  const MusicPlaylist({
    required this.id,
    required this.name,
    required this.coverUrl,
    required this.playCount,
    this.description,
  });

  factory MusicPlaylist.fromJson(Map<String, dynamic> json) {
    return MusicPlaylist(
      id: json['id'] is int ? json['id'] as int : int.tryParse('${json['id']}') ?? 0,
      name: '${json['name'] ?? ''}',
      coverUrl: '${json['picUrl'] ?? json['coverImgUrl'] ?? ''}',
      playCount: json['playCount'] is num ? (json['playCount'] as num).toInt() : 0,
      description: json['description']?.toString(),
    );
  }

  final int id;
  final String name;
  final String coverUrl;
  final int playCount;
  final String? description;
}
