class Note {
  final int? id;

  final String uid;

  final String title;
  final String content;
  final String category;
  final String? cloudId;
  final bool isSynced;

  final String date;

  Note({
    this.id,
    required this.uid,
    required this.title,
    required this.content,
    required this.date,
    this.category = 'Pessoal',
    this.cloudId,
    this.isSynced = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'uid': uid,
      'title': title,
      'content': content,
      'category': category,
      'cloud_id': cloudId,
      'is_synced': isSynced ? 1 : 0,
      'date': date,
    };
  }

  factory Note.fromMap(Map<String, dynamic> map) {
    return Note(
      id: map['id'],
      uid: map['uid'],
      title: map['title'],
      content: map['content'],
      category: map['category'] ?? 'Pessoal',
      cloudId: map['cloud_id'],
      isSynced: map['is_synced'] == 1 || map['is_synced'] == true,
      date: map['date'],
    );
  }

  Map<String, dynamic> toCloudMap() {
    return {
      'uid': uid,
      'title': title,
      'content': content,
      'category': category,
      'date': date,
    };
  }

  factory Note.fromCloudMap(String cloudId, Map<String, dynamic> map) {
    return Note(
      uid: map['uid'],
      title: map['title'],
      content: map['content'],
      category: map['category'] ?? 'Pessoal',
      date: map['date'],
      cloudId: cloudId,
      isSynced: true,
    );
  }

  Note copyWith({int? id, String? cloudId, bool? isSynced}) {
    return Note(
      id: id ?? this.id,
      uid: uid,
      title: title,
      content: content,
      category: category,
      date: date,
      cloudId: cloudId ?? this.cloudId,
      isSynced: isSynced ?? this.isSynced,
    );
  }
}
