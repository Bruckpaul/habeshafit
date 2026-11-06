import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sembast/sembast_io.dart';

/// Opens the database file in the app's documents folder (Android, iOS, desktop).
Future<Database> openAppDatabase(String name) async {
  final dir = await getApplicationDocumentsDirectory();
  await dir.create(recursive: true);
  return databaseFactoryIo.openDatabase(p.join(dir.path, name));
}
