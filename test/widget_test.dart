
import 'package:flutter_test/flutter_test.dart';
import 'package:bloco_de_nota_turma_a/models/note.dart';

void main() {
  test('Deve converter uma nota para o banco de dados', () {
    final nota = Note(
      cloudId: '',
      uid: 'usuario123',
      title: 'Minha anotação',
      content: 'Estudar Flutter',
      category: 'Estudos',
      date: '02/11/2026',
      pinned: true,
    );

    final dados = nota.toMap();

    expect(dados['title'], 'Minha anotação');
    expect(dados['category'], 'Estudos');
    expect(dados['pinned'], 1);
  });
}
