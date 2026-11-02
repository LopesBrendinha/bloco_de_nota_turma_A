class Note {
  final int? id;
  final String cloudId;
  final String uid;
  final String title;
  final String content;
  final String category;
  final String date;
  final bool pinned;

  const Note({
    this.id,
    required this.cloudId,
    required this.uid,
    required this.title,
    required this.content,
    required this.category,
    required this.date,
    this.pinned = false,
  });

  Map<String, dynamic> toMap() => {
    'id': id, 'cloudId': cloudId, 'uid': uid, 'title': title,
    'content': content, 'category': category, 'date': date,
    'pinned': pinned ? 1 : 0,
  };

  Map<String, dynamic> toCloud() => {
    'uid': uid, 'title': title, 'content': content,
    'category': category, 'date': date, 'pinned': pinned,
  };

  factory Note.fromMap(Map<String, dynamic> map) => Note(
    id: map['id'] as int?,
    cloudId: map['cloudId'] as String? ?? '',
    uid: map['uid'] as String,
    title: map['title'] as String,
    content: map['content'] as String,
    category: map['category'] as String? ?? 'Geral',
    date: map['date'] as String,
    pinned: (map['pinned'] ?? 0) == 1 || map['pinned'] == true,
  );

  factory Note.fromCloud(String id, Map<String, dynamic> map) => Note(
    cloudId: id, uid: map['uid'] as String,
    title: map['title'] as String? ?? '',
    content: map['content'] as String? ?? '',
    category: map['category'] as String? ?? 'Geral',
    date: map['date'] as String? ?? '',
    pinned: map['pinned'] as bool? ?? false,
  );
}
