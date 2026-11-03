import 'package:uuid/uuid.dart';

class NoteCategory {
  final String id, uid, name, revision;
  final bool dirty;
  NoteCategory({
    String? id,
    required this.uid,
    required this.name,
    this.dirty = true,
    String? revision,
  }) : id = id ?? const Uuid().v4(),
       revision = revision ?? const Uuid().v4();
  Map<String, Object?> toCloud() => {
    'uid': uid,
    'name': name,
    'revision': revision,
  };
  Map<String, Object?> toMap() => {
    ...toCloud(),
    'id': id,
    'dirty': dirty ? 1 : 0,
  };
  factory NoteCategory.fromMap(Map<String, Object?> m) => NoteCategory(
    id: m['id'] as String,
    uid: m['uid'] as String,
    name: m['name'] as String,
    dirty: m['dirty'] == 1,
    revision: m['revision'] as String,
  );
}
