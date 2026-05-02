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
import '../../../core/storage/local_paths.dart';
import '../../../core/services/local_whisper_service.dart';
import '../../../core/services/model_manager.dart';
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

      await _repository.update(
        recording.copyWith(
          status: RecordingStatus.transcribing,
          updatedAt: DateTime.now(),
        ),
      );

      final service = _config.createService();

      if (_config.engine == TranscriptionEngine.local &&
          service is LocalWhisperService) {
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

      _transcriptionStatus = _config.engine == TranscriptionEngine.local
          ? 'Preparando audio local y transcribiendo...'
          : 'Transcribiendo con ${_config.engine.name}...';
      _log('calling_transcribe audio=${recording.audioPath}');
      notifyListeners();

      final result = await service
          .transcribe(recording.audioPath)
          .timeout(_timeoutFor(recording, _config.engine), onTimeout: () {
        throw TranscriptionTimeoutException(
          'La transcripcion excedio el tiempo esperado y fue interrumpida. Puedes reintentar o usar OpenAI/AssemblyAI para audios importados.',
        );
      });

      _log(
          'transcribe_ok text_length=${result.text.length} segments=${result.segments.length}');

      final database = await _appDb.database;
      final transcriptionId = DateTime.now().millisecondsSinceEpoch.toString();

      _transcriptionStatus = 'Guardando transcripcion...';
      notifyListeners();

      final createdAt = DateTime.now().toIso8601String();
      final batch = database.batch();
      batch.insert('transcriptions', {
        'id': transcriptionId,
        'recording_id': recordingId,
        'full_text': result.text,
        'language': result.language,
        'model_used': result.engine.name,
        'created_at': createdAt,
      });

      for (var i = 0; i < result.segments.length; i++) {
        final segment = result.segments[i];
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
      TranscriptionEngine.openai || TranscriptionEngine.assemblyai => Duration(
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

    final summaryService = _config.createSummaryService();
    if (summaryService == null) {
      _summaryStatus = SummaryStatus.generating;
      _summaryStatusMessage = 'Generando resumen local...';
      notifyListeners();
      try {
        final result = _localSummary(text);
        _summaryStatus = SummaryStatus.done;
        _summaryStatusMessage = 'Resumen local completado';
        AppLogger.instance.info('Summary', 'Local summary generated (${result.length} chars)');
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

    _summaryStatus = SummaryStatus.connecting;
    _summaryStatusMessage = 'Conectando a ${_config.summaryEngine.name}...';
    AppLogger.instance.info('Summary', 'Connecting to ${_config.summaryEngine.name}');
    notifyListeners();

    try {
      _summaryStatus = SummaryStatus.generating;
      _summaryStatusMessage = 'Generando resumen con ${_config.summaryEngine.name}...';
      notifyListeners();

      final result = await summaryService
          .summarize(text)
          .timeout(const Duration(minutes: 5), onTimeout: () {
        throw SummaryTimeoutException(
          'El resumen excedio 5 minutos. Verifica tu conexion o intenta con resumen local.',
        );
      });

      _summaryStatus = SummaryStatus.done;
      _summaryStatusMessage = 'Conexion exitosa. Resumen completado.';
      AppLogger.instance.info('Summary', 'API summary generated (${result.summary.length} chars)');
      notifyListeners();
      return result.summary;
    } on SummaryTimeoutException {
      _summaryStatus = SummaryStatus.error;
      _summaryError = 'Tiempo de espera agotado. Verifica tu conexion a internet.';
      _summaryStatusMessage = _summaryError!;
      AppLogger.instance.warning('Summary', 'Summary timed out, falling back to local');
      notifyListeners();
      return _localSummary(text);
    } catch (e, st) {
      _summaryStatus = SummaryStatus.error;
      _summaryError = 'Error de API: $e';
      _summaryStatusMessage = _summaryError!;
      AppLogger.instance.error('Summary', 'API summary failed: $e', st.toString());
      notifyListeners();

      try {
        final fallback = _localSummary(text);
        _summaryStatus = SummaryStatus.doneWithFallback;
        _summaryStatusMessage = 'Resumen local generado como alternativa (la API falló).';
        AppLogger.instance.info('Summary', 'Fallback to local summary');
        notifyListeners();
        return fallback;
      } catch (_) {
        return null;
      }
    }
  }

  String _localSummary(String text) {
    final cleanedText = _cleanupTranscriptText(text);
    final sentences = cleanedText
        .split(RegExp(r'[.!?]+'))
        .map((s) => s.trim())
        .where((s) => s.length > 12)
        .toList();

    if (sentences.isEmpty) return cleanedText;

    final selected = <String>[];
    selected.addAll(sentences.take(2));

    final important = sentences.where((sentence) {
      final lower = sentence.toLowerCase();
      return lower.contains('acuerdo') ||
          lower.contains('decid') ||
          lower.contains('pendiente') ||
          lower.contains('tarea') ||
          lower.contains('próxim') ||
          lower.contains('proxim') ||
          lower.contains('problema') ||
          lower.contains('riesgo');
    });
    for (final sentence in important) {
      if (selected.length >= 8) break;
      if (!selected.contains(sentence)) selected.add(sentence);
    }

    final buffer = StringBuffer();
    buffer.writeln('Resumen ejecutivo');
    buffer.writeln(_ensureSentence(selected.take(3).join(' ')));
    buffer.writeln();
    buffer.writeln('Temas principales');
    for (final sentence in selected.take(5)) {
      buffer.writeln('- ${_ensureSentence(sentence)}');
    }
    buffer.writeln();
    buffer.writeln('Acciones o pendientes detectados');
    final actions = selected.where((sentence) {
      final lower = sentence.toLowerCase();
      return lower.contains('pendiente') ||
          lower.contains('tarea') ||
          lower.contains('hacer') ||
          lower.contains('próxim') ||
          lower.contains('proxim');
    }).toList();
    if (actions.isEmpty) {
      buffer.writeln('- No identificado en el resumen local.');
    } else {
      for (final action in actions.take(5)) {
        buffer.writeln('- ${_ensureSentence(action)}');
      }
    }
    buffer.writeln();
    buffer.writeln('Nota');
    buffer.writeln(
      'Este resumen local es extractivo y no corrige todos los errores de transcripcion. Para mejor calidad usa OpenAI o AssemblyAI como motor de resumen.',
    );
    return buffer.toString();
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
