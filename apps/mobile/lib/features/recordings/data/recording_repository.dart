import '../domain/recording.dart';

abstract class RecordingRepository {
  Future<List<Recording>> list();
  Stream<List<Recording>> watchAll();
  Future<Recording> getById(String id);
  Future<void> save(Recording recording);
  Future<void> update(Recording recording);
  Future<void> delete(String id);
}
