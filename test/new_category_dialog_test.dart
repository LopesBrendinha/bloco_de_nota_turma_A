import 'package:bloco_de_nota_turma_a/pages/note_form_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('NewCategoryDialog devolve o nome e fecha sem erro', (
    tester,
  ) async {
    String? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await showDialog<String>(
                context: context,
                builder: (_) => const NewCategoryDialog(),
              );
            },
            child: const Text('abrir'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Viagem');
    await tester.tap(find.text('Criar'));
    await tester.pumpAndSettle();

    expect(result, 'Viagem');
    expect(find.byType(NewCategoryDialog), findsNothing);
  });
}
