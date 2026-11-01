import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

/// Resolves the database connection for Drift.
///
/// Uses [NativeDatabase.memory] when [inMemory] is true (ideal for fast, isolated unit tests).
/// Otherwise, stores SQLite database on persistent disk in the application documents directory.
QueryExecutor openConnection({bool inMemory = false, File? customFile}) {
  if (inMemory) {
    return NativeDatabase.memory();
  }

  if (customFile != null) {
    return NativeDatabase.createInBackground(customFile);
  }

  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'campus_os.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
