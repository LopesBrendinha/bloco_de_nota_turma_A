import 'package:bloco_de_nota_turma_a/database/database_helper.dart';
import 'package:bloco_de_nota_turma_a/models/note.dart';
import 'package:bloco_de_nota_turma_a/pages/login_page.dart';
import 'package:bloco_de_nota_turma_a/pages/note_form_page.dart';
import 'package:bloco_de_nota_turma_a/services/auth_service.dart';
import 'package:bloco_de_nota_turma_a/widgets/note_card.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

enum NoteSortOrder {
  newest('Mais recentes'),
  oldest('Mais antigas'),
  recentlyUpdated('Alteradas recentemente'),
  leastRecentlyUpdated('Inalterado há tempo');

  const NoteSortOrder(this.label);
  final String label;
}

class NotesPage extends StatefulWidget {
  const NotesPage({super.key});

  @override
  State<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends State<NotesPage> {
  final DatabaseHelper database = DatabaseHelper.instance;
  final AuthService authService = AuthService();
  final TextEditingController searchController = TextEditingController();

  List<Note> notes = [];
  String selectedCategory = 'Todas';
  NoteSortOrder sortOrder = NoteSortOrder.newest;

  @override
  void initState() {
    super.initState();
    loadNotes();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> loadNotes() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final result = await database.getNotes(user.uid);
    if (mounted) setState(() => notes = result);
  }

  List<Note> get visibleNotes {
    final query = searchController.text.trim().toLowerCase();
    final filtered = notes.where((note) {
      final matchesText = query.isEmpty ||
          note.title.toLowerCase().contains(query) ||
          note.content.toLowerCase().contains(query);
      final matchesCategory =
          selectedCategory == 'Todas' || note.category == selectedCategory;
      return !note.isArchived && matchesText && matchesCategory;
    }).toList();

    DateTime created(Note note) =>
        note.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    DateTime updated(Note note) =>
        note.updatedAt ?? note.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);

    filtered.sort((a, b) {
      switch (sortOrder) {
        case NoteSortOrder.newest:
          return created(b).compareTo(created(a));
        case NoteSortOrder.oldest:
          return created(a).compareTo(created(b));
        case NoteSortOrder.recentlyUpdated:
          return updated(b).compareTo(updated(a));
        case NoteSortOrder.leastRecentlyUpdated:
          return updated(a).compareTo(updated(b));
      }
    });
    return filtered;
  }

  Future<void> deleteNote(int id) async {
    await database.deleteNote(id);
    await loadNotes();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nota deletada com sucesso!')),
      );
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
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final categories = <String>{'Todas', ...notes.map((note) => note.category)}
        .toList();
    final filteredNotes = visibleNotes;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Minhas notas',
            style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            tooltip: 'Sair',
            onPressed: logout,
            icon: const Icon(Icons.logout_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: openNewNote,
        backgroundColor: const Color(0xff6c4ab6),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nova Nota',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 90),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(user?.email ?? '',
                style: const TextStyle(
                    color: Color(0xFF77717f), fontSize: 13)),
            const SizedBox(height: 16),
            TextField(
              controller: searchController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Pesquisar notas...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: searchController.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Limpar pesquisa',
                        onPressed: () {
                          searchController.clear();
                          setState(() {});
                        },
                        icon: const Icon(Icons.close_rounded),
                      ),
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: categories.contains(selectedCategory)
                        ? selectedCategory
                        : 'Todas',
                    decoration: const InputDecoration(
                      labelText: 'Categoria',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: categories
                        .map((category) => DropdownMenuItem(
                              value: category,
                              child: Text(category,
                                  overflow: TextOverflow.ellipsis),
                            ))
                        .toList(),
                    onChanged: (category) {
                      if (category != null) {
                        setState(() => selectedCategory = category);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<NoteSortOrder>(
                    value: sortOrder,
                    decoration: const InputDecoration(
                      labelText: 'Ordenar',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: NoteSortOrder.values
                        .map((order) => DropdownMenuItem(
                              value: order,
                              child: Text(order.label,
                                  overflow: TextOverflow.ellipsis),
                            ))
                        .toList(),
                    onChanged: (order) {
                      if (order != null) setState(() => sortOrder = order);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: filteredNotes.isEmpty
                  ? Center(
                      child: Text(notes.isEmpty
                          ? 'Nenhuma nota ainda. Crie sua primeira nota.'
                          : 'Nenhuma nota corresponde aos filtros.'),
                    )
                  : ListView.builder(
                      itemCount: filteredNotes.length,
                      itemBuilder: (context, index) {
                        final note = filteredNotes[index];
                        return NoteCard(
                          note: note,
                          onTap: () => openEditNote(note),
                          onDelete: () => deleteNote(note.id!),
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
