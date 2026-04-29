import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

class AppDatabase {
  static const _dbName = 'sami_transcribe.db';
  static const _dbVersion = 1;

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, _dbName);

    return openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE recordings (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL DEFAULT 'Sin titulo',
        audio_path TEXT NOT NULL,
        duration_seconds INTEGER NOT NULL DEFAULT 0,
        source TEXT NOT NULL DEFAULT 'app',
        status TEXT NOT NULL DEFAULT 'idle',
        created_at TEXT NOT NULL,
        updated_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE transcriptions (
        id TEXT PRIMARY KEY,
        recording_id TEXT NOT NULL,
        full_text TEXT NOT NULL DEFAULT '',
        language TEXT NOT NULL DEFAULT 'es',
        model_used TEXT NOT NULL DEFAULT '',
        created_at TEXT NOT NULL,
        FOREIGN KEY (recording_id) REFERENCES recordings(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE segments (
        id TEXT PRIMARY KEY,
        transcription_id TEXT NOT NULL,
        speaker_label TEXT NOT NULL DEFAULT 'Hablante 1',
        speaker_name TEXT,
        start_time REAL NOT NULL DEFAULT 0,
        end_time REAL NOT NULL DEFAULT 0,
        text TEXT NOT NULL DEFAULT '',
        FOREIGN KEY (transcription_id) REFERENCES transcriptions(id) ON DELETE CASCADE
      )
    ''');
  }

  Future<void> close() async {
    final db = _db;
    if (db != null) {
      await db.close();
      _db = null;
    }
  }
}
