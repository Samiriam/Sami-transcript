import '../domain/recording.dart';
import 'recording_repository.dart';
import '../../../core/database/app_database.dart' as db;

class SqliteRecordingRepository implements RecordingRepository {
  SqliteRecordingRepository(this._appDb);

  final db.AppDatabase _appDb;

  @override
  Future<List<Recording>> list() async {
    final database = await _appDb.database;
    final rows = await database.query(
      'recordings',
      orderBy: 'created_at DESC',
    );
    return rows.map(_fromRow).toList();
  }

  @override
  Stream<List<Recording>> watchAll() async* {
    while (true) {
      yield await list();
      await Future.delayed(const Duration(milliseconds: 500));
    }
  }

  @override
  Future<Recording> getById(String id) async {
    final database = await _appDb.database;
    final rows = await database.query(
      'recordings',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (rows.isEmpty) throw Exception('Recording not found: $id');
    return _fromRow(rows.first);
  }

  @override
  Future<void> save(Recording recording) async {
    final database = await _appDb.database;
    await database.insert('recordings', _toRow(recording));
  }

  @override
  Future<void> update(Recording recording) async {
    final database = await _appDb.database;
    await database.update(
      'recordings',
      _toRow(recording),
      where: 'id = ?',
      whereArgs: [recording.id],
    );
  }

  @override
  Future<void> delete(String id) async {
    final database = await _appDb.database;
    await database.delete('recordings', where: 'id = ?', whereArgs: [id]);
  }

  Recording _fromRow(Map<String, dynamic> row) {
    return Recording(
      id: row['id'] as String,
      title: row['title'] as String,
      audioPath: row['audio_path'] as String,
      durationSeconds: row['duration_seconds'] as int,
      source: row['source'] == 'import' ? RecordingSource.import : RecordingSource.app,
      status: _parseStatus(row['status'] as String),
      createdAt: DateTime.parse(row['created_at'] as String),
      updatedAt: row['updated_at'] != null
          ? DateTime.parse(row['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> _toRow(Recording r) {
    return {
      'id': r.id,
      'title': r.title,
      'audio_path': r.audioPath,
      'duration_seconds': r.durationSeconds,
      'source': r.source == RecordingSource.import ? 'import' : 'app',
      'status': r.status.name,
      'created_at': r.createdAt.toIso8601String(),
      'updated_at': r.updatedAt?.toIso8601String(),
    };
  }

  RecordingStatus _parseStatus(String value) {
    return RecordingStatus.values.firstWhere(
      (e) => e.name == value,
      orElse: () => RecordingStatus.idle,
    );
  }
}
