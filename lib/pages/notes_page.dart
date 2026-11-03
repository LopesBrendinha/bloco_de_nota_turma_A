import 'package:bloco_de_nota_turma_a/models/note.dart';
import 'package:bloco_de_nota_turma_a/pages/login_page.dart';
import 'package:bloco_de_nota_turma_a/pages/note_form_page.dart';
import 'package:bloco_de_nota_turma_a/services/auth_service.dart';
import 'package:bloco_de_nota_turma_a/services/note_repository.dart';
import 'package:bloco_de_nota_turma_a/services/note_sorting.dart';
import 'package:bloco_de_nota_turma_a/widgets/note_card.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class NotesPage extends StatefulWidget {
  const NotesPage({super.key});

  @override
  State<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends State<NotesPage> {
  final AuthService authService = AuthService();
  final NoteRepository repository = NoteRepository();
  final searchController = TextEditingController();

  List<Note> notes = [];
  bool syncing = false;
  bool syncFailed = false;
  String searchText = '';
  String categoryFilter = 'Todas';
  bool newestFirst = true;
  @override
  void initState() {
    super.initState();
    loadNotes();
  }

  Future<void> loadNotes() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    if (mounted) setState(() => syncing = true);
    var failed = false;
    try {
      await repository.synchronize(user.uid);
    } catch (_) {
      // Notes remain available from SQLite while Firebase is unavailable.
      failed = true;
    }
    final result = await repository.getLocalNotes(user.uid);

    if (mounted) {
      setState(() {
        notes = result;
        syncing = false;
        syncFailed = failed;
        if (categoryFilter != 'Todas' &&
            !result.any((note) => note.category == categoryFilter)) {
          categoryFilter = 'Todas';
        }
      });
    }
  }

  Future<void> deleteNote(Note note) async {
    try {
      await repository.delete(note);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não foi possível excluir a nota da nuvem.'),
          ),
        );
      }
    }
    await loadNotes();
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Nota deletada com sucesso!")));
    }
  }

  Future<void> logout() async {
    await authService.logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => LoginPage()),
      (route) => false,
    );
  }

  Future<void> openEditNote(Note note) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => NoteFormPage(note: note)),
    );

    await loadNotes();
  }

  Future<void> openNewNote() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => NoteFormPage()),
    );

    await loadNotes();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final sortedNotes = sortNotesByUpdatedAt(notes, newestFirst: newestFirst);
    final filteredNotes = sortedNotes.where((note) {
      final query = searchText.toLowerCase();
      final matchesSearch =
          note.title.toLowerCase().contains(query) ||
          note.content.toLowerCase().contains(query);
      final matchesCategory =
          categoryFilter == 'Todas' || note.category == categoryFilter;
      return matchesSearch && matchesCategory;
    }).toList();
    final categories = {'Todas', ...notes.map((note) => note.category)}.toList()
      ..sort((a, b) {
        if (a == 'Todas') return -1;
        if (b == 'Todas') return 1;
        return a.toLowerCase().compareTo(b.toLowerCase());
      });
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Minhas notas",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          PopupMenuButton<bool>(
            tooltip: 'Ordenar notas',
            initialValue: newestFirst,
            onSelected: (value) => setState(() => newestFirst = value),
            itemBuilder: (context) => const [
              PopupMenuItem(value: true, child: Text('Mais recentes primeiro')),
              PopupMenuItem(value: false, child: Text('Mais antigas primeiro')),
            ],
            icon: const Icon(Icons.sort_rounded),
          ),
          IconButton(
            tooltip: 'Sincronizar agora',
            onPressed: syncing ? null : loadNotes,
            icon: syncing
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync_rounded),
          ),
          IconButton(
            tooltip: "Sair",
            onPressed: logout,
            icon: Icon(Icons.logout_rounded),
          ),
          SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: openNewNote,
        backgroundColor: Color(0xff6c4ab6),
        foregroundColor: Colors.white,
        icon: Icon(Icons.add_rounded),
        label: Text("Nova Nota", style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Padding(
        padding: EdgeInsets.fromLTRB(20, 10, 20, 90),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              user?.email ?? "",
              style: TextStyle(color: Color(0xFF77717f), fontSize: 13),
            ),
            if (syncFailed)
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text(
                  'Não foi possível sincronizar com o Firebase. As notas locais continuam disponíveis.',
                  style: TextStyle(color: Color(0xFF77717F), fontSize: 12),
                ),
              ),
            const SizedBox(height: 12),
            TextField(
              controller: searchController,
              onChanged: (value) => setState(() => searchText = value.trim()),
              decoration: InputDecoration(
                hintText: 'Buscar notas',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: syncing
                    ? const Padding(
                        padding: EdgeInsets.all(14),
                        child: SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 36,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: categories.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final category = categories[index];
                  return ChoiceChip(
                    label: Text(category),
                    selected: categoryFilter == category,
                    onSelected: (_) =>
                        setState(() => categoryFilter = category),
                    visualDensity: VisualDensity.compact,
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            if (filteredNotes.isEmpty)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 100,
                        height: 100,

                        decoration: BoxDecoration(
                          color: Color(0xffede5fa),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.sticky_note_2_rounded,
                          color: Color(0xffede5fa),
                        ),
                      ),
                      SizedBox(height: 25),
                      Text(
                        searchText.isEmpty && categoryFilter == 'Todas'
                            ? "Nenhuma nota ainda"
                            : "Nenhuma nota encontrada",
                      ),
                      SizedBox(height: 8),
                      Text(
                        searchText.isEmpty && categoryFilter == 'Todas'
                            ? 'Crie sua primeira nota.'
                            : 'Altere a busca ou selecione outra categoria.',
                      ),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  itemCount: filteredNotes.length,
                  itemBuilder: (context, index) {
                    final note = filteredNotes[index];

                    return NoteCard(
                      note: note,
                      onTap: () => openEditNote(note),
                      onDelete: () => deleteNote(note),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
