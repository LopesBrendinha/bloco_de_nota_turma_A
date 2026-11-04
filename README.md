# Bloco de Notas

Aplicativo multiplataforma em Flutter para manter notas pessoais organizadas por categoria, com persistência local em SQLite e sincronização com Cloud Firestore por conta autenticada.

## Funcionalidades

- Cadastro e login com Firebase Authentication (e-mail e senha).
- Criar, visualizar, editar e excluir notas.
- Categoria por nota; categorias sincronizadas entre instalações da mesma conta.
- Busca local pelo título e pelo conteúdo, com filtro por categoria.
- Ordenação pela data de atualização, mais recentes ou mais antigas primeiro.
- Persistência local para consultar notas mesmo quando a sincronização com a nuvem falha.
- Sincronização manual pela ação de atualizar na tela de notas e tentativa ao abrir a lista.
- Isolamento de dados por usuário nas regras do Firestore.

## Tecnologias e dependências

- Flutter e Dart (versão do SDK conforme `pubspec.yaml`).
- Firebase Core, Firebase Authentication e Cloud Firestore.
- SQLite com `sqflite`; no navegador, `sqflite_common_ffi_web` usa SQLite WebAssembly e IndexedDB.
- Testes: `flutter_test`, `fake_cloud_firestore` e `sqflite_common_ffi`.
- Teste das regras: Node.js, Firebase CLI, Firebase Emulator Suite e Java 21 ou superior.

## Arquitetura e organização

A interface Flutter fica em `lib/pages` e `lib/widgets`. As páginas de login e cadastro usam `AuthService`; a tela `NotesPage` carrega os dados, mostra o estado de sincronização e aplica busca, filtro e ordenação. O formulário cria e altera notas.

A camada de dados é organizada em torno de `NoteRepository` (`lib/services/note_repository.dart`), que coordena SQLite e Firestore, e `DatabaseHelper` (`lib/database/database_helper.dart`), responsável pelo acesso SQLite e migrações. `Note` (`lib/models/note.dart`) representa a nota em ambas as camadas. Os serviços `note_search.dart` e `note_sorting.dart` mantêm as operações de pesquisa e ordenação separadas da interface.

Padrões adotados no código:

- **Repository:** `NoteRepository` concentra as operações de notas/categorias e a coordenação entre os dois armazenamentos, evitando chamadas diretas do Firestore pelas páginas.
- **Singleton:** `DatabaseHelper.instance` mantém uma instância compartilhada do acesso e da conexão SQLite.
- **Modelo de domínio/entidade:** `Note` converte os campos entre o modelo Dart, as linhas SQLite e os documentos Firestore.
- **Local-first:** alterações são gravadas primeiro no SQLite; a tentativa de nuvem acontece depois, preservando o uso local quando a rede falha.

O projeto usa essa separação pragmática; não declara uma implementação completa de Clean Architecture ou MVC.

## Armazenamento e sincronização

Cada nota contém `id` local, `uid` do Firebase Auth, título, conteúdo, categoria, data, identificador Firestore (`cloudId`) e `updatedAt`. O SQLite mantém as tabelas `notes`, `note_categories` e `pending_deletions`. O banco é criado ou migrado automaticamente até a versão 4. No Firestore, os documentos ficam em `users/{uid}/notes/{noteId}` e `users/{uid}/categories/{categoryId}`.

Ao salvar, o repositório grava no SQLite e tenta enviar o documento com um ID estável para a nuvem. Ao sincronizar, primeiro tenta concluir exclusões pendentes; depois combina categorias, busca documentos remotos e compara `updatedAt`: uma versão remota mais recente atualiza o SQLite, enquanto uma versão local mais recente é enviada à nuvem. Notas remotas ausentes localmente são baixadas. Uma exclusão sem conexão é registrada em `pending_deletions` e tentada novamente na próxima sincronização. Categorias são combinadas entre os lados; não há exclusão/sincronização de remoção de categoria.

Busca e filtro operam sobre as notas carregadas no SQLite, incluindo as baixadas na sincronização. Por isso, notas da nuvem de outra instalação só aparecem depois que a sincronização é concluída. Se a sincronização falhar, a interface informa a falha e mantém disponíveis as notas locais; use o botão de sincronizar para tentar novamente. As escritas de nota e categoria tentam a nuvem imediatamente e podem ser reenviadas na sincronização seguinte. A resolução de conflito usa o maior `updatedAt` em milissegundos; não há histórico ou mesclagem campo a campo.

