import 'package:bloco_de_nota_turma_a/models/note.dart';
import 'package:bloco_de_nota_turma_a/pages/note_form_page.dart';
import 'package:bloco_de_nota_turma_a/repositories/note_filter.dart';
import 'package:bloco_de_nota_turma_a/repositories/note_repository.dart';
import 'package:bloco_de_nota_turma_a/services/auth_service.dart';
import 'package:bloco_de_nota_turma_a/widgets/note_card.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class NotesPage extends StatefulWidget {
  const NotesPage({super.key});

  @override
  State<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends State<NotesPage> {
  final NoteRepository repository = NoteRepository();
  final AuthService authService = AuthService();

  List<Note> notes = [];
  final searchController = TextEditingController();
  List<String> categories = [];
  String query = '';
  String? selectedCategory;
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
    final result = await repository.getNotes();
    final resultCategories = await repository.getCategories();

    if (mounted) {
      setState(() {
        notes = result;
        categories = resultCategories;
        if (!categories.contains(selectedCategory)) {
          selectedCategory = null;
        }
      });
    }
  }

  Future<void> deleteNote(Note note) async {
    await repository.delete(note);
    await loadNotes();
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Nota deletada com sucesso!")));
    }
  }

  Future<void> logout() async {
    await authService.logout();
  }

  Future<void> openEditNote(Note note) async{
    await Navigator.push(context, 
    MaterialPageRoute(builder:(_)=> NoteFormPage(note: note)));

    await loadNotes();
  }
  Future<void> openNewNote() async{
    await Navigator.push(context, 
    MaterialPageRoute(builder:(_)=> NoteFormPage()));

    await loadNotes();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final visible = filterNotes(
      notes,
      query: query,
      category: selectedCategory,
    );
    return Scaffold(
      appBar: AppBar(
        title: Text("Minhas notas", style: TextStyle(fontWeight:FontWeight.bold )),
        actions:[
          IconButton(
            tooltip: "Sair",
            onPressed: logout,
            icon: Icon(Icons.logout_rounded)
          ),
          SizedBox(width: 8)
        ] 
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: openNewNote,
        backgroundColor: Color(0xff6c4ab6),
        foregroundColor: Colors.white,
        icon: Icon(Icons.add_rounded),
        label: Text("Nova Nota", style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Padding(
        padding: EdgeInsets.fromLTRB(20,10,20,90),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children:[
            Text(user?.email ?? "", style: TextStyle(color: Color(0xFF77717f), fontSize:13)),
            SizedBox(height: 12),
            TextField(
              controller: searchController,
              onChanged: (value) => setState(() => query = value),
              decoration: InputDecoration(
                hintText: "Pesquisar no título ou no conteúdo",
                prefixIcon: Icon(Icons.search_rounded),
                suffixIcon: query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: "Limpar pesquisa",
                        icon: Icon(Icons.close_rounded),
                        onPressed: () {
                          searchController.clear();
                          setState(() => query = '');
                        },
                      ),
              ),
            ),
            SizedBox(height: 12),
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final category in [null, ...categories])
                    Padding(
                      padding: EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(category ?? "Todas"),
                        selected: selectedCategory == category,
                        onSelected: (_) => setState(() => selectedCategory = category),
                      ),
                    ),
                ],
              ),
            ),
            SizedBox(height: 12),
            if(notes.isEmpty)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children:[
                      Container(
                        width: 100,
                        height:100,

                        decoration: BoxDecoration(
                          color: Color(0xffede5fa),
                          shape: BoxShape.circle
                        ),
                        child: Icon(
                          Icons.sticky_note_2_rounded,
                          color: Color(0xff6c4ab6)
                        )
                      ),
                      SizedBox(height: 25),
                      Text("Nenhuma nota ainda"),
                      SizedBox(height: 8),
                      Text('Crie sua primeira nota.')
                    ]
                  )
                )
              )
            else if (visible.isEmpty)
              Expanded(
                child: Center(
                  child: Text(
                    query.trim().isEmpty
                        ? "Nenhuma nota nesta categoria"
                        : "Nenhuma nota encontrada para \"${query.trim()}\"",
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            else
                Expanded(
                  child: ListView.builder(
                    itemCount: visible.length,
                    itemBuilder: (context, index){
                      final note = visible[index];

                      return NoteCard(
                        note: note,
                        onTap: () => openEditNote(note),
                        onDelete: () => deleteNote(note),
                      );
                    }
                  )
                )

          ],
        ),
      ),
    );
  }
}
