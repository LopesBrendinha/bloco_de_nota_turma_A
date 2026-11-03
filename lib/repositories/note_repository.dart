import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../database/database_helper.dart';
import '../models/note.dart';
import 'note_filter.dart';

const _idChars =
    'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
final _random = Random.secure();

// Mesmo formato dos IDs automáticos do Firestore: 20 caracteres [A-Za-z0-9].
@visibleForTesting
String newNoteId() => String.fromCharCodes(
  List.generate(
    20,
    (_) => _idChars.codeUnitAt(_random.nextInt(_idChars.length)),
  ),
);

String? _cleanCategory(String? category) {
  final trimmed = category?.trim() ?? '';
  return trimmed.isEmpty ? null : trimmed;
}

class NoteRepository {
  final DatabaseHelper _database = DatabaseHelper.instance;

  String get _uid => FirebaseAuth.instance.currentUser!.uid;

  int get _now => DateTime.now().millisecondsSinceEpoch;

  Future<List<Note>> getNotes() => _database.getNotes(_uid);

  Future<List<String>> getCategories() async =>
      mergeCategories(await _database.getCategories(_uid));

  Future<void> create({
    required String title,
    required String content,
    String? category,
  }) async {
    final now = _now;
    await _database.insertNote(
      Note(
        id: newNoteId(),
        uid: _uid,
        title: title,
        content: content,
        category: _cleanCategory(category),
        createdAt: now,
        updatedAt: now,
        syncStatus: 'pending',
      ),
    );
  }

  Future<void> update(
    Note note, {
    required String title,
    required String content,
    String? category,
  }) async {
    final cleaned = _cleanCategory(category);
    await _database.updateNote(
      note.copyWith(
        title: title,
        content: content,
        category: cleaned,
        clearCategory: cleaned == null,
        updatedAt: _now,
        syncStatus: 'pending',
      ),
    );
  }

  // Exclusão reversível: a linha fica no banco com deleted_at preenchido.
  Future<void> delete(Note note) async {
    final now = _now;
    await _database.updateNote(
      note.copyWith(deletedAt: now, updatedAt: now, syncStatus: 'pending'),
    );
  }
}
