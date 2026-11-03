# Bloco de Notas

Aplicativo Flutter para criar, editar, buscar e excluir notas. A autenticação é
feita pelo Firebase Authentication. As notas e categorias são armazenadas no
SQLite local e sincronizadas com o Cloud Firestore por usuário.

## Configuração do Firebase

1. Configure o Firebase Authentication com o provedor de e-mail e senha.
2. Crie o banco Cloud Firestore no projeto `blocodenotasturmaa`.
3. Publique as regras de `firestore.rules`:

   ```powershell
   firebase deploy --only firestore:rules
   ```

## Executar no Chrome

Requisitos: Flutter/Dart conforme `pubspec.yaml` e Google Chrome.

```powershell
flutter pub get
flutter run -d chrome
```

O SQLite no navegador usa WebAssembly e IndexedDB. Os arquivos necessários,
`web/sqlite3.wasm` e `web/sqflite_sw.js`, já estão no repositório. Para
regenerá-los após atualizar a dependência, execute:

```powershell
dart run sqflite_common_ffi_web:setup
```

## Executar no Android

Requer Android Studio, Android SDK, um dispositivo ou emulador Android e JDK
17 ou superior. Depois de configurar o SDK:

```powershell
flutter pub get
flutter run -d <id-do-dispositivo>
```

O arquivo Android de configuração Firebase está em
`android/app/google-services.json`. O banco SQLite é migrado automaticamente.
Sem conexão com o Firestore, o aplicativo mantém as notas no dispositivo e
mostra o estado da sincronização; uma nova tentativa pode ser feita pelo botão
de sincronizar.

## Testes

Execute os testes locais com:

```powershell
flutter test
```

Eles cobrem a persistência SQLite, envio e recuperação de notas, atualizações,
exclusões, categorias, busca e ordenação. Para testar também as regras do
Firestore Emulator, instale Node.js, Firebase CLI e JDK 21 ou superior e rode:

```powershell
firebase emulators:exec --project demo-blocodenotasturmaa --only auth,firestore "node test/firestore_emulator_test.cjs"
```

O teste do emulador valida criação, leitura, edição, exclusão e isolamento entre
usuários. Para obter uma captura de evidência no projeto real, crie uma nota e
abra **Firestore Database → users → UID da conta → notes** no Firebase Console.

## Funcionalidades

- Categorias por usuário, armazenadas localmente e em
  `users/{uid}/categories`; cada nota contém sua categoria em `category`.
- Busca pelo título ou conteúdo e filtro por categoria.
- Ordenação pela última atualização, em ordem crescente ou decrescente.
- Sincronização local/nuvem e recuperação de notas em outra instalação.

## Estrutura

- `lib/models`: modelo das notas.
- `lib/database`: persistência SQLite e migrações.
- `lib/services`: autenticação, sincronização, busca e ordenação.
- `lib/pages`: login, cadastro, listagem e edição.
- `test`: testes unitários e de integração.
