import 'dart:math';

/// Critério de ordenação da lista de notas.
enum NoteSort { createdAt, updatedAt }

/// Representa uma nota do aplicativo.
///
/// A mesma classe é usada nos dois armazenamentos:
///  * SQLite (local)  -> [toMap] / [Note.fromMap]
///  * Firestore (nuvem) -> [toFirestoreMap] / [Note.fromFirestore]
///
/// Os campos de controle `isSynced` e `isPurged` existem somente no SQLite:
/// eles dizem se a nota já foi enviada ao Firebase e se ela foi excluída
/// definitivamente e aguarda a remoção na nuvem.
class Note {
  static const List<String> defaultCategories = [
    'Estudos',
    'Trabalho',
    'Pessoal',
  ];
  static const String fallbackCategory = 'Pessoal';

  /// Identificador gerado no aparelho. Também é o ID do documento no Firestore,
  /// o que permite criar notas offline sem conflito de IDs.
  final String id;

  /// UID do usuário autenticado dono da nota.
  final String uid;

  final String title;
  final String content;
  final String category;

  final DateTime createdAt;
  final DateTime updatedAt;

  /// `true` quando a nota está na lixeira.
  final bool isDeleted;
  final DateTime? deletedAt;

  /// `true` quando a versão local já foi enviada ao Firebase.
  final bool isSynced;

  /// `true` quando a nota foi excluída definitivamente, mas a exclusão ainda
  /// não chegou ao Firebase (aparelho sem conexão).
  final bool isPurged;

  const Note({
    required this.id,
    required this.uid,
    required this.title,
    required this.content,
    required this.category,
    required this.createdAt,
    required this.updatedAt,
    this.isDeleted = false,
    this.deletedAt,
    this.isSynced = false,
    this.isPurged = false,
  });

  /// Cria uma nota nova, com ID e datas gerados agora.
  factory Note.create({
    required String uid,
    required String title,
    required String content,
    required String category,
  }) {
    final now = DateTime.now();

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

  /// Gera um ID único sem depender de servidor (tempo + sufixo aleatório).
  static String generateId() {
    final random = Random.secure();
    final time = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    final salt = List.generate(
      6,
      (_) => random.nextInt(36).toRadixString(36),
    ).join();

    return '$time$salt';
  }

  /// Formata como `dd/MM/yyyy HH:mm`.
  static String formatDateTime(DateTime date) {
    String two(int value) => value.toString().padLeft(2, '0');

    return '${two(date.day)}/${two(date.month)}/${date.year} '
        '${two(date.hour)}:${two(date.minute)}';
  }

  String get dateLabel => formatDateTime(updatedAt);

  Note copyWith({
    String? title,
    String? content,
    String? category,
    DateTime? updatedAt,
    bool? isDeleted,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
    bool? isSynced,
    bool? isPurged,
  }) {
    return Note(
      id: id,
      uid: uid,
      title: title ?? this.title,
      content: content ?? this.content,
      category: category ?? this.category,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
      isSynced: isSynced ?? this.isSynced,
      isPurged: isPurged ?? this.isPurged,
    );
  }

  /// Mapa gravado na tabela `notes` do SQLite.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'uid': uid,
      'title': title,
      'content': content,
      'category': category,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
      'deleted': isDeleted ? 1 : 0,
      'deleted_at': deletedAt?.millisecondsSinceEpoch,
      'synced': isSynced ? 1 : 0,
      'purged': isPurged ? 1 : 0,
    };
  }

  factory Note.fromMap(Map<String, dynamic> map) {
    final deletedAtMs = map['deleted_at'] as int?;

    return Note(
      id: map['id'] as String,
      uid: map['uid'] as String,
      title: map['title'] as String,
      content: map['content'] as String,
      category: map['category'] as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int),
      isDeleted: (map['deleted'] as int) == 1,
      deletedAt: deletedAtMs == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(deletedAtMs),
      isSynced: (map['synced'] as int) == 1,
      isPurged: (map['purged'] as int) == 1,
    );
  }

  /// Documento gravado em `users/{uid}/notes/{id}` no Firestore.
  /// As flags locais (`synced`, `purged`) não são enviadas.
  Map<String, dynamic> toFirestoreMap() {
    return {
      'uid': uid,
      'title': title,
      'content': content,
      'category': category,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
      'deleted': isDeleted,
      'deletedAt': deletedAt?.millisecondsSinceEpoch,
    };
  }

  /// Reconstrói a nota a partir de um documento do Firestore.
  /// Tudo que vem da nuvem já está sincronizado (`isSynced = true`).
  factory Note.fromFirestore(
    String id,
    String uid,
    Map<String, dynamic> data,
  ) {
    final createdMs = (data['createdAt'] as num?)?.toInt() ?? 0;
    final updatedMs = (data['updatedAt'] as num?)?.toInt() ?? createdMs;
    final deletedAtMs = (data['deletedAt'] as num?)?.toInt();

    return Note(
      id: id,
      uid: uid,
      title: (data['title'] as String?) ?? '',
      content: (data['content'] as String?) ?? '',
      category: (data['category'] as String?) ?? fallbackCategory,
      createdAt: DateTime.fromMillisecondsSinceEpoch(createdMs),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(updatedMs),
      isDeleted: (data['deleted'] as bool?) ?? false,
      deletedAt: deletedAtMs == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(deletedAtMs),
      isSynced: true,
    );
  }
}
