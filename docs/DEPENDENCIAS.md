# Arquivos gerados para SQLite Web

`web/sqflite_sw.js` é o worker compilado de `sqflite_common_ffi_web` 1.2.0
(projeto Tekartik/sqflite, licença BSD-2-Clause). `web/sqlite3.wasm` vem da
release `sqlite3-3.8.0` de simolus3/sqlite3.dart; SQLite é de domínio público.
As bibliotecas Dart também estão discriminadas no registro de licenças do Flutter.

Fontes e licenças:

- https://github.com/tekartik/sqflite
- https://github.com/simolus3/sqlite3.dart
- https://sqlite.org/copyright.html

Os binários são versionados para permitir executar a Web após `flutter pub get`.
Se atualizar os pacotes relacionados ao SQLite, gere novamente usando:

```sh
dart run tool/build_sqlite_web.dart
```

Esse script compila o worker com as dependências efetivamente resolvidas e baixa
o WebAssembly correspondente à versão de `sqlite3` instalada. A ferramenta
oficial `dart run sqflite_common_ffi_web:setup` também pode ser utilizada; confira
a compatibilidade da versão do WebAssembly gerada.
