import 'package:sqflite/sqflite.dart';

// Fora do navegador o pacote web nem é compilado; o main só usa isto na web.
DatabaseFactory get webDatabaseFactory =>
    throw UnsupportedError('Só existe na web');
