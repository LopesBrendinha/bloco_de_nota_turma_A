class Note{
  final int? id;

  // id do documento da nota no Firestore
  final String? firebaseId;

  final String uid;

  final String title;
  final String content;
  final String category;

  final String date;

  // datas em milissegundos, usadas para ordenar e na sincronização
  final int createdAt;
  final int updatedAt;

  // 0 = ainda não foi enviada para o Firebase, 1 = sincronizada
  final int synced;

  // 1 = está na lixeira
  final int trashed;

  // 1 = excluída definitivamente, falta apagar no Firebase
  final int deleted;

  Note({
    this.id,
    this.firebaseId,
    required this.uid,
    required this.title,
    required this.content,
    required this.category,
    required this.date,
    required this.createdAt,
    required this.updatedAt,
    this.synced = 0,
    this.trashed = 0,
    this.deleted = 0,
  });

  Map<String, dynamic> toMap(){
    return{
      'id' : id,
      'firebaseId' : firebaseId,
      'uid' : uid,
      'title' : title,
      'content' : content,
      'category' : category,
      'date' : date,
      'createdAt' : createdAt,
      'updatedAt' : updatedAt,
      'synced' : synced,
      'trashed' : trashed,
      'deleted' : deleted,
    };
  }

  factory Note.fromMap(Map<String,dynamic> map){
    return Note(
      id: map['id'],
      firebaseId: map['firebaseId'],
      uid: map['uid'],
      title: map['title'],
      content: map['content'],
      category: map['category'],
      date: map['date'],
      createdAt: map['createdAt'],
      updatedAt: map['updatedAt'],
      synced: map['synced'],
      trashed: map['trashed'],
      deleted: map['deleted'],
    );

  }

  // o que vai para o Firestore (id, synced e deleted só existem no SQLite)
  Map<String, dynamic> toFirestore(){
    return{
      'uid' : uid,
      'title' : title,
      'content' : content,
      'category' : category,
      'date' : date,
      'createdAt' : createdAt,
      'updatedAt' : updatedAt,
      'trashed' : trashed == 1,
    };
  }

  factory Note.fromFirestore(String docId, Map<String,dynamic> map){
    return Note(
      firebaseId: docId,
      uid: map['uid'],
      title: map['title'] ?? '',
      content: map['content'] ?? '',
      category: map['category'] ?? 'Pessoal',
      date: map['date'] ?? '',
      createdAt: map['createdAt'] ?? 0,
      updatedAt: map['updatedAt'] ?? 0,
      // se veio do Firebase então já está sincronizada
      synced: 1,
      trashed: map['trashed'] == true ? 1 : 0,
    );
  }

  Note copyWith({
    int? id,
    String? firebaseId,
    String? category,
    int? updatedAt,
    int? synced,
    int? trashed,
    int? deleted,
  }){
    return Note(
      id: id ?? this.id,
      firebaseId: firebaseId ?? this.firebaseId,
      uid: uid,
      title: title,
      content: content,
      category: category ?? this.category,
      date: date,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      synced: synced ?? this.synced,
      trashed: trashed ?? this.trashed,
      deleted: deleted ?? this.deleted,
    );
  }

}
