import 'package:flutter/foundation.dart';
import 'package:whisper_flutter_new/whisper_flutter_new.dart';

import 'model_manager.dart';
import 'transcription_service.dart';

class LocalWhisperService implements TranscriptionService {
  LocalWhisperService({
    WhisperModel model = WhisperModel.base,
    ModelManager? modelManager,
  })  : _model = model,
        _modelManager = modelManager ?? ModelManager();

  final WhisperModel _model;
  final ModelManager _modelManager;

  @override
  TranscriptionEngine get engine => TranscriptionEngine.local;

  @override
  Future<bool> isAvailable() async {
    return _modelManager.isAvailable(_model);
  }

  Future<void> ensureModel({void Function(double progress)? onProgress}) async {
    await _modelManager.ensureModel(_model, onProgress: onProgress);
  }

  @override
  Future<TranscriptionResult> transcribe(String audioPath) async {
    _log('transcribe_start audio=$audioPath model=${_model.modelName}');

    try {
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
