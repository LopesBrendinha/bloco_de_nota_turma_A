# Bloco de Notas - Turma A

App de bloco de notas em Flutter, feito a partir do projeto da professora. As notas ficam salvas no celular (SQLite) e também no Firebase (Cloud Firestore), então dá para usar sem internet e recuperar as notas depois.

## Funcionalidades

- Cadastro, login e logout com Firebase Authentication
- Criar, editar e excluir notas
- Notas salvas no SQLite e no Firestore, separadas por usuário
- Sincronização entre o SQLite e o Firestore
- Funciona sem internet (envia depois, quando a conexão voltar)
- Categorias (Estudos, Trabalho, Pessoal e outras que o usuário criar)
- Pesquisa pelo título ou pelo conteúdo
- Lixeira com opção de restaurar (funcionalidade adicional)
- Ordenação por data de criação ou de atualização (funcionalidade adicional)

## Tecnologias

- Flutter 3.47 / Dart 3.13
- firebase_core e firebase_auth (login)
- cloud_firestore (banco na nuvem)
- sqflite (banco local)
- sqflite_common_ffi_web (para o SQLite funcionar no navegador)
- path

## Como rodar

1. Clonar o repositório e entrar na branch `desenvolvimento`
2. Rodar `flutter pub get`
3. Configurar o Firebase (próxima seção)
4. Rodar `flutter run` (celular ou emulador) ou `flutter run -d chrome --web-port 5000` (navegador)

## Configurar o Firebase

O `firebase_options.dart` e o `google-services.json` não estão no repositório porque cada um usa o seu próprio projeto do Firebase. Para gerar:

1. Criar um projeto no console do Firebase
2. Em Authentication, ativar o login por E-mail/senha
3. Criar o Firestore Database (modo de produção)
4. Instalar as ferramentas e fazer login:
   ```
   npm install -g firebase-tools
   dart pub global activate flutterfire_cli
   firebase login
   ```
5. Na pasta do projeto, rodar `flutterfire configure`
6. Publicar as regras do arquivo `firestore.rules` (pelo console, na aba Regras, ou com `firebase deploy --only firestore:rules`)

## Organização dos arquivos

- `lib/main.dart`: inicia o Firebase e abre a tela de login ou as notas
- `lib/models/note.dart`: classe Note
- `lib/database/database_helper.dart`: banco SQLite
- `lib/services/auth_service.dart`: login e cadastro
- `lib/services/firestore_service.dart`: salvar, buscar e apagar notas no Firestore
- `lib/repositories/note_repository.dart`: junta o SQLite e o Firestore e faz a sincronização
- `lib/pages/`: telas (login, cadastro, notas, nova nota e lixeira)
- `lib/widgets/note_card.dart`: card de cada nota
- `firestore.rules`: regras de segurança do Firestore

As telas não falam direto com o banco. Elas chamam o `NoteRepository`, que salva no SQLite e depois manda para o Firestore.

## Padrões usados

- Singleton: o `DatabaseHelper` tem uma única instância (`DatabaseHelper.instance`), assim o banco é aberto uma vez só.
- Repository: o `NoteRepository` concentra o acesso aos dados. As telas não precisam saber se a nota está no SQLite ou no Firestore.
- Service: o `AuthService` e o `FirestoreService` separam o código do Firebase do resto do app.
- Factory: `Note.fromMap` e `Note.fromFirestore` criam a nota a partir dos dados de cada banco.

## Banco local e Firebase

No SQLite, a tabela `notes` guarda título, conteúdo, categoria, datas e alguns campos de controle:

- `firebaseId`: id da nota no Firestore
- `synced`: 1 se já foi enviada para o Firebase, 0 se está pendente
- `trashed`: 1 se está na lixeira
- `deleted`: 1 se foi excluída e falta apagar no Firebase

Também tem a tabela `categories`. O projeto da professora tinha uma vírgula sobrando no `CREATE TABLE`, que foi corrigida. O banco está na versão 3 e o `onUpgrade` adiciona as colunas novas sem perder as notas antigas.

No Firestore, cada usuário tem as suas notas em `users/{uid}/notes`.

## Sincronização e erros

Toda alteração é salva primeiro no SQLite com `synced = 0`. Depois o `syncNotes` faz três coisas:

1. Baixa as notas do Firestore e atualiza o SQLite. Se a mesma nota mudou nos dois lugares, fica a mais recente (`updatedAt`).
2. Apaga do SQLite as notas que foram excluídas em outro aparelho.
3. Envia para o Firestore o que ainda está pendente.

A sincronização roda quando o app abre, depois de cada alteração e no botão de sincronizar.

Se não tiver internet ou o Firebase não responder em 10 segundos, o erro é tratado com `try/catch`: as notas continuam salvas no SQLite, aparece um aviso na tela e elas são enviadas na próxima sincronização. Cada nota mostra um ícone de nuvem dizendo se já foi enviada.

Ao entrar de novo ou em outra instalação, as notas são baixadas do Firestore.

## Autenticação e segurança

O login é feito pelo Firebase Authentication e cada nota guarda o `uid` do usuário. As regras do Firestore só deixam o próprio usuário ler e alterar as notas dele. Trecho do `firestore.rules`:

```
match /users/{userId}/notes/{noteId} {
  allow read, delete: if request.auth != null && request.auth.uid == userId;
  allow create, update: if request.auth != null && request.auth.uid == userId
                        && request.resource.data.uid == userId;
}
```

Nenhuma senha ou arquivo de configuração do Firebase foi colocado no repositório.

## Testes

- `flutter test` roda os testes da classe Note
- Testei no app: cadastro, login, notas, categorias, pesquisa, lixeira, ordenação, uso sem internet e recuperação das notas depois de apagar o banco local

## Prints do app

<img src="screenshots/01_login.jpg" width="200"> <img src="screenshots/02_lista_notas.jpg" width="200"> <img src="screenshots/03_nota_com_categoria.jpg" width="200"> <img src="screenshots/04_nova_categoria.jpg" width="200">

<img src="screenshots/05_pesquisa.jpg" width="200"> <img src="screenshots/06_ordenacao_e_filtro.jpg" width="200"> <img src="screenshots/07_lixeira.jpg" width="200"> <img src="screenshots/08_sem_conexao.jpg" width="200">

Login, lista de notas, nota com categoria, nova categoria, pesquisa, filtro e ordenação, lixeira e o aviso de sem conexão (a nota fica pendente até a internet voltar).

## Prints do Firebase

Notas salvas no Firestore:

![Firestore](screenshots/09_firebase_firestore.jpg)

Usuário no Authentication:

![Authentication](screenshots/10_firebase_authentication.jpg)

Regras publicadas:

![Regras](screenshots/11_firebase_regras.jpg)

Teste das regras no console: outro usuário não consegue ler a nota, e o dono consegue.

![Leitura negada](screenshots/12_regras_outro_usuario_negado.jpg)

![Leitura permitida](screenshots/13_regras_dono_permitido.jpg)
