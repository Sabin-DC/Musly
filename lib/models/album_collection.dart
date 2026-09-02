class AlbumCollection {
  final String id;
  final String name;
  final String? description;
  final List<String> albumIds;
  final DateTime createdAt;
  final DateTime updatedAt;

  const AlbumCollection({
    required this.id,
    required this.name,
    this.description,
    required this.albumIds,
    required this.createdAt,
    required this.updatedAt,
  });

  AlbumCollection copyWith({
    String? name,
    String? description,
    bool clearDescription = false,
    List<String>? albumIds,
    DateTime? updatedAt,
  }) {
    return AlbumCollection(
      id: id,
      name: name ?? this.name,
      description: clearDescription ? null : description ?? this.description,
      albumIds: albumIds ?? this.albumIds,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory AlbumCollection.fromJson(Map<String, dynamic> json) {
    final now = DateTime.now();
    return AlbumCollection(
      id: json['id'].toString(),
      name: json['name'].toString(),
      description: json['description']?.toString(),
      albumIds: (json['albumIds'] as List<dynamic>? ?? const [])
          .map((value) => value.toString())
          .toList(),
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? now,
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? '') ?? now,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'albumIds': albumIds,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };
}
