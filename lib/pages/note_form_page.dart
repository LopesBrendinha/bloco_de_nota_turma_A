import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/note.dart';
import '../services/note_repository.dart';

class NoteFormPage extends StatefulWidget {
  final Note? note;

  const NoteFormPage({super.key, this.note});

  @override
  State<NoteFormPage> createState() => _NoteFormPageState();
}

class _NoteFormPageState extends State<NoteFormPage> {
  final titleController = TextEditingController();
  final contentController = TextEditingController();
  final repository = NoteRepository();
  List<String> categories = ['Geral'];
  late String selectedCategory;
  bool saving = false;

  bool get isEditing => widget.note != null;

  @override
  void initState() {
    super.initState();
    titleController.text = widget.note?.title ?? '';
    contentController.text = widget.note?.content ?? '';
    selectedCategory = widget.note?.category ?? 'Geral';
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      await repository.refreshCategories(uid);
    } catch (_) {
      // Continue with categories already stored on this device.
    }
    try {
      final savedCategories = await repository.getCategories(uid);
      if (!mounted) return;
      final loaded = {'Geral', ...savedCategories, selectedCategory}.toList()
        ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      setState(() => categories = loaded);
    } catch (_) {
      // The default and current category remain selectable while offline.
    }
  }

  Future<void> _createCategory() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Nova categoria'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 50,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(hintText: 'Ex.: Estudos'),
          onSubmitted: (value) => Navigator.pop(dialogContext, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text('Criar'),
          ),
        ],
      ),
    );
    controller.dispose();

    final normalizedName = name?.trim() ?? '';
    if (normalizedName.isEmpty || !mounted) return;
    final existing = categories.where(
      (category) => category.toLowerCase() == normalizedName.toLowerCase(),
    );
    final category = existing.isEmpty ? normalizedName : existing.first;

    try {
      await repository.createCategory(
        FirebaseAuth.instance.currentUser!.uid,
        category,
      );
      if (!mounted) return;
      setState(() {
        categories = {...categories, category}.toList()
          ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
        selectedCategory = category;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível criar a categoria.')),
      );
    }
  }

  Future<void> saveNote() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || saving) return;

    final title = titleController.text.trim();
    final content = contentController.text.trim();
    if (title.isEmpty && content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Digite um título ou o conteúdo da nota.'),
        ),
      );
      return;
    }

    setState(() => saving = true);
    final now = DateTime.now();
    final date =
        '${now.day.toString().padLeft(2, '0')}/'
        '${now.month.toString().padLeft(2, '0')}/'
        '${now.year} ${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}';
    final note = Note(
      id: widget.note?.id,
      uid: user.uid,
      title: title,
      content: content,
      category: selectedCategory,
      date: date,
      cloudId: widget.note?.cloudId,
    );

    try {
      await repository.save(note);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (!mounted) return;
      setState(() => saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível salvar a nota. Tente novamente.'),
        ),
      );
    }
  }

  @override
  void dispose() {
    titleController.dispose();
    contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        isEditing ? 'Editar nota' : 'Nova nota',
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      actions: [
        IconButton(
          tooltip: 'Salvar nota',
          onPressed: saving ? null : saveNote,
          icon: saving
              ? const SizedBox.square(
                  dimension: 20,
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
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  key: ValueKey(selectedCategory),
                  initialValue: selectedCategory,
                  decoration: const InputDecoration(
                    labelText: 'Categoria',
                    prefixIcon: Icon(Icons.folder_outlined),
                  ),
                  items: categories
                      .map(
                        (category) => DropdownMenuItem(
                          value: category,
                          child: Text(category),
                        ),
                      )
                      .toList(),
                  onChanged: (category) {
                    if (category != null) {
                      setState(() => selectedCategory = category);
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                tooltip: 'Criar categoria',
                onPressed: _createCategory,
                icon: const Icon(Icons.create_new_folder_outlined),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: titleController,
            textCapitalization: TextCapitalization.sentences,
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
          Expanded(
            child: TextField(
              controller: contentController,
              maxLines: null,
              expands: true,
              textCapitalization: TextCapitalization.sentences,
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
