import 'package:flutter/material.dart';

import '../models/note.dart';

/// Cartão de uma nota na lista.
///
/// Mostra título, trecho do conteúdo, categoria, data e se a nota já foi
/// enviada ao Firebase. Os botões da direita ([actions]) mudam conforme a
/// tela: na lista principal há "mover para a lixeira"; na lixeira há
/// "restaurar" e "excluir definitivamente".
class NoteCard extends StatelessWidget {
  final Note note;
  final VoidCallback? onTap;
  final List<Widget> actions;
  final NoteSort sort;

  const NoteCard({
    super.key,
    required this.note,
    this.onTap,
    this.actions = const [],
    this.sort = NoteSort.updatedAt,
  });

  String get _dateLabel {
    if (note.isDeleted && note.deletedAt != null) {
      return 'Excluída em ${Note.formatDateTime(note.deletedAt!)}';
    }

    if (sort == NoteSort.createdAt) {
      return 'Criada em ${Note.formatDateTime(note.createdAt)}';
    }

    return 'Atualizada em ${Note.formatDateTime(note.updatedAt)}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 8, 20),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFEDE5FA),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(
                  Icons.notes_rounded,
                  color: Color(0xFF6C4AB6),
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      note.title.isEmpty ? 'Sem título' : note.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF292333),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      note.content,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF77717F),
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 110),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEDE5FA),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              note.category,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF6C4AB6),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _dateLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF9A94A1),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Tooltip(
                          message: note.isSynced
                              ? 'Sincronizada com o Firebase'
                              : 'Aguardando sincronização',
                          child: Icon(
                            note.isSynced
                                ? Icons.cloud_done_outlined
                                : Icons.cloud_off_outlined,
                            size: 16,
                            color: note.isSynced
                                ? const Color(0xFF4C9A6A)
                                : const Color(0xFFC0892B),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              ...actions,
            ],
          ),
        ),
      ),
    );
  }
}
