import 'package:flutter/material.dart';
import '../models/note.dart';

class NoteCard extends StatelessWidget {
  final Note note;
  final VoidCallback onTap, onDelete, onArchive;
  const NoteCard({
    super.key,
    required this.note,
    required this.onTap,
    required this.onDelete,
    required this.onArchive,
  });
  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 12),
    child: InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    note.title.isEmpty ? 'Sem título' : note.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  tooltip: note.archived ? 'Desarquivar' : 'Arquivar',
                  onPressed: onArchive,
                  icon: Icon(
                    note.archived
                        ? Icons.unarchive_outlined
                        : Icons.archive_outlined,
                  ),
                ),
                IconButton(
                  tooltip: 'Excluir nota',
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            Text(note.content, maxLines: 3, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 6,
              children: [
                Text(
                  note.category,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(note.date),
                if (note.reminderAt != null)
                  Text('Lembrete: ${Note.formatDate(note.reminderAt!)}'),
                Text(
                  note.dirty ? 'Envio pendente' : 'Na nuvem',
                  style: TextStyle(
                    color: note.dirty ? Colors.brown : Colors.teal,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
