import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/note.dart';
import '../services/notes_service.dart';
import '../services/auth_service.dart';
import 'login_page.dart';
import 'note_form_page.dart';

class NotesPage extends StatefulWidget {
  const NotesPage({super.key});
  @override
  State<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends State<NotesPage> {
  final service = NotesService();
  List<Note> notes = [];
  String search = '';
  String category = 'Todas';
  bool loading = true;
  String? error;

  @override
  void initState() { super.initState(); loadNotes(); }

  Future<void> loadNotes() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    setState(() { loading = true; error = null; });
    try {
      final result = await service.load(user.uid);
      if (mounted) setState(() { notes = result; loading = false; });
    } catch (_) {
      if (mounted) setState(() { loading = false; error = 'Não foi possível atualizar as notas.'; });
    }
  }

  List<Note> get visibleNotes => notes.where((n) {
    final term = search.toLowerCase();
    final matches = n.title.toLowerCase().contains(term) ||
        n.content.toLowerCase().contains(term);
    return matches && (category == 'Todas' || n.category == category);
  }).toList();

  Future<void> openForm([Note? note]) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => NoteFormPage(note: note)));
    await loadNotes();
  }

  Future<void> remove(Note note) async {
    try {
      await service.delete(note);
      await loadNotes();
    } catch (_) { message('Não foi possível excluir. Confira sua conexão.'); }
  }

  Future<void> logout() async {
    await AuthService().logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(context,
      MaterialPageRoute(builder: (_) => const LoginPage()), (_) => false);
  }

  void message(String value) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(value)));

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final categories = ['Todas', ...{for (final n in notes) n.category}];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Caderno de Bolso', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(onPressed: loadNotes, icon: const Icon(Icons.sync), tooltip: 'Atualizar'),
          IconButton(onPressed: logout, icon: const Icon(Icons.logout), tooltip: 'Sair'),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => openForm(), icon: const Icon(Icons.add),
        label: const Text('Nova anotação'),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 90),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(user?.email ?? '', style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 14),
          TextField(
            onChanged: (v) => setState(() => search = v),
            decoration: const InputDecoration(
              hintText: 'Buscar por título ou texto',
              prefixIcon: Icon(Icons.search),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(height: 42, child: ListView(
            scrollDirection: Axis.horizontal,
            children: categories.map((c) => Padding(
              padding: const EdgeInsets.only(right: 7),
              child: ChoiceChip(label: Text(c), selected: category == c,
                onSelected: (_) => setState(() => category = c)),
            )).toList(),
          )),
          if (error != null) Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(error!, style: const TextStyle(color: Colors.red)),
          ),
          Expanded(child: loading
            ? const Center(child: CircularProgressIndicator())
            : visibleNotes.isEmpty
              ? const Center(child: Text('Nenhuma anotação encontrada.'))
              : ListView.builder(
                itemCount: visibleNotes.length,
                itemBuilder: (_, i) {
                  final n = visibleNotes[i];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      onTap: () => openForm(n),
                      leading: Icon(n.pinned ? Icons.push_pin : Icons.sticky_note_2_outlined),
                      title: Text(n.title.isEmpty ? 'Sem título' : n.title,
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text('${n.category} • ${n.date}\n${n.content}',
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                      isThreeLine: true,
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => remove(n),
                      ),
                    ),
                  );
                },
              )),
        ]),
      ),
    );
  }
}
