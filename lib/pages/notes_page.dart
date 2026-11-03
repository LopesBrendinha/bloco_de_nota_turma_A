import 'package:bloco_de_nota_turma_a/models/note.dart';
import 'package:bloco_de_nota_turma_a/pages/note_form_page.dart';
import 'package:bloco_de_nota_turma_a/pages/trash_page.dart';
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
  @override
  void initState() {
    super.initState();
    loadNotes();
  }

  Future<void> loadNotes() async {
    final result = await repository.getNotes();

    if (mounted) {
      setState(() {
        notes = result;
      });
    }
  }

  Future<void> deleteNote(Note note) async {
    await repository.delete(note);
    await loadNotes();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Nota movida para a lixeira"),
        // Com action, a SnackBar fica na tela para sempre se persist não for false.
        persist: false,
        action: SnackBarAction(
          label: "Desfazer",
          onPressed: () async {
            await repository.restore(note);
            await loadNotes();
          },
        ),
      ),
    );
  }

  Future<void> openTrash() async {
    // Sem isso, o "Desfazer" iria junto para a lixeira e poderia ressuscitar
    // uma nota que o usuário acabou de excluir de vez.
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => TrashPage()),
    );
    await loadNotes();
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
    return Scaffold(
      appBar: AppBar(
        title: Text("Minhas notas", style: TextStyle(fontWeight:FontWeight.bold )),
        actions:[
          IconButton(
            tooltip: "Lixeira",
            onPressed: openTrash,
            icon: Icon(Icons.delete_outline_rounded),
          ),
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
            SizedBox(height: 20),
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
            else
                Expanded(
                  child: ListView.builder(
                    itemCount: notes.length,
                    itemBuilder: (context, index){
                      final note = notes[index];

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
