import '../models/note.dart';

// Pesquisa em Dart, não com LIKE: o LIKE e o lower() do SQLite só ignoram
// maiúsculas em ASCII, então "ÁGUA" não encontraria "água".
// ponytail: filtra em memória, o que basta para centenas de notas.
// Se um dia ficar lento, mover a pesquisa para SQL com FTS (full-text search do SQLite).
List<Note> filterNotes(
  List<Note> notes, {
  String query = '',
  String? category,
}) {
  final q = query.trim().toLowerCase();
  final c = category?.toLowerCase();

  return notes.where((note) {
    if (c != null && note.category?.toLowerCase() != c) {
      return false;
    }
    if (q.isEmpty) {
      return true;
    }
    return note.title.toLowerCase().contains(q) ||
        note.content.toLowerCase().contains(q);
  }).toList();
}

List<String> mergeCategories(List<String> userCategories) {
  final seen = <String>{};
  final result = <String>[];

  for (final category in [...defaultCategories, ...userCategories]) {
    if (seen.add(category.toLowerCase())) {
      result.add(category);
    }
  }

  result.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  return result;
}
