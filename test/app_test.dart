import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bloco_de_nota_turma_a/main.dart';
import 'package:bloco_de_nota_turma_a/models/note.dart';
import 'package:bloco_de_nota_turma_a/widgets/note_card.dart';

void main() {
  testWidgets('missing configuration gives actionable startup instructions', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MyApp(
        startupError: 'Configure seu próprio Firebase seguindo o README.',
      ),
    );
    expect(
      find.textContaining('Configure seu próprio Firebase'),
      findsOneWidget,
    );
  });
  testWidgets(
    'note card exposes category, pending upload, archive and deletion',
    (tester) async {
      var archived = false, deleted = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NoteCard(
              note: Note(
                uid: 'alice',
                title: 'Estudar',
                content: 'Para a prova',
                category: 'Estudos',
              ),
              onTap: () {},
              onArchive: () => archived = true,
              onDelete: () => deleted = true,
            ),
          ),
        ),
      );
      expect(find.text('Estudos'), findsOneWidget);
      expect(find.text('Envio pendente'), findsOneWidget);
      await tester.tap(find.byTooltip('Arquivar'));
      expect(archived, true);
      await tester.tap(find.byTooltip('Excluir nota'));
      expect(deleted, true);
    },
  );
}
