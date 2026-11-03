import 'dart:math';

/// Modelo de uma nota.
///
/// O mesmo [id] (texto) é usado como chave primária no SQLite e como
/// ID do documento no Firestore, o que permite comparar as duas cópias.
class Note {
  /// Categorias que sempre aparecem para escolha.
  static const List<String> defaultCategories = [
    'Estudos',
    'Trabalho',
    'Pessoal',
  ];

  final String id;
  final String uid;
  final String title;
  final String content;
  final String category;

  /// Datas em milissegundos desde 1970 (facilita ordenar e comparar).
  final int createdAt;
  final int updatedAt;

  /// Lixeira: a nota continua salva, mas fica escondida da lista principal.
  final bool deleted;
  final int? deletedAt;

  /// `false` = existe alteração local que ainda não foi enviada ao Firebase.
  final bool synced;

  const Note({
    required this.id,
    required this.uid,
    required this.title,
    required this.content,
    required this.category,
    required this.createdAt,
    required this.updatedAt,
    this.deleted = false,
    this.deletedAt,
    this.synced = false,
  });

  /// Cria uma nota nova, com ID gerado no próprio aparelho.
  factory Note.create({
    required String uid,
    required String title,
    required String content,
    required String category,
  }) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return Note(
      id: generateId(),
      uid: uid,
      title: title,
      content: content,
      category: category,
      createdAt: now,
      updatedAt: now,
    );
  }

  static String generateId() {
    final random = Random.secure().nextInt(1 << 32);
    return '${DateTime.now().microsecondsSinceEpoch}-$random';
  }

  Note copyWith({
    String? title,
    String? content,
    String? category,
    int? updatedAt,
    bool? deleted,
    int? deletedAt,
    bool clearDeletedAt = false,
    bool? synced,
  }) {
    return Note(
      id: id,
      uid: uid,
      title: title ?? this.title,
      content: content ?? this.content,
      category: category ?? this.category,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deleted: deleted ?? this.deleted,
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
      synced: synced ?? this.synced,
    );
  }

  /// Data de última alteração no formato dd/mm/aaaa hh:mm.
  String get dateLabel {
    final d = DateTime.fromMillisecondsSinceEpoch(updatedAt);
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year} ${two(d.hour)}:${two(d.minute)}';
  }

  // ---------- SQLite ----------

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'uid': uid,
      'title': title,
      'content': content,
      'category': category,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'deleted': deleted ? 1 : 0,
      'deleted_at': deletedAt,
      'synced': synced ? 1 : 0,
    };
  }

  factory Note.fromMap(Map<String, dynamic> map) {
    return Note(
      id: map['id'] as String,
      uid: map['uid'] as String,
      title: map['title'] as String,
      content: map['content'] as String,
      category: map['category'] as String,
      createdAt: map['created_at'] as int,
      updatedAt: map['updated_at'] as int,
      deleted: (map['deleted'] as int) == 1,
      deletedAt: map['deleted_at'] as int?,
      synced: (map['synced'] as int) == 1,
    );
  }

  // ---------- Firestore ----------

  /// O uid não vai no documento: ele já está no caminho
  /// `users/{uid}/notes/{id}`.
  Map<String, dynamic> toRemoteMap() {
    return {
      'title': title,
      'content': content,
      'category': category,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'deleted': deleted,
      'deletedAt': deletedAt,
    };
  }

  factory Note.fromRemote(String id, String uid, Map<String, dynamic> data) {
    int toInt(dynamic value) => value is num ? value.toInt() : 0;

    return Note(
      id: id,
      uid: uid,
      title: (data['title'] as String?) ?? '',
      content: (data['content'] as String?) ?? '',
      category: (data['category'] as String?) ?? 'Pessoal',
      createdAt: toInt(data['createdAt']),
      updatedAt: toInt(data['updatedAt']),
      deleted: data['deleted'] == true,
      deletedAt: data['deletedAt'] is num
          ? (data['deletedAt'] as num).toInt()
          : null,
      synced: true,
    );
  }
}
