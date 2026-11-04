import '../models/note.dart';

List<Note> searchNotes(
  Iterable<Note> notes, {
  String query = '',
  String category = 'Todas',
}) {
  final normalizedQuery = query.trim().toLowerCase();
  return notes.where((note) {
    final matchesText =
        normalizedQuery.isEmpty ||
        note.title.toLowerCase().contains(normalizedQuery) ||
        note.content.toLowerCase().contains(normalizedQuery);
    final matchesCategory = category == 'Todas' || note.category == category;
    return matchesText && matchesCategory;
  }).toList();
}
