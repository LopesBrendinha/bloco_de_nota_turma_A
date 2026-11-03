class Note {
  final String id;
  final String uid;
  final String title;
  final String content;
  final String? category;
  final int createdAt;
  final int updatedAt;
  final int? deletedAt;
  final String syncStatus;

  Note({
    required this.id,
    required this.uid,
    required this.title,
    required this.content,
    this.category,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    required this.syncStatus,
  });

  Note copyWith({
    String? title,
    String? content,
    String? category,
    int? updatedAt,
    int? deletedAt,
    String? syncStatus,
  }) {
    return Note(
      id: id,
      uid: uid,
      title: title ?? this.title,
      content: content ?? this.content,
      category: category ?? this.category,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'uid': uid,
      'title': title,
      'content': content,
      'category': category,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'deleted_at': deletedAt,
      'sync_status': syncStatus,
    };
  }

  factory Note.fromMap(Map<String, dynamic> map) {
    return Note(
      id: map['id'],
      uid: map['uid'],
      title: map['title'],
      content: map['content'],
      category: map['category'],
      createdAt: map['created_at'],
      updatedAt: map['updated_at'],
      deletedAt: map['deleted_at'],
      syncStatus: map['sync_status'],
    );
  }
}
