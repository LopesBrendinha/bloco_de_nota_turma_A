const defaultCategories = ['Estudos', 'Trabalho', 'Pessoal'];

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
    bool clearCategory = false,
    int? updatedAt,
    int? deletedAt,
    bool clearDeletedAt = false,
    String? syncStatus,
  }) {
    return Note(
      id: id,
      uid: uid,
      title: title ?? this.title,
      content: content ?? this.content,
      category: clearCategory ? null : (category ?? this.category),
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
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

  // Documento do Firestore: as mesmas colunas do SQLite, menos id (é o ID do
  // documento) e sync_status (só existe no aparelho).
  Map<String, dynamic> toFirestore() =>
      toMap()..remove('id')..remove('sync_status');

  // data precisa ter o 'id' (o FirestoreService coloca o doc.id no mapa).
  factory Note.fromFirestore(Map<String, dynamic> data) =>
      Note.fromMap({...data, 'sync_status': 'synced'});
}
