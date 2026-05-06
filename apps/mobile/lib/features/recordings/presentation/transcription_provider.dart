import 'dart:io';
import 'dart:async';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:whisper_flutter_new/whisper_flutter_new.dart';

import '../../../core/database/app_database.dart' as db;
import '../../../core/services/app_logger.dart';
import '../../../core/services/assemblyai_service.dart';
import '../../../core/services/post_processing_service.dart';
import '../../../core/storage/local_paths.dart';
import '../../../core/services/local_whisper_service.dart';
import '../../../core/services/model_manager.dart';
import '../../../core/services/openai_service.dart';
import '../../../core/services/transcription_config.dart';
import '../../../core/services/transcription_service.dart';
import '../data/recording_repository.dart';
import '../domain/recording.dart';

class TranscriptionProvider extends ChangeNotifier {
  TranscriptionProvider(this._repository, this._appDb, this._config)
      : _modelManager = ModelManager();

  final RecordingRepository _repository;
  final db.AppDatabase _appDb;
  final TranscriptionConfig _config;
  final ModelManager _modelManager;
  final PostProcessingService _postProcessor = PostProcessingService();

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

  Timer? _transcriptionTicker;
  int _transcriptionElapsedSeconds = 0;
  int get transcriptionElapsedSeconds => _transcriptionElapsedSeconds;
  String get transcriptionElapsedLabel {
    final minutes =
        (_transcriptionElapsedSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds =
        (_transcriptionElapsedSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  SummaryStatus _summaryStatus = SummaryStatus.idle;
  SummaryStatus get summaryStatus => _summaryStatus;
  String _summaryStatusMessage = '';
  String get summaryStatusMessage => _summaryStatusMessage;
  String? _summaryError;
  String? get summaryError => _summaryError;

  static const int maxLocalDurationSeconds = 600;

  Future<void> transcribeRecording(String recordingId) async {
    _isTranscribing = true;
    _lastError = null;
    _transcriptionStatus = 'Preparando transcripcion...';
    _transcriptionElapsedSeconds = 0;
    _startTranscriptionTicker();
    _log(
        'transcribe_start recording=$recordingId engine=${_config.engine.name}');
    notifyListeners();

    try {
      final recording = await _repository.getById(recordingId);

      final validationError = _validateRecordingForEngine(recording);
      if (validationError != null) {
        _lastError = validationError;
        _transcriptionStatus = validationError;
        _log('transcribe_validation_failed: $validationError');
        await _repository.update(
          recording.copyWith(
            status: RecordingStatus.failed,
            updatedAt: DateTime.now(),
          ),
        );
        return;
      }

      await _repository.update(
        recording.copyWith(
          status: RecordingStatus.transcribing,
          updatedAt: DateTime.now(),
        ),
      );

      final attempts = _buildTranscriptionAttempts(recording);
      final errors = <String>[];

      for (var i = 0; i < attempts.length; i++) {
        final attempt = attempts[i];
        final isFallback = i > 0;

        try {
          if (attempt.service is LocalWhisperService) {
            await _prepareLocalModel(attempt.service as LocalWhisperService);
          }

          _transcriptionStatus = _statusForTranscriptionAttempt(
            attempt.engine,
            isFallback: isFallback,
          );
          _log(
            'calling_transcribe audio=${recording.audioPath} engine=${attempt.engine.name}',
          );
          notifyListeners();

          final result = await attempt.service
              .transcribe(recording.audioPath)
              .timeout(_timeoutFor(recording, attempt.engine), onTimeout: () {
            throw TranscriptionTimeoutException(
              'La transcripcion con ${_engineLabel(attempt.engine)} excedio el tiempo esperado.',
            );
          });

          _log(
            'transcribe_ok engine=${attempt.engine.name} text_length=${result.text.length} segments=${result.segments.length}',
          );
          await _saveTranscriptionResult(result, recording, recordingId);
          return;
        } catch (e, st) {
          errors.add('${_engineLabel(attempt.engine)}: $e');
          _log(
            'transcribe_attempt_error engine=${attempt.engine.name}: $e\n$st',
          );
        }
      }

      _lastError = errors.join('\n');
      _transcriptionStatus = _lastError!;
      await _repository.update(
        recording.copyWith(
          status: RecordingStatus.failed,
          updatedAt: DateTime.now(),
        ),
      );
    } catch (e, st) {
      _lastError = e.toString();
      _transcriptionStatus = 'Error: $e';
      _log('transcribe_error: $e\n$st');
      try {
        final recording = await _repository.getById(recordingId);
        await _repository.update(
          recording.copyWith(
            status: RecordingStatus.failed,
            updatedAt: DateTime.now(),
          ),
        );
      } catch (_) {}
    } finally {
      _transcriptionTicker?.cancel();
      _transcriptionTicker = null;
      _isTranscribing = false;
      _isModelDownloading = false;
      _downloadProgress = 0;
      _transcriptionElapsedSeconds = 0;
      notifyListeners();
    }
  }

  String? _validateRecordingForEngine(Recording recording) {
    final isLocal = _config.engine == TranscriptionEngine.local;
    final isImported = recording.source == RecordingSource.import;
    final ext = p.extension(recording.audioPath).toLowerCase();

    if (isImported && isLocal) {
      return 'Los archivos importados no se pueden transcribir con el motor local. '
          'Configura una API (OpenAI, Groq o AssemblyAI) en Ajustes para transcribir archivos importados.';
    }

    if (isLocal) {
      if (ext != '.wav') {
        return 'El motor local solo soporta archivos WAV grabados desde la app. '
            'Este archivo tiene formato $ext. Usa una API en la nube para otros formatos.';
      }
      if (recording.durationSeconds > maxLocalDurationSeconds) {
        final maxMin = maxLocalDurationSeconds ~/ 60;
        final recMin = recording.durationSeconds ~/ 60;
        return 'El motor local tiene un limite de $maxMin minutos. '
            'Esta grabacion dura $recMin minutos. Usa una API en la nube para transcribir.';
      }
    }

    return null;
  }

  bool canTranscribeLocally(Recording recording) {
    if (recording.source == RecordingSource.import) return false;
    if (p.extension(recording.audioPath).toLowerCase() != '.wav') return false;
    if (recording.durationSeconds > maxLocalDurationSeconds) return false;
    return true;
  }

  String localTranscriptionWarning(Recording recording) {
    if (recording.source == RecordingSource.import) {
      return 'Archivo importado: se requiere una API en la nube para transcribir.';
    }
    final ext = p.extension(recording.audioPath).toLowerCase();
    if (ext != '.wav') {
      return 'Formato $ext no compatible con transcripcion local. Se requiere una API en la nube.';
    }
    if (recording.durationSeconds > maxLocalDurationSeconds) {
      final maxMin = maxLocalDurationSeconds ~/ 60;
      return 'La grabacion excede el limite de $maxMin minutos para transcripcion local. Se requiere una API en la nube.';
    }
    return '';
  }

  Future<void> _prepareLocalModel(LocalWhisperService service) async {
    _isModelDownloading = true;
    _downloadProgress = 0;
    _transcriptionStatus = 'Verificando modelo local...';
    notifyListeners();

    final available = await service.isAvailable();
    if (!available) {
      _transcriptionStatus = 'Descargando modelo Whisper...';
      _log('download_start');
      notifyListeners();

      await service.ensureModel(
        onProgress: (progress) {
          _downloadProgress = progress;
          _log('download_progress: ${(progress * 100).toInt()}%');
          notifyListeners();
        },
      );

      _log('download_complete');
    } else {
      _log('model_already_available');
    }
    _isModelDownloading = false;
    _downloadProgress = 0;
  }

  List<_TranscriptionAttempt> _buildTranscriptionAttempts(Recording recording) {
    final isImported = recording.source == RecordingSource.import;
    final canLocal = !isImported &&
        p.extension(recording.audioPath).toLowerCase() == '.wav' &&
        recording.durationSeconds <= maxLocalDurationSeconds;

    if (_config.engine == TranscriptionEngine.local) {
      if (!canLocal) return [];
      return [
        _TranscriptionAttempt(
          engine: TranscriptionEngine.local,
          service: _config.createFallbackService(),
        ),
      ];
    }

    final attempts = <_TranscriptionAttempt>[];
    final orderedEngines = <TranscriptionEngine>[
      _config.engine,
      ...TranscriptionEngine.values.where(
        (engine) =>
            engine != _config.engine && engine != TranscriptionEngine.local,
      ),
      if (canLocal) TranscriptionEngine.local,
    ];

    for (final engine in orderedEngines) {
      final service = _createServiceForEngine(engine);
      if (service != null) {
        attempts.add(_TranscriptionAttempt(engine: engine, service: service));
      }
    }

    return attempts;
  }

  TranscriptionService? _createServiceForEngine(TranscriptionEngine engine) {
    return switch (engine) {
      TranscriptionEngine.local => _config.createFallbackService(),
      TranscriptionEngine.groq => _config.groqKey.isEmpty
          ? null
          : OpenAITranscriptionService(
              apiKey: _config.groqKey,
              baseUrl: 'https://api.groq.com/openai/v1',
              model: _config.groqModel,
              enableChunking: true,
              engineType: TranscriptionEngine.groq,
            ),
      TranscriptionEngine.openai => _config.openAiKey.isEmpty
          ? null
          : OpenAITranscriptionService(
              apiKey: _config.openAiKey,
              baseUrl: _config.openAiBaseUrl,
              model: _config.openAiModel,
              engineType: TranscriptionEngine.openai,
            ),
      TranscriptionEngine.assemblyai => _config.assemblyAiKey.isEmpty
          ? null
          : AssemblyAITranscriptionService(apiKey: _config.assemblyAiKey),
    };
  }

  String _statusForTranscriptionAttempt(
    TranscriptionEngine engine, {
    required bool isFallback,
  }) {
    if (engine == TranscriptionEngine.local) {
      return isFallback
          ? 'Las APIs no respondieron. Usando motor local...'
          : 'Preparando audio local y transcribiendo...';
    }

    if (isFallback) {
      return 'Reintentando con ${_engineLabel(engine)}...';
    }

    return 'Transcribiendo con ${_engineLabel(engine)}...';
  }

  String _engineLabel(TranscriptionEngine engine) {
    return switch (engine) {
      TranscriptionEngine.local => 'motor local',
      TranscriptionEngine.groq => 'Groq',
      TranscriptionEngine.openai => 'OpenAI',
      TranscriptionEngine.assemblyai => 'AssemblyAI',
    };
  }

  Future<void> _saveTranscriptionResult(
    TranscriptionResult result,
    Recording recording,
    String recordingId,
  ) async {
    var processedText = result.text;
    var processedSegments = result.segments;

    if (_config.postProcessingEnabled) {
      _transcriptionStatus = 'Mejorando coherencia del texto...';
      notifyListeners();

      final processed = _postProcessor.process(
        result.text,
        result.segments,
        level: _config.postProcessingLevel,
      );
      processedText = processed.text;
      processedSegments = processed.segments;
      _log(
          'postprocessed level=${processed.level.name} elapsed=${processed.elapsedMs}ms text_length=${processedText.length}');
    }

    final database = await _appDb.database;
    final transcriptionId = DateTime.now().millisecondsSinceEpoch.toString();

    _transcriptionStatus = 'Guardando transcripcion...';
    notifyListeners();

    final createdAt = DateTime.now().toIso8601String();
    final batch = database.batch();
    batch.insert('transcriptions', {
      'id': transcriptionId,
      'recording_id': recordingId,
      'full_text': processedText,
      'language': result.language,
      'model_used': result.engine.name,
      'created_at': createdAt,
    });

    for (var i = 0; i < processedSegments.length; i++) {
      final segment = processedSegments[i];
      batch.insert('segments', {
        'id': '${transcriptionId}_$i',
        'transcription_id': transcriptionId,
        'speaker_label': segment.speaker ?? 'Hablante 1',
        'speaker_name': null,
        'start_time': segment.startTime,
        'end_time': segment.endTime,
        'text': segment.text,
      });
    }

    await batch.commit(noResult: true);

    await _repository.update(
      recording.copyWith(
        status: RecordingStatus.done,
        updatedAt: DateTime.now(),
      ),
    );

    _transcriptionStatus = 'Transcripcion completada';
    _log('transcribe_completed');
  }

  void _startTranscriptionTicker() {
    _transcriptionTicker?.cancel();
    _transcriptionTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      _transcriptionElapsedSeconds++;
      notifyListeners();
    });
  }

  Duration _timeoutFor(Recording recording, TranscriptionEngine engine) {
    final audioSeconds =
        recording.durationSeconds <= 0 ? 180 : recording.durationSeconds;
    return switch (engine) {
      TranscriptionEngine.local => Duration(
          seconds: (audioSeconds * 2 + 120).clamp(420, 1200),
        ),
      TranscriptionEngine.openai ||
      TranscriptionEngine.groq ||
      TranscriptionEngine.assemblyai =>
        Duration(
          seconds: (audioSeconds * 2 + 180).clamp(420, 1800),
        ),
    };
  }

  Future<bool> isModelAvailable() async {
    final service = _config.createService();
    if (service is LocalWhisperService) {
      return service.isAvailable();
    }
    return true;
  }

  Future<ModelInfo?> getModelInfo() async {
    if (_config.engine != TranscriptionEngine.local) return null;
    final model = _parseWhisperModel(_config.whisperModel);
    return _modelManager.getModelInfo(model);
  }

  Future<void> replaceLocalModel(
    String nextModelName, {
    void Function(double progress)? onProgress,
  }) async {
    final previousModelName = _config.whisperModel;
    if (previousModelName == nextModelName) return;

    final previousModel = _parseWhisperModel(previousModelName);
    final nextModel = _parseWhisperModel(nextModelName);

    await _modelManager.ensureModel(nextModel, onProgress: onProgress);
    await _config.setWhisperModel(nextModelName);
    await _modelManager.deleteModel(previousModel);
  }

  Future<String> getStorageInfo() async {
    if (_config.engine != TranscriptionEngine.local) return 'N/A';
    final info = await getModelInfo();
    if (info == null) return 'Modelo no descargado';
    return '${info.model.modelName} - ${info.sizeFormatted}';
  }

  WhisperModel _parseWhisperModel(String name) {
    return switch (name) {
      'tiny' => WhisperModel.tiny,
      'base' => WhisperModel.base,
      'small' => WhisperModel.small,
      'medium' => WhisperModel.medium,
      'large-v1' => WhisperModel.largeV1,
      'large-v2' => WhisperModel.largeV2,
      _ => WhisperModel.tiny,
    };
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

  Future<void> deleteTranscription(String recordingId) async {
    final database = await _appDb.database;
    final transRows = await database.query(
      'transcriptions',
      columns: ['id'],
      where: 'recording_id = ?',
      whereArgs: [recordingId],
    );

    final batch = database.batch();
    for (final row in transRows) {
      final transcriptionId = row['id'] as String;
      batch.delete(
        'segments',
        where: 'transcription_id = ?',
        whereArgs: [transcriptionId],
      );
    }
    batch.delete(
      'transcriptions',
      where: 'recording_id = ?',
      whereArgs: [recordingId],
    );
    await batch.commit(noResult: true);

    final recording = await _repository.getById(recordingId);
    await _repository.update(
      recording.copyWith(
        status: RecordingStatus.saved,
        updatedAt: DateTime.now(),
      ),
    );
  }

  Future<String?> generateSummary(String recordingId) async {
    final text = await getTranscriptionText(recordingId);
    if (text == null || text.isEmpty) return null;

    _summaryError = null;
    _summaryStatusMessage = 'Preparando resumen...';

    final mode = _config.summaryMode;

    final attempts = _buildSummaryAttempts();
    if (attempts.isEmpty) {
      _summaryStatus = SummaryStatus.generating;
      _summaryStatusMessage = 'Generando resumen local (${mode == SummaryMode.meeting ? "reunion" : "apuntes"})...';
      notifyListeners();
      try {
        final result = _localSummary(text, mode: mode);
        _summaryStatus = SummaryStatus.done;
        _summaryStatusMessage = 'Resumen local completado';
        AppLogger.instance.info('Summary', 'Local summary generated (${result.length} chars, mode=${mode.name})');
        notifyListeners();
        return result;
      } catch (e, st) {
        _summaryStatus = SummaryStatus.error;
        _summaryError = 'Error en resumen local: $e';
        _summaryStatusMessage = _summaryError!;
        AppLogger.instance.error('Summary', 'Local summary failed: $e', st.toString());
        notifyListeners();
        return null;
      }
    }

    final errors = <String>[];
    for (var i = 0; i < attempts.length; i++) {
      final attempt = attempts[i];
      final isFallback = i > 0;

      _summaryStatus = i == 0 ? SummaryStatus.connecting : SummaryStatus.generating;
      _summaryStatusMessage = isFallback
          ? 'Reintentando resumen con ${_engineLabel(attempt.engine)}...'
          : 'Generando resumen con ${_engineLabel(attempt.engine)}...';
      AppLogger.instance.info(
        'Summary',
        'Generating summary with ${attempt.engine.name} mode=${mode.name}',
      );
      notifyListeners();

      try {
        final result = await attempt.service
            .summarize(text, mode: mode)
            .timeout(const Duration(minutes: 5), onTimeout: () {
          throw SummaryTimeoutException(
            'El resumen con ${_engineLabel(attempt.engine)} excedio 5 minutos.',
          );
        });

        _summaryStatus = isFallback ? SummaryStatus.doneWithFallback : SummaryStatus.done;
        _summaryStatusMessage = isFallback
            ? 'Resumen completado con ${_engineLabel(attempt.engine)} como alternativa.'
            : 'Resumen completado.';
        AppLogger.instance.info(
          'Summary',
          'API summary generated (${result.summary.length} chars, engine=${attempt.engine.name})',
        );
        notifyListeners();
        return result.summary;
      } catch (e, st) {
        errors.add('${_engineLabel(attempt.engine)}: $e');
        AppLogger.instance.error(
          'Summary',
          'API summary failed with ${attempt.engine.name}: $e',
          st.toString(),
        );
      }
    }

    try {
      final fallback = _localSummary(text, mode: mode);
      _summaryStatus = SummaryStatus.doneWithFallback;
      _summaryStatusMessage = 'Resumen local generado como alternativa.';
      AppLogger.instance.info('Summary', 'Fallback to local summary');
      notifyListeners();
      return fallback;
    } catch (e, st) {
      _summaryStatus = SummaryStatus.error;
      _summaryError = errors.isEmpty ? 'Error al generar resumen: $e' : errors.join('\n');
      _summaryStatusMessage = _summaryError!;
      AppLogger.instance.error('Summary', 'Local summary fallback failed: $e', st.toString());
      notifyListeners();
      return null;
    }
  }

  List<_SummaryAttempt> _buildSummaryAttempts() {
    if (_config.summaryEngine == SummaryEngine.local) {
      return const [];
    }

    final attempts = <_SummaryAttempt>[];
    final orderedEngines = <SummaryEngine>[
      _config.summaryEngine,
      ...SummaryEngine.values.where(
        (engine) =>
            engine != _config.summaryEngine && engine != SummaryEngine.local,
      ),
    ];

    for (final engine in orderedEngines) {
      final service = _createSummaryServiceForEngine(engine);
      if (service != null) {
        attempts.add(_SummaryAttempt(engine: _mapSummaryEngine(engine), service: service));
      }
    }

    return attempts;
  }

  SummaryService? _createSummaryServiceForEngine(SummaryEngine engine) {
    return switch (engine) {
      SummaryEngine.local => null,
      SummaryEngine.groq => _config.groqKey.isEmpty
          ? null
          : OpenAISummaryService(
              apiKey: _config.groqKey,
              baseUrl: 'https://api.groq.com/openai/v1',
              model: 'llama-3.3-70b-versatile',
              engineType: TranscriptionEngine.groq,
            ),
      SummaryEngine.openai => _config.summaryOpenAiKey.isEmpty
          ? null
          : OpenAISummaryService(
              apiKey: _config.summaryOpenAiKey,
              baseUrl: _config.summaryOpenAiBaseUrl,
              model: _config.summaryOpenAiModel,
              engineType: TranscriptionEngine.openai,
            ),
      SummaryEngine.assemblyai => _config.summaryAssemblyAiKey.isEmpty
          ? null
          : AssemblyAISummaryService(
              apiKey: _config.summaryAssemblyAiKey,
            ),
    };
  }

  TranscriptionEngine _mapSummaryEngine(SummaryEngine engine) {
    return switch (engine) {
      SummaryEngine.local => TranscriptionEngine.local,
      SummaryEngine.groq => TranscriptionEngine.groq,
      SummaryEngine.openai => TranscriptionEngine.openai,
      SummaryEngine.assemblyai => TranscriptionEngine.assemblyai,
    };
  }

  String _localSummary(String text, {SummaryMode mode = SummaryMode.meeting}) {
    final cleanedText = _cleanupTranscriptText(text);
    final sentences = _extractMeaningfulSentences(cleanedText);

    if (sentences.isEmpty) return cleanedText;

    if (mode == SummaryMode.meeting) {
      return _buildMeetingSummary(sentences, cleanedText);
    } else {
      return _buildNotesSummary(sentences, cleanedText);
    }
  }

  List<String> _extractMeaningfulSentences(String text) {
    return text
        .split(RegExp(r'[.!?]+'))
        .map((s) => s.trim())
        .where((s) => s.length > 12)
        .toList();
  }

  String _buildMeetingSummary(List<String> sentences, String fullText) {
    final buffer = StringBuffer();

    buffer.writeln('## Resumen ejecutivo');
    final executive = sentences.take(3).map(_ensureSentence).join(' ');
    buffer.writeln(executive);
    buffer.writeln();

    buffer.writeln('## Temas tratados');
    final topicSentences = <String>[];
    final topicKeywords = [
      'tratar', 'hablar', 'tratar', 'tema', 'punto', 'asunto',
      'respecto a', 'sobre', 'referente', 'relacionado',
      'proyecto', 'sprint', 'plan', 'avance', 'estado',
      'revisar', 'analizar', 'evaluar', 'discutir',
    ];
    for (final s in sentences) {
      if (topicSentences.length >= 6) break;
      final lower = s.toLowerCase();
      if (topicKeywords.any((kw) => lower.contains(kw))) {
        if (!topicSentences.contains(s)) topicSentences.add(s);
      }
    }
    if (topicSentences.isEmpty) {
      topicSentences.addAll(sentences.take(4));
    }
    for (final s in topicSentences) {
      buffer.writeln('- ${_ensureSentence(s)}');
    }
    buffer.writeln();

    buffer.writeln('## Acuerdos y decisiones');
    final agreementKeywords = [
      'acuerdo', 'acord', 'decid', 'confirm', 'aprobar', 'aproba',
      'definir', 'definid', 'establecer', 'establecid',
      'vamos a', 'sera', 'seran', 'quedo en', 'quedamos',
    ];
    final agreements = sentences.where((s) {
      final lower = s.toLowerCase();
      return agreementKeywords.any((kw) => lower.contains(kw));
    }).toList();
    if (agreements.isEmpty) {
      buffer.writeln('- Sin acuerdos formales identificados.');
    } else {
      for (final a in agreements.take(5)) {
        buffer.writeln('- ${_ensureSentence(a)}');
      }
    }
    buffer.writeln();

    buffer.writeln('## Acciones pendientes');
    final actionKeywords = [
      'pendiente', 'tarea', 'hacer', 'falta', 'necesit',
      'proximo', 'proxima', 'siguiente', 'plazo', 'entrega',
      'antes de', 'para el', 'febrero', 'marzo', 'abril',
      'semana que', 'mañana', 'lunes', 'martes', 'miercoles',
    ];
    final actions = sentences.where((s) {
      final lower = s.toLowerCase();
      return actionKeywords.any((kw) => lower.contains(kw));
    }).toList();
    if (actions.isEmpty) {
      buffer.writeln('- Sin acciones pendientes explicitas.');
    } else {
      for (final a in actions.take(6)) {
        buffer.writeln('- [ ] ${_ensureSentence(a)}');
      }
    }
    buffer.writeln();

    buffer.writeln('## Riesgos y dudas');
    final riskKeywords = [
      'riesgo', 'problema', 'duda', 'incertidum', 'bloqueo',
      'preocup', 'dificultad', 'impedimento', 'atraso', 'retraso',
      'no se', 'no sabemos', 'podria ser', 'tal vez',
    ];
    final risks = sentences.where((s) {
      final lower = s.toLowerCase();
      return riskKeywords.any((kw) => lower.contains(kw));
    }).toList();
    if (risks.isEmpty) {
      buffer.writeln('- Sin riesgos evidentes.');
    } else {
      for (final r in risks.take(4)) {
        buffer.writeln('- ${_ensureSentence(r)}');
      }
    }
    buffer.writeln();

    buffer.writeln('---');
    buffer.writeln('*Resumen local extractivo. Para mejor calidad, usa un motor de resumen con IA.*');

    return buffer.toString();
  }

  String _buildNotesSummary(List<String> sentences, String fullText) {
    final buffer = StringBuffer();

    buffer.writeln('## Tema principal');
    buffer.writeln(_ensureSentence(sentences.take(2).join(' ')));
    buffer.writeln();

    buffer.writeln('## Conceptos clave');
    final conceptKeywords = [
      'define', 'definicion', 'concepto', 'significa', 'llamado',
      'conocido como', 'se refiere', 'es un', 'es una', 'son los',
      'tipo de', 'clasificacion', 'categoria',
      'formula', 'ecuacion', 'teorema', 'ley', 'principio', 'regla',
    ];
    final concepts = sentences.where((s) {
      final lower = s.toLowerCase();
      return conceptKeywords.any((kw) => lower.contains(kw));
    }).toList();
    if (concepts.isEmpty) {
      for (final s in sentences.take(4)) {
        buffer.writeln('- ${_ensureSentence(s)}');
      }
    } else {
      for (final c in concepts.take(8)) {
        buffer.writeln('- **${_extractKeyPhrase(c)}**: ${_ensureSentence(c)}');
      }
    }
    buffer.writeln();

    buffer.writeln('## Desarrollo');
    final developmentSentences = <String>[];
    final devKeywords = [
      'porque', 'por que', 'entonces', 'ademas', 'tambien',
      'primero', 'segundo', 'luego', 'despues', 'finalmente',
      'ejemplo', 'caso', 'instancia', 'situacion',
      'importante', 'relevante', 'fundamental', 'necesario',
      'diferencia', 'comparar', 'ventaja', 'desventaja',
    ];
    for (final s in sentences) {
      if (developmentSentences.length >= 10) break;
      final lower = s.toLowerCase();
      if (devKeywords.any((kw) => lower.contains(kw))) {
        if (!developmentSentences.contains(s)) developmentSentences.add(s);
      }
    }
    if (developmentSentences.length < 3) {
      developmentSentences.clear();
      developmentSentences.addAll(sentences.skip(2).take(8));
    }
    for (final s in developmentSentences) {
      buffer.writeln('- ${_ensureSentence(s)}');
    }
    buffer.writeln();

    buffer.writeln('## Ejemplos');
    final exampleKeywords = [
      'ejemplo', 'por ejemplo', 'caso', 'instancia', 'supongamos',
      'imaginar', 'digamos que', 'como si', 'ilustra',
    ];
    final examples = sentences.where((s) {
      final lower = s.toLowerCase();
      return exampleKeywords.any((kw) => lower.contains(kw));
    }).toList();
    if (examples.isEmpty) {
      buffer.writeln('- Sin ejemplos explicitos en la transcripcion.');
    } else {
      for (final e in examples.take(5)) {
        buffer.writeln('- ${_ensureSentence(e)}');
      }
    }
    buffer.writeln();

    buffer.writeln('## Preguntas de repaso');
    final questionKeywords = [
      'que es', 'como', 'cuando', 'donde', 'cual', 'cuanto',
      'por que', 'para que', 'quien',
    ];
    final questions = <String>[];
    for (final s in sentences) {
      if (questions.length >= 5) break;
      final lower = s.toLowerCase();
      if (questionKeywords.any((kw) => lower.contains(kw))) {
        questions.add(_ensureSentence(s).replaceAll('?', '?'));
      }
    }
    if (questions.length < 3) {
      final autoQuestions = _generateReviewQuestions(sentences);
      questions.addAll(autoQuestions);
    }
    for (var i = 0; i < questions.length && i < 5; i++) {
      buffer.writeln('${i + 1}. ${questions[i]}');
    }
    buffer.writeln();

    buffer.writeln('---');
    buffer.writeln('*Resumen local extractivo. Para mejor calidad, usa un motor de resumen con IA.*');

    return buffer.toString();
  }

  String _extractKeyPhrase(String sentence) {
    final words = sentence.split(RegExp(r'\s+'));
    if (words.length <= 4) return sentence;
    return words.take(4).join(' ');
  }

  List<String> _generateReviewQuestions(List<String> sentences) {
    final questions = <String>[];
    final important = sentences.take(8).toList();
    for (var i = 0; i < important.length && questions.length < 4; i += 2) {
      final s = important[i];
      questions.add('De acuerdo con la transcripcion, ${_ensureSentence(s).toLowerCase().replaceAll('.', '')}?');
    }
    return questions;
  }

  String _cleanupTranscriptText(String text) {
    final collapsed = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (collapsed.isEmpty) return collapsed;
    return collapsed[0].toUpperCase() + collapsed.substring(1);
  }

  String _ensureSentence(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return trimmed;
    final capitalized = trimmed[0].toUpperCase() + trimmed.substring(1);
    return RegExp(r'[.!?]$').hasMatch(capitalized)
        ? capitalized
        : '$capitalized.';
  }

  Future<File> exportTranscription(
    String recordingId, {
    String? recordingTitle,
    String? summary,
    ExportFormat format = ExportFormat.txt,
  }) async {
    final exportDir = Directory(await LocalPaths.exportsDir);
    if (!await exportDir.exists()) {
      await exportDir.create(recursive: true);
    }

    final safeTitle = _safeFileName(recordingTitle ?? 'transcripcion');
    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    final fileName = '${safeTitle}_$timestamp.${format.extension}';
    final file = File(p.join(exportDir.path, fileName));
    final bytes = await buildExportBytes(
      recordingId,
      recordingTitle: recordingTitle,
      summary: summary,
      format: format,
    );
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  Future<String?> saveExportAs(
    String recordingId, {
    String? recordingTitle,
    String? summary,
    required ExportFormat format,
  }) async {
    final safeTitle = _safeFileName(recordingTitle ?? 'transcripcion');
    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    final fileName = '${safeTitle}_$timestamp.${format.extension}';
    final bytes = await buildExportBytes(
      recordingId,
      recordingTitle: recordingTitle,
      summary: summary,
      format: format,
    );

    return FilePicker.platform.saveFile(
      dialogTitle: 'Guardar ${format.label}',
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: [format.extension],
      bytes: bytes,
    );
  }

  Future<Uint8List> buildExportBytes(
    String recordingId, {
    String? recordingTitle,
    String? summary,
    required ExportFormat format,
  }) async {
    final text = await _buildExportText(
      recordingId,
      recordingTitle: recordingTitle,
      summary: summary,
    );
    if (format == ExportFormat.txt) {
      return Uint8List.fromList(utf8.encode(text));
    }
    return _buildPdfBytes(text, recordingTitle ?? 'Transcripcion');
  }

  Future<String> _buildExportText(
    String recordingId, {
    String? recordingTitle,
    String? summary,
  }) async {
    final fullText = await getTranscriptionText(recordingId);
    if (fullText == null || fullText.trim().isEmpty) {
      throw Exception('No hay transcripcion disponible para exportar');
    }

    final segments = await getSegments(recordingId);
    final buffer = StringBuffer();
    buffer.writeln('Sami Transcribe');
    buffer.writeln('Registro: $recordingId');
    if (recordingTitle != null && recordingTitle.isNotEmpty) {
      buffer.writeln('Titulo: $recordingTitle');
    }
    buffer.writeln('Motor: ${_config.engine.name}');
    buffer.writeln('Exportado: ${DateTime.now().toIso8601String()}');
    buffer.writeln();

    if (summary != null && summary.trim().isNotEmpty) {
      buffer.writeln('Resumen');
      buffer.writeln(summary.trim());
      buffer.writeln();
    }

    if (segments.isNotEmpty) {
      buffer.writeln('Segmentos:');
      for (final segment in segments) {
        final speaker = segment['speaker_label'] as String? ?? 'Hablante 1';
        final start = (segment['start_time'] as num?)?.toDouble() ?? 0.0;
        final end = (segment['end_time'] as num?)?.toDouble() ?? 0.0;
        final text = segment['text'] as String? ?? '';
        buffer.writeln(
            '[${_formatSeconds(start)} - ${_formatSeconds(end)}] $speaker: $text');
      }
      buffer.writeln();
    }

    buffer.writeln('Transcripcion completa:');
    buffer.writeln(fullText);
    return buffer.toString();
  }

  Future<Uint8List> _buildPdfBytes(String text, String title) async {
    final doc = pw.Document();
    final lines = text.split('\n');
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          pw.Text(
            title,
            style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 16),
          ...lines.map((line) {
            final isHeader = line == 'Resumen' ||
                line == 'Segmentos:' ||
                line == 'Transcripcion completa:' ||
                line == 'Sami Transcribe';
            return pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 4),
              child: pw.Text(
                line,
                style: pw.TextStyle(
                  fontSize: isHeader ? 13 : 10,
                  fontWeight:
                      isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
                ),
              ),
            );
          }),
        ],
      ),
    );
    return doc.save();
  }

  String _safeFileName(String input) {
    final normalized =
        input.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9\-\s_]'), '');
    return normalized.replaceAll(RegExp(r'\s+'), '_').isEmpty
        ? 'transcripcion'
        : normalized.replaceAll(RegExp(r'\s+'), '_');
  }

  String _formatSeconds(double seconds) {
    final total = seconds.round();
    final minutes = (total ~/ 60).toString().padLeft(2, '0');
    final secs = (total % 60).toString().padLeft(2, '0');
    return '$minutes:$secs';
  }

  void _log(String message) {
    AppLogger.instance.info('TranscriptionProvider', message);
  }
}

class _TranscriptionAttempt {
  const _TranscriptionAttempt({required this.engine, required this.service});

  final TranscriptionEngine engine;
  final TranscriptionService service;
}

class _SummaryAttempt {
  const _SummaryAttempt({required this.engine, required this.service});

  final TranscriptionEngine engine;
  final SummaryService service;
}

class TranscriptionTimeoutException implements Exception {
  TranscriptionTimeoutException(this.message);

  final String message;

  @override
  String toString() => message;
}

class SummaryTimeoutException implements Exception {
  SummaryTimeoutException(this.message);

  final String message;

  @override
  String toString() => message;
}

enum SummaryStatus {
  idle,
  connecting,
  generating,
  done,
  doneWithFallback,
  error,
}

enum ExportFormat {
  txt('TXT', 'txt'),
  pdf('PDF', 'pdf');

  const ExportFormat(this.label, this.extension);

  final String label;
  final String extension;
}
