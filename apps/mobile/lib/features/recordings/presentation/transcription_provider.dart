import 'package:flutter/foundation.dart';

import '../../../core/database/app_database.dart' as db;
import '../../../core/services/local_whisper_service.dart';
import '../../../core/services/transcription_config.dart';
import '../../../core/services/transcription_service.dart';
import '../data/recording_repository.dart';
import '../domain/recording.dart';

class TranscriptionProvider extends ChangeNotifier {
  TranscriptionProvider(this._repository, this._appDb, this._config);

  final RecordingRepository _repository;
  final db.AppDatabase _appDb;
  final TranscriptionConfig _config;

  bool _isTranscribing = false;
  bool get isTranscribing => _isTranscribing;

  String _transcriptionStatus = '';
  String get transcriptionStatus => _transcriptionStatus;

  String? _lastError;
  String? get lastError => _lastError;

  bool _isModelDownloading = false;
  bool get isModelDownloading => _isModelDownloading;

  double _downloadProgress = 0;
  double get downloadProgress => _downloadProgress;

  Future<void> transcribeRecording(String recordingId) async {
    _isTranscribing = true;
    _lastError = null;
    _transcriptionStatus = 'Preparando transcripcion...';
    _log('transcribe_start recording=$recordingId engine=${_config.engine.name}');
    notifyListeners();

    try {
      final recording = await _repository.getById(recordingId);
      if (recording == null) {
        throw TranscriptionException('Grabacion no encontrada');
      }

      await _repository.update(
        recording.copyWith(
          status: RecordingStatus.transcribing,
          updatedAt: DateTime.now(),
        ),
      );

      final service = _config.createService();

      if (_config.engine == TranscriptionEngine.local) {
        _isModelDownloading = true;
        _downloadProgress = 0.1;
        _transcriptionStatus = 'Verificando modelo local...';
        notifyListeners();

        final available = await service.isAvailable();
        if (!available) {
          _transcriptionStatus = 'Descargando modelo Whisper...';
          _downloadProgress = 0.3;
          notifyListeners();
        } else {
          _log('model_already_available');
        }
        _isModelDownloading = false;
        _downloadProgress = 0;
      }

      _transcriptionStatus = 'Transcribiendo con ${_config.engine.name}...';
      _log('calling_transcribe audio=${recording.audioPath}');
      notifyListeners();

      final result = await service.transcribe(recording.audioPath);

      _log('transcribe_ok text_length=${result.text.length} segments=${result.segments.length}');

      final database = await _appDb.database;
      final transcriptionId = DateTime.now().millisecondsSinceEpoch.toString();

      await database.insert('transcriptions', {
        'id': transcriptionId,
        'recording_id': recordingId,
        'full_text': result.text,
        'language': result.language,
        'model_used': result.engine.name,
        'created_at': DateTime.now().toIso8601String(),
      });

      for (final segment in result.segments) {
        final segmentId =
            '${transcriptionId}_${result.segments.indexOf(segment)}';
        await database.insert('segments', {
          'id': segmentId,
          'transcription_id': transcriptionId,
          'speaker_label': segment.speaker ?? 'Hablante 1',
          'speaker_name': null,
          'start_time': segment.startTime,
          'end_time': segment.endTime,
          'text': segment.text,
        });
      }

      await _repository.update(
        recording.copyWith(
          status: RecordingStatus.done,
          updatedAt: DateTime.now(),
        ),
      );

      _transcriptionStatus = 'Transcripcion completada';
      _log('transcribe_completed');
    } catch (e, st) {
      _lastError = e.toString();
      _transcriptionStatus = 'Error: $e';
      _log('transcribe_error: $e\n$st');
      try {
        final recording = await _repository.getById(recordingId);
        if (recording != null) {
          await _repository.update(
            recording.copyWith(
              status: RecordingStatus.failed,
              updatedAt: DateTime.now(),
            ),
          );
        }
      } catch (_) {}
    } finally {
      _isTranscribing = false;
      _isModelDownloading = false;
      _downloadProgress = 0;
      notifyListeners();
    }
  }

  Future<String?> getTranscriptionText(String recordingId) async {
    final database = await _appDb.database;
    final rows = await database.query(
      'transcriptions',
      where: 'recording_id = ?',
      whereArgs: [recordingId],
      orderBy: 'created_at DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['full_text'] as String;
  }

  Future<List<Map<String, dynamic>>> getSegments(String recordingId) async {
    final database = await _appDb.database;
    final transRows = await database.query(
      'transcriptions',
      where: 'recording_id = ?',
      whereArgs: [recordingId],
      orderBy: 'created_at DESC',
      limit: 1,
    );
    if (transRows.isEmpty) return [];

    final transId = transRows.first['id'] as String;
    return database.query(
      'segments',
      where: 'transcription_id = ?',
      whereArgs: [transId],
      orderBy: 'start_time ASC',
    );
  }

  Future<String?> generateSummary(String recordingId) async {
    final text = await getTranscriptionText(recordingId);
    if (text == null || text.isEmpty) return null;

    final summaryService = _config.createSummaryService();
    if (summaryService == null) {
      return _localSummary(text);
    }

    final result = await summaryService.summarize(text);
    return result.summary;
  }

  String _localSummary(String text) {
    final sentences =
        text.split(RegExp(r'[.!?]+')).where((s) => s.trim().isNotEmpty).toList();
    if (sentences.length <= 3) return text;
    final buffer = StringBuffer('Resumen automatico:\n\n');
    for (var i = 0; i < sentences.length && i < 8; i++) {
      buffer.writeln('- ${sentences[i].trim()}');
    }
    return buffer.toString();
  }

  void _log(String message) {
    debugPrint('[TranscriptionProvider] $message');
  }
}
