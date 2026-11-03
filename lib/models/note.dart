import 'package:uuid/uuid.dart';

class Note {
  final int? id;
  final String cloudId, uid, title, content, category, revision;
  final bool archived, deleted, dirty;
  final DateTime updatedAt;
  final DateTime? reminderAt;
  Note({
    this.id,
    String? cloudId,
    required this.uid,
    required this.title,
    required this.content,
    this.category = 'Pessoal',
    this.archived = false,
    this.deleted = false,
    this.dirty = true,
    DateTime? updatedAt,
    this.reminderAt,
    String? revision,
  }) : cloudId = cloudId ?? const Uuid().v4(),
       updatedAt = updatedAt ?? DateTime.now().toUtc(),
       revision = revision ?? const Uuid().v4();
  String get date => formatDate(updatedAt);
  static String formatDate(DateTime value) {
    final d = value.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year} ${two(d.hour)}:${two(d.minute)}';
  }

  Note edit({
    String? title,
    String? content,
    String? category,
    bool? archived,
    bool? deleted,
    DateTime? reminderAt,
    bool clearReminder = false,
  }) => Note(
    id: id,
    cloudId: cloudId,
    uid: uid,
    title: title ?? this.title,
    content: content ?? this.content,
    category: category ?? this.category,
    archived: archived ?? this.archived,
    deleted: deleted ?? this.deleted,
    reminderAt: clearReminder ? null : reminderAt ?? this.reminderAt,
  );
  Map<String, Object?> toCloud() => {
    'uid': uid,
    'title': title,
    'content': content,
    'category': category,
    'archived': archived,
    'deleted': deleted,
    'updatedAt': updatedAt.millisecondsSinceEpoch,
    'reminderAt': reminderAt?.millisecondsSinceEpoch,
    'revision': revision,
  };
  Map<String, Object?> toMap() => {
    ...toCloud(),
    'id': id,
    'cloudId': cloudId,
    'archived': archived ? 1 : 0,
    'deleted': deleted ? 1 : 0,
    'dirty': dirty ? 1 : 0,
    'date': date,
  };
  factory Note.fromMap(Map<String, Object?> m) => Note(
    id: m['id'] as int?,
    cloudId: m['cloudId'] as String,
    uid: m['uid'] as String,
    title: m['title'] as String,
    content: m['content'] as String,
    category: m['category'] as String,
    archived: m['archived'] == 1,
    deleted: m['deleted'] == 1,
    dirty: m['dirty'] == 1,
    updatedAt: DateTime.fromMillisecondsSinceEpoch(
      m['updatedAt'] as int,
      isUtc: true,
    ),
    reminderAt: m['reminderAt'] == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(
            m['reminderAt'] as int,
            isUtc: true,
          ),
    revision: m['revision'] as String,
  );
  factory Note.fromCloud(String id, Map<String, dynamic> m) => Note.fromMap({
    ...m,
    'id': null,
    'cloudId': id,
    'archived': m['archived'] == true ? 1 : 0,
    'deleted': m['deleted'] == true ? 1 : 0,
    'dirty': 0,
  });
}
