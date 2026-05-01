import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:whisper_flutter_new/whisper_flutter_new.dart';

import 'transcription_service.dart';

class LocalWhisperService implements TranscriptionService {
  LocalWhisperService({WhisperModel model = WhisperModel.base}) : _model = model;

  final WhisperModel _model;

  @override
  TranscriptionEngine get engine => TranscriptionEngine.local;

  @override
  Future<bool> isAvailable() async {
    try {
      final dir = await _modelDir();
      final modelFile = File(_model.getPath(dir));
      final exists = modelFile.existsSync();
      _log('isAvailable -> $exists (path: ${modelFile.path})');
      return exists;
    } catch (e) {
      _log('isAvailable error: $e');
      return false;
    }
  }

  Future<String> _modelDir() async {
    final directory = Platform.isAndroid
        ? await getApplicationSupportDirectory()
        : await getLibraryDirectory();
    return directory.path;
  }

  @override
  Future<TranscriptionResult> transcribe(String audioPath) async {
    _log('transcribe_start audio=$audioPath model=${_model.modelName}');

    try {
      final modelDir = await _modelDir();
      final modelFile = File(_model.getPath(modelDir));
      if (!modelFile.existsSync()) {
        _log('model_not_found, descargando...');
      }

      final whisper = Whisper(model: _model);

      final result = await whisper.transcribe(
        transcribeRequest: TranscribeRequest(
          audio: audioPath,
          language: 'es',
          isTranslate: false,
        ),
      );

      _log('transcribe_end text_length=${result.text.length}');

      final segments = <TranscriptSegment>[];
      if (result.segments != null) {
        for (final seg in result.segments!) {
          segments.add(
            TranscriptSegment(
              startTime: seg.fromTs.inMilliseconds / 1000.0,
              endTime: seg.toTs.inMilliseconds / 1000.0,
              text: seg.text,
            ),
          );
        }
      }

      return TranscriptionResult(
        text: result.text,
        engine: engine,
        language: 'es',
        segments: segments,
      );
    } catch (e, st) {
      _log('transcribe_error: $e\n$st');
      throw TranscriptionException('Error en transcripcion local: $e');
    }
  }

  void _log(String message) {
    debugPrint('[LocalWhisper] $message');
  }
}

class TranscriptionException implements Exception {
  TranscriptionException(this.message);
  final String message;
  @override
  String toString() => message;
}
