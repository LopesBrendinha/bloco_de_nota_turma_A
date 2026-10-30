import 'package:bloco_de_nota_turma_a/database/database_helper.dart';
import 'package:bloco_de_nota_turma_a/models/note.dart';
import 'package:bloco_de_nota_turma_a/pages/login_page.dart';
import 'package:bloco_de_nota_turma_a/pages/note_form_page.dart';
import 'package:bloco_de_nota_turma_a/services/auth_service.dart';
import 'package:bloco_de_nota_turma_a/widgets/note_card.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

class NotesPage extends StatefulWidget {
  const NotesPage({super.key});

  @override
  State<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends State<NotesPage> {
  final DatabaseHelper database = DatabaseHelper.instance;
  final AuthService authService = AuthService();

  List<Note> notes = [];
  final searchController = TextEditingController();
  String searchQuery = '';
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
    final query = searchQuery.trim().toLowerCase();
    final filteredNotes = notes
        .where(
          (note) =>
              note.title.toLowerCase().contains(query) ||
              note.content.toLowerCase().contains(query) ||
              note.category.toLowerCase().contains(query),
        )
        .toList();
    if (user == null) return;
    final result = await database.getNotes(user.uid);

    if (mounted) {
      setState(() {
        notes = result;
      });
    }
  }

  Future<void> deleteNote(int id) async {
    await database.deleteNote(id);
    await loadNotes();
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Nota deletada com sucesso!")));
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
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Minhas notas",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
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
            SizedBox(height: 20),
            TextField(
              controller: searchController,
              onChanged: (value) => setState(() => searchQuery = value),
              decoration: InputDecoration(
                hintText: 'Pesquisar título, conteúdo ou categoria',
                prefixIcon: Icon(Icons.search_rounded),
                suffixIcon: searchQuery.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Limpar pesquisa',
                        onPressed: () {
                          searchController.clear();
                          setState(() => searchQuery = '');
                        },
                        icon: Icon(Icons.close_rounded),
                      ),
              ),
            ),
            SizedBox(height: 16),
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
                        notes.isEmpty
                            ? "Nenhuma nota ainda"
                            : "Nenhum resultado",
                      ),
                      SizedBox(height: 8),
                      Text('Crie sua primeira nota.'),
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
