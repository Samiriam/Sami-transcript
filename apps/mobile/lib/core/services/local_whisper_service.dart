import 'dart:io';

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
      final directory = Platform.isAndroid
          ? await getApplicationSupportDirectory()
          : await getLibraryDirectory();
      final modelFile = File(_model.getPath(directory.path));
      return modelFile.existsSync();
    } catch (_) {
      return false;
    }
  }

  @override
  Future<TranscriptionResult> transcribe(String audioPath) async {
    try {
      final whisper = Whisper(model: _model);

      final result = await whisper.transcribe(
        transcribeRequest: TranscribeRequest(
          audio: audioPath,
          language: 'es',
          isTranslate: false,
        ),
      );

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
    } catch (e) {
      throw TranscriptionException('Error en transcripcion local: $e');
    }
  }
}

class TranscriptionException implements Exception {
  TranscriptionException(this.message);
  final String message;
  @override
  String toString() => message;
}
