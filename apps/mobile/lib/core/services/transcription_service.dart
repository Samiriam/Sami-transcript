enum TranscriptionEngine { local, openai, groq, assemblyai }

enum SummaryEngine { local, openai, groq, assemblyai }

enum SummaryMode { meeting, notes }

class TranscriptionResult {
  const TranscriptionResult({
    required this.text,
    required this.engine,
    required this.language,
    this.segments = const [],
    this.durationSeconds,
  });

  final String text;
  final TranscriptionEngine engine;
  final String language;
  final List<TranscriptSegment> segments;
  final double? durationSeconds;
}

class TranscriptSegment {
  const TranscriptSegment({
    required this.startTime,
    required this.endTime,
    required this.text,
    this.speaker,
  });

  final double startTime;
  final double endTime;
  final String text;
  final String? speaker;
}

abstract class TranscriptionService {
  TranscriptionEngine get engine;

  Future<TranscriptionResult> transcribe(String audioPath);

  Future<bool> isAvailable();
}

class SummaryResult {
  const SummaryResult({required this.summary, required this.engine});

  final String summary;
  final TranscriptionEngine engine;
}

abstract class SummaryService {
  Future<SummaryResult> summarize(String fullText, {SummaryMode mode});
}
