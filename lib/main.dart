import 'package:bloco_de_nota_turma_a/firebase_options.dart';
import 'package:bloco_de_nota_turma_a/pages/login_page.dart';
import 'package:bloco_de_nota_turma_a/pages/notes_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

void main() async{
  WidgetsFlutterBinding.ensureInitialized();

  // no navegador o sqflite precisa usar a versão web (sqlite3.wasm)
  if (kIsWeb) {
    databaseFactory = databaseFactoryFfiWeb;
  }

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Quem guarda as notas offline é o SQLite,
  // então o cache do próprio Firestore fica desligado.
  FirebaseFirestore.instance.settings = Settings(persistenceEnabled: false);

  // se o usuário já entrou antes vai direto para as notas (funciona sem internet)
  final user = await FirebaseAuth.instance.authStateChanges().first;

  runApp(MyApp(logged: user != null));
}

class MyApp extends StatelessWidget {
  final bool logged;

  const MyApp({super.key, required this.logged});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Bloco de Notas',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: Color(0xFFF7F5FC),
        colorScheme: ColorScheme.fromSeed(
          seedColor: Color(0xFF6c4ab6), 
          brightness: Brightness.light
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: Color(0xfff7f5fc),
          foregroundColor: Color(0xff292333),
           elevation: 0,
           centerTitle: false,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding: EdgeInsets.symmetric(horizontal:20, vertical: 17),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide(
              color: Color(0XFF6C4AB6),
              width: 2,
            ),
          ),
        ),

        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Color(0xFF6c4ab6),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
        ),
      ),
      home: logged ? NotesPage() : LoginPage(),
    );
  }
}

