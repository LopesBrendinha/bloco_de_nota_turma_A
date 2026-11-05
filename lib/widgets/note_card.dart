import 'package:flutter/material.dart';

import '../models/note.dart';

class NoteCard extends StatelessWidget {
  final Note note;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const NoteCard({
    super.key,
    required this.note,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(
        bottom: 14,
      ),

      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),

      child: InkWell(
        borderRadius:
            BorderRadius.circular(22),
        onTap: onTap,

        child: Padding(
          padding: const EdgeInsets.all(20),

          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,

                decoration: BoxDecoration(
                  color:
                      const Color(0xFFEDE5FA),
                  borderRadius:
                      BorderRadius.circular(15),
                ),

                child: const Icon(
                  Icons.notes_rounded,
                  color:
                      Color(0xFF6C4AB6),
                ),
              ),

              const SizedBox(width: 15),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,

                  children: [
                    Text(
                      note.title.isEmpty
                          ? 'Sem título'
                          : note.title,
                      maxLines: 1,
                      overflow:
                          TextOverflow.ellipsis,

                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight:
                            FontWeight.bold,
                        color:
                            Color(0xFF292333),
                      ),
                    ),

                    const SizedBox(height: 6),

                    Text(
                      note.content,
                      maxLines: 2,
                      overflow:
                          TextOverflow.ellipsis,

                      style: const TextStyle(
                        color:
                            Color(0xFF77717F),
                        height: 1.4,
                      ),
                    ),

                    const SizedBox(height: 8),

                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment:
                          WrapCrossAlignment.center,

                      children: [
                        Text(
                          note.date,
                          style: const TextStyle(
                            fontSize: 11,
                            color:
                                Color(0xFF9A94A1),
                          ),
                        ),

                        // nuvem preenchida = já está no Firebase
                        // nuvem com seta = falta enviar
                        Icon(
                          note.synced == 1
                              ? Icons.cloud_done_outlined
                              : Icons.cloud_upload_outlined,
                          size: 14,
                          color: note.synced == 1
                              ? const Color(0xFF9A94A1)
                              : const Color(0xFFB7791F),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              IconButton(
                onPressed: onDelete,
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  color:
                      Color(0xFFB45F6C),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}