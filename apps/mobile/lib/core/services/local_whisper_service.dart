import 'dart:io';

import 'package:whisper_flutter_new/whisper_flutter_new.dart';

import 'app_logger.dart';
import 'model_manager.dart';
import 'transcription_service.dart';
import 'wav_audio_preparer.dart';

class LocalWhisperService implements TranscriptionService {
  LocalWhisperService({
    WhisperModel model = WhisperModel.tiny,
    ModelManager? modelManager,
  })  : _model = model,
        _modelManager = modelManager ?? ModelManager();

  final WhisperModel _model;
  final ModelManager _modelManager;
  final WavAudioPreparer _audioPreparer = WavAudioPreparer();

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
    PreparedAudioFile? preparedAudio;

    try {
      preparedAudio = await _audioPreparer.prepareForWhisper(audioPath);
      if (preparedAudio.isTemporary) {
        _log('audio_normalized_for_whisper path=${preparedAudio.path}');
      }

      final whisper = Whisper(model: _model);
      final threads = _threadCountForModel(_model);
      final processors = _processorCountForModel(_model);
      final disableTimestamps = _disableTimestampsForModel(_model);
      _log(
        'transcribe_config threads=$threads processors=$processors no_timestamps=$disableTimestamps',
      );

      final result = await whisper.transcribe(
        transcribeRequest: TranscribeRequest(
          audio: preparedAudio.path,
          language: 'es',
          isTranslate: false,
          threads: threads,
          nProcessors: processors,
          isNoTimestamps: disableTimestamps,
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
    } on WavAudioPreparationException catch (e, st) {
      _log('audio_prepare_error: $e\n$st');
      throw TranscriptionException('Error en audio local: $e');
    } catch (e, st) {
      _log('transcribe_error: $e\n$st');
      throw TranscriptionException('Error en transcripcion local: $e');
    } finally {
      if (preparedAudio != null && preparedAudio.isTemporary) {
        final tempFile = File(preparedAudio.path);
        if (await tempFile.exists()) {
          await tempFile.delete();
        }
      }
    }
  }

  void _log(String message) {
    AppLogger.instance.info('LocalWhisper', message);
  }

  int _threadCountForModel(WhisperModel model) {
    return switch (model) {
      WhisperModel.tiny => 2,
      WhisperModel.base => 1,
      WhisperModel.small ||
      WhisperModel.medium ||
      WhisperModel.largeV1 ||
      WhisperModel.largeV2 =>
        1,
      WhisperModel.none => 1,
    };
  }

  int _processorCountForModel(WhisperModel model) {
    return switch (model) {
      WhisperModel.tiny => 1,
      WhisperModel.base => 1,
      WhisperModel.small ||
      WhisperModel.medium ||
      WhisperModel.largeV1 ||
      WhisperModel.largeV2 =>
        1,
      WhisperModel.none => 1,
    };
  }

  bool _disableTimestampsForModel(WhisperModel model) {
    return switch (model) {
      WhisperModel.tiny => false,
      WhisperModel.base => true,
      WhisperModel.small ||
      WhisperModel.medium ||
      WhisperModel.largeV1 ||
      WhisperModel.largeV2 =>
        true,
      WhisperModel.none => true,
    };
  }
}

class TranscriptionException implements Exception {
  TranscriptionException(this.message);
  final String message;
  @override
  String toString() => message;
}
