import 'package:bloco_de_nota_turma_a/models/note.dart';
import 'package:bloco_de_nota_turma_a/repositories/notes_repository.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class NoteFormPage extends StatefulWidget {
  final Note? note;

  const NoteFormPage({super.key, this.note});

  @override
  State<NoteFormPage> createState() => _NoteFormPageState();
}

class _NoteFormPageState extends State<NoteFormPage> {
  final titleController = TextEditingController();
  final contentController = TextEditingController();

  final NotesRepository repository = NotesRepository();

  late String selectedCategory;
  late List<String> categories;
  bool saving = false;

  bool get isEditing => widget.note != null;

  @override
  void initState() {
    super.initState();

    if (isEditing) {
      titleController.text = widget.note!.title;
      contentController.text = widget.note!.content;
    }

    selectedCategory = widget.note?.category ?? Note.fallbackCategory;
    categories = _mergeCategories(const []);

    _loadCategories();
  }

  /// Categorias padrão + categorias já usadas pelo usuário + a selecionada.
  List<String> _mergeCategories(List<String> existing) {
    final result = <String>[...Note.defaultCategories];

    for (final category in [...existing, selectedCategory]) {
      final alreadyListed = result.any(
        (item) => item.toLowerCase() == category.toLowerCase(),
      );

      if (!alreadyListed) {
        result.add(category);
      }
    }

    return result;
  }

  Future<void> _loadCategories() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final existing = await repository.getCategories(user.uid);

    if (!mounted) return;

    setState(() {
      categories = _mergeCategories(existing);
    });
  }

  Future<void> _createCategory() async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => const _CategoryDialog(),
    );

    if (name == null || name.isEmpty || !mounted) return;

    // Se já existe uma categoria com o mesmo nome, apenas a seleciona.
    final existing = categories.where(
      (item) => item.toLowerCase() == name.toLowerCase(),
    );

    setState(() {
      if (existing.isNotEmpty) {
        selectedCategory = existing.first;
      } else {
        categories = [...categories, name];
        selectedCategory = name;
      }
    });
  }

  void _showMessage(String text) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> saveNote() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null || saving) return;

    final title = titleController.text.trim();
    final content = contentController.text.trim();

    if (title.isEmpty && content.isEmpty) {
      _showMessage('Escreva um título ou um conteúdo para salvar.');
      return;
    }

    setState(() {
      saving = true;
    });

    // Guardamos antes do await: depois de fechar a tela o context não é mais
    // seguro, mas o messenger do app continua válido.
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    final base = widget.note;
    final note = base == null
        ? Note.create(
            uid: user.uid,
            title: title,
            content: content,
            category: selectedCategory,
          )
        : base.copyWith(
            title: title,
            content: content,
            category: selectedCategory,
          );

    final SyncResult result;

    try {
      result = await repository.saveNote(note);
    } catch (_) {
      // Falha ao gravar no SQLite (a falha do Firebase não cai aqui).
      if (mounted) {
        setState(() {
          saving = false;
        });
      }

      _showMessage('Não foi possível salvar a nota no aparelho.');
      return;
    }

    navigator.pop();

    if (!result.success) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              'Nota salva no aparelho. ${result.message} '
              'Ela será enviada na próxima sincronização.',
            ),
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
                  width: 22,
                  height: 22,
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
            Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final category in categories)
                    ChoiceChip(
                      label: Text(category),
                      selected: selectedCategory == category,
                      onSelected: (_) {
                        setState(() {
                          selectedCategory = category;
                        });
                      },
                    ),
                  ActionChip(
                    avatar: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Nova categoria'),
                    onPressed: _createCategory,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
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

/// Diálogo para digitar o nome de uma nova categoria.
/// É um widget próprio para que o controller seja descartado com segurança.
class _CategoryDialog extends StatefulWidget {
  const _CategoryDialog();

  @override
  State<_CategoryDialog> createState() => _CategoryDialogState();
}

class _CategoryDialogState extends State<_CategoryDialog> {
  final controller = TextEditingController();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void _submit() {
    Navigator.pop(context, controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nova categoria'),
      content: TextField(
        controller: controller,
        autofocus: true,
        maxLength: 30,
        textCapitalization: TextCapitalization.sentences,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _submit(),
        decoration: const InputDecoration(hintText: 'Ex.: Receitas'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        TextButton(onPressed: _submit, child: const Text('Criar')),
      ],
    );
  }
}
