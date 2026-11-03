import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/note.dart';
import '../repositories/note_repository.dart';

class NoteFormPage extends StatefulWidget {
  final Note? note;

  const NoteFormPage({super.key, this.note});

  @override
  State<NoteFormPage> createState() => _NoteFormPageState();
}

class _NoteFormPageState extends State<NoteFormPage> {
  final titleController = TextEditingController();
  final contentController = TextEditingController();

  final NoteRepository repository = NoteRepository.instance;

  /// Categorias disponíveis para escolha: as padrão + as que o usuário
  /// já criou (e que existem em suas notas).
  final List<String> categories = [...Note.defaultCategories];

  String category = 'Pessoal';
  bool saving = false;

  bool get isEditing => widget.note != null;

  @override
  void initState() {
    super.initState();

    if (isEditing) {
      titleController.text = widget.note!.title;
      contentController.text = widget.note!.content;
      category = widget.note!.category;
    }

    if (!categories.contains(category)) {
      categories.add(category);
    }

    loadCategories();
  }

  Future<void> loadCategories() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final saved = await repository.getCategories(user.uid);

    if (!mounted) return;
    setState(() {
      for (final name in saved) {
        final exists = categories.any((c) => c.toLowerCase() == name.toLowerCase());
        if (!exists) {
          categories.add(name);
        }
      }
    });
  }

  Future<void> addCategory() async {
    final controller = TextEditingController();

    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Nova categoria'),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLength: 30,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(hintText: 'Nome da categoria'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, controller.text.trim()),
              child: const Text('Criar'),
            ),
          ],
        );
      },
    );

    if (name == null || name.isEmpty) return;

    final existing = categories.where(
      (c) => c.toLowerCase() == name.toLowerCase(),
    );

    setState(() {
      if (existing.isEmpty) {
        categories.add(name);
        category = name;
      } else {
        category = existing.first;
      }
    });
  }

  Future<void> saveNote() async {
    if (saving) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final title = titleController.text.trim();
    final content = contentController.text.trim();

    if (content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Escreva algum conteúdo para salvar a nota.')),
      );
      return;
    }

    // Limite aceito pelas regras de segurança do Firestore.
    if (content.length > 100000) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('A nota é muito grande (máximo de 100.000 caracteres).'),
        ),
      );
      return;
    }

    setState(() {
      saving = true;
    });

    final Note note = isEditing
        ? widget.note!.copyWith(
            title: title,
            content: content,
            category: category,
          )
        : Note.create(
            uid: user.uid,
            title: title,
            content: content,
            category: category,
          );

    // Grava só no SQLite (rápido). O envio ao Firebase é feito em segundo
    // plano pela tela anterior, então esta tela nunca espera a rede.
    try {
      await repository.saveNote(note);

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        saving = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(describeLocalError(e))));
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
          if (saving)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 14),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            IconButton(
              tooltip: 'Salvar',
              onPressed: saveNote,
              icon: const Icon(Icons.check_rounded),
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
              maxLength: 300,
              buildCounter:
                  (
                    context, {
                    required currentLength,
                    required isFocused,
                    maxLength,
                  }) => null,
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
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final name in categories)
                    ChoiceChip(
                      label: Text(name),
                      selected: category == name,
                      onSelected: (_) {
                        setState(() {
                          category = name;
                        });
                      },
                    ),
                  ActionChip(
                    avatar: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Nova categoria'),
                    onPressed: addCategory,
                  ),
                ],
              ),
            ),
            const Divider(color: Color(0xFFE4DFEA)),
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
