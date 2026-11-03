import '../models/note.dart';

List<Note> sortNotesByUpdatedAt(
  Iterable<Note> notes, {
  bool newestFirst = true,
}) {
  final sortedNotes = notes.toList();
  sortedNotes.sort((first, second) {
    return newestFirst
        ? second.updatedAt.compareTo(first.updatedAt)
        : first.updatedAt.compareTo(second.updatedAt);
  });
  return sortedNotes;
}
