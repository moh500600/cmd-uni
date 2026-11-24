import 'package:sqflite/sqflite.dart';

import 'schema.dart';

/// The device database. One table per synced entity (see [kTables]) plus
/// `sync_state` (the pull cursor of each table, per signed-in user).
class AppDatabase {
  static const version = 1;

  static Future<Database> open(DatabaseFactory factory, String path) => factory.openDatabase(
    path,
    options: OpenDatabaseOptions(
      version: version,
      onConfigure: (db) async => db.execute('PRAGMA foreign_keys = OFF'),
      onCreate: (db, v) async => create(db),
      onUpgrade: (db, from, to) async => create(db),
    ),
  );

  /// Creates every table and index (idempotent).
  static Future<void> create(DatabaseExecutor db) async {
    for (final t in kTables) {
      await db.execute(t.createSql());
      await db.execute('CREATE INDEX IF NOT EXISTS ix_${t.name}_user ON ${t.name}(user_id, deleted)');
      await db.execute('CREATE INDEX IF NOT EXISTS ix_${t.name}_dirty ON ${t.name}(dirty)');
    }
    await db.execute(
      'CREATE TABLE IF NOT EXISTS sync_state (user_id TEXT NOT NULL, tbl TEXT NOT NULL, cursor TEXT, '
      'PRIMARY KEY (user_id, tbl))',
    );
    await db.execute('CREATE TABLE IF NOT EXISTS sync_meta (user_id TEXT PRIMARY KEY, last_sync_at TEXT, last_error TEXT)');
  }
}
