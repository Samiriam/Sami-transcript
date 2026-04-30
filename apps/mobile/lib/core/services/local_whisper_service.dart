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
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<TranscriptionResult> transcribe(String audioPath) async {
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
  }
}