## Configuração do Firebase e segurança

1. Crie ou selecione um projeto Firebase e registre os aplicativos das plataformas que pretende executar.
2. Ative **Authentication → Sign-in method → E-mail/Senha**.
3. Crie o banco **Cloud Firestore** em modo de produção.
4. A configuração cliente do repositório está registrada para o projeto `blocodenotasturmaa-b4c4a` (Android, iOS e Web). Para configurá-la novamente, instale FlutterFire CLI (`dart pub global activate flutterfire_cli`) e execute `flutterfire configure --project=blocodenotasturmaa-b4c4a --platforms=android,ios,web`.
5. Publique as regras deste repositório: `firebase deploy --only firestore:rules --project blocodenotasturmaa-b4c4a`.
6. Execute o app, cadastre uma conta e entre. As notas são gravadas no caminho associado ao UID autenticado.

As regras em `firestore.rules` exigem autenticação e correspondência entre `request.auth.uid`, o UID do caminho e o campo `uid` do documento; também verificam os tipos dos campos. Nunca publique credenciais administrativas, chaves privadas ou arquivos de service account. `lib/firebase_options.dart` e `android/app/google-services.json` são configurações de cliente usadas pelos SDKs mobile/web, não credenciais administrativas; restrinja as chaves de API no Google Cloud às APIs e aplicativos necessários. As regras do Firestore, e não o segredo da configuração do cliente, protegem os documentos.

## Instalação e execução

Requisitos: Flutter SDK compatível com `pubspec.yaml`; para web, Google Chrome. No PowerShell, na raiz do projeto:

```powershell
flutter pub get
flutter run -d chrome
```

Os recursos necessários ao SQLite no navegador (`web/sqlite3.wasm` e `web/sqflite_sw.js`) estão versionados. Se atualizar a dependência que os fornece, regenere-os com:

```powershell
dart run sqflite_common_ffi_web:setup
```

Para Android, instale Android Studio, Android SDK, configure um emulador/dispositivo e JDK 17 ou superior; em seguida:

```powershell
flutter pub get
flutter devices
flutter run -d <id-do-dispositivo>
```

## Testes e verificações

```powershell
flutter test
dart analyze lib test
```

Os testes cobrem conversão do modelo, busca, ordenação e operações de sincronização com SQLite e Firestore falso. Para validar as regras reais no emulador (sem usar o projeto Firebase de produção):

```powershell
firebase emulators:exec --project demo-blocodenotasturmaa --only auth,firestore "node test/firestore_emulator_test.cjs"
```

O teste de emulador verifica operações permitidas do proprietário e nega leitura/alteração entre usuários. Requer Node.js, Firebase CLI e Java 21 ou superior.

## Capturas de tela e evidências

Para registrar evidência visual do aplicativo, execute-o, entre com uma conta de teste e capture a tela de lista com uma nota e sua categoria; uma segunda captura pode mostrar busca e ordenação. Não inclua e-mail real, senha ou dados pessoais nas imagens.

Para comprovar a gravação no Firebase, no Console abra **Firestore Database → users → UID da conta de teste → notes** e capture um documento com `title`, `content`, `category`, `date`, `uid` e `updatedAt`. O UID exibido no caminho deve ser o da conta autenticada. Também é possível conferir `users/{uid}/categories`. Não foi incluída neste repositório uma captura do Console Firebase: ela precisa ser obtida no projeto ao qual o avaliador tenha acesso; testes com `FakeFirebaseFirestore` ou com emulador não comprovam gravação no projeto de produção.

## Principais arquivos

- `lib/main.dart`: inicialização do Firebase e rotas/entrada do app.
- `lib/models/note.dart`: modelo e conversões da nota.
- `lib/database/database_helper.dart`: SQLite, tabelas e migrações.
- `lib/services/auth_service.dart`: autenticação.
- `lib/services/note_repository.dart`: operações e sincronização local/nuvem.
- `lib/services/note_search.dart`, `note_sorting.dart`: busca e ordenação.
- `lib/pages/`: login, cadastro, listagem e formulário de notas.
- `lib/widgets/note_card.dart`: apresentação resumida de uma nota.
- `firestore.rules`: isolamento e validação dos documentos por usuário.
- `firebase.json`: caminhos das regras e configuração dos emuladores.
- `test/`: testes unitários, do repositório e das regras no emulador.
- `web/sqlite3.wasm`, `web/sqflite_sw.js`: suporte do SQLite no navegador.
