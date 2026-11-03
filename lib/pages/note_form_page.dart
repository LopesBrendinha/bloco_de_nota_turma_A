
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../database/database_helper.dart';
import '../models/note.dart';
import '../services/sync_service.dart';

class NoteFormPage extends StatefulWidget {
  final Note? note;

  const NoteFormPage({super.key, this.note});

  @override
  State<NoteFormPage> createState() => _NoteFormPageState();
}

class _NoteFormPageState extends State<NoteFormPage> {
  final titleController = TextEditingController();
  final contentController = TextEditingController();

  final database = DatabaseHelper.instance;
  final syncService = SyncService();

  final List<String> categories = [
    'Geral',
    'Estudos',
    'Trabalho',
    'Pessoal',
    'Projetos',
  ];

  late String selectedCategory;
  bool isSaving = false;

  bool get isEditing => widget.note != null;

  @override
  void initState() {
    super.initState();

    selectedCategory = widget.note?.category ?? 'Geral';

    if (isEditing) {
      titleController.text = widget.note!.title;
      contentController.text = widget.note!.content;
    }
  }

  Future<void> saveNote() async {
    if (isSaving) return;

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return;

    final title = titleController.text.trim();
    final content = contentController.text.trim();

    if (content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Digite algum conteúdo para a nota.'),
        ),
      );
      return;
    }

    setState(() {
      isSaving = true;
    });

    try {
      final now = DateTime.now();

      final date =
          '${now.day.toString().padLeft(2, '0')}/'
          '${now.month.toString().padLeft(2, '0')}/'
          '${now.year} '
          '${now.hour.toString().padLeft(2, '0')}:'
          '${now.minute.toString().padLeft(2, '0')}';

      final note = Note(
        id: widget.note?.id,
        uid: user.uid,
        title: title,
        content: content,
        date: date,
        category: selectedCategory,
        cloudId: widget.note?.cloudId,
        isSynced: false,

        // Preserva o status de favorito durante a edição.
        isFavorite: widget.note?.isFavorite ?? false,
      );

      late Note savedNote;

      // Salva primeiro no banco de dados local.
      if (isEditing) {
        await database.updateNote(note);
        savedNote = note;
      } else {
        final id = await database.insertNote(note);

        savedNote = Note(
          id: id,
          uid: note.uid,
          title: note.title,
          content: note.content,
          date: note.date,
          category: note.category,
          cloudId: note.cloudId,
          isSynced: false,
          isFavorite: note.isFavorite,
        );
      }

      // Tenta sincronizar com o Firebase.
      try {
        await syncService.uploadNote(savedNote);
      } catch (error) {
        debugPrint(
          'Nota salva localmente. Sincronização pendente: $error',
        );
      }

      if (!mounted) return;

      Navigator.pop(context);
    } catch (error) {
      debugPrint('Erro ao salvar nota: $error');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não foi possível salvar a nota.'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isSaving = false;
        });
      }
    }
  }

  @override
  void dispose() {
    titleController.dispose();
    contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          isEditing ? 'Editar nota' : 'Nova nota',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            onPressed: isSaving ? null : saveNote,
            icon: isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          children: [
            TextField(
              controller: titleController,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF292333),
              ),
              decoration: const InputDecoration(
                hintText: 'Título',
                border: InputBorder.none,
                filled: false,
                contentPadding: EdgeInsets.symmetric(horizontal: 4),
              ),
            ),
            const Divider(color: Color(0xFFE4DFEA)),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Categoria',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
              ),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: selectedCategory,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.category_outlined),
              ),
              items: categories.map((category) {
                return DropdownMenuItem(
                  value: category,
                  child: Text(category),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    selectedCategory = value;
                  });
                }
              },
            ),
            const SizedBox(height: 12),
            Expanded(
              child: TextField(
                controller: contentController,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                style: const TextStyle(
                  fontSize: 17,
                  height: 1.5,
                  color: Color(0xFF40394A),
                ),
                decoration: const InputDecoration(
                  hintText: 'Comece a escrever...',
                  border: InputBorder.none,
                  filled: false,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 15,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
