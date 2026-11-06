import 'package:sembast_web/sembast_web.dart';

/// Opens the database in the browser's IndexedDB.
Future<Database> openAppDatabase(String name) =>
    databaseFactoryWeb.openDatabase(name);
