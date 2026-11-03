
class Note {
  final int? id;
  final String uid;
  final String title;
  final String content;
  final String date;
  final String category;
  final String? cloudId;
  final bool isSynced;
  final bool isFavorite;

  Note({
    this.id,
    required this.uid,
    required this.title,
    required this.content,
    required this.date,
    this.category = 'Geral',
    this.cloudId,
    this.isSynced = false,
    this.isFavorite = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'uid': uid,
      'title': title,
      'content': content,
      'date': date,
      'category': category,
      'cloud_id': cloudId,
      'is_synced': isSynced ? 1 : 0,
      'is_favorite': isFavorite ? 1 : 0,
    };
  }

  factory Note.fromMap(Map<String, dynamic> map) {
    return Note(
      id: map['id'] as int?,
      uid: map['uid'] as String,
      title: map['title'] as String,
      content: map['content'] as String,
      date: map['date'] as String,
      category: map['category'] as String? ?? 'Geral',
      cloudId: map['cloud_id'] as String?,
      isSynced: (map['is_synced'] as int? ?? 0) == 1,
      isFavorite: (map['is_favorite'] as int? ?? 0) == 1,
    );
  }
}
