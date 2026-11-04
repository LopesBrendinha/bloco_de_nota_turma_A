class Note {
  final int? id;

  final String uid;

  final String title;
  final String content;
  final String category;

  final String date;
  final String? cloudId;
  final int updatedAt;

  Note({
    this.id,
    required this.uid,
    required this.title,
    required this.content,
    this.category = 'Geral',
    required this.date,
    this.cloudId,
    int? updatedAt,
  }) : updatedAt = updatedAt ?? DateTime.now().millisecondsSinceEpoch;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'uid': uid,
      'title': title,
      'content': content,
      'category': category,
      'date': date,
      'cloudId': cloudId,
      'updatedAt': updatedAt,
    };
  }

  factory Note.fromMap(Map<String, dynamic> map) {
    return Note(
      id: map['id'] as int?,
      uid: map['uid'] as String,
      title: map['title'] as String,
      content: map['content'] as String,
      category: map['category'] as String? ?? 'Geral',
      date: map['date'] as String,
      cloudId: map['cloudId'] as String?,
      updatedAt: map['updatedAt'] as int? ?? 0,
    );
  }
}
