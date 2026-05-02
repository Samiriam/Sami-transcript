import 'transcription_service.dart';

enum PostProcessingLevel {
  none,
  low,
  medium,
  high,
}

class PostProcessingResult {
  const PostProcessingResult({
    required this.text,
    required this.segments,
    required this.level,
    required this.elapsedMs,
  });

  final String text;
  final List<TranscriptSegment> segments;
  final PostProcessingLevel level;
  final int elapsedMs;
}

class PostProcessingService {
  static const _fillerWordsEs = [
    'ehm', 'eh', 'em', 'um', 'uh', 'este', 'o sea', 'bueno,',
    'bueno', 'como decia', 'digamos', 'la verdad', 'tipo',
    'vla', 'mmm', 'hmm', 'ah', 'ehh', 'ehhm',
  ];

  static const _shortSentenceThreshold = 20;

  PostProcessingResult process(
    String rawText,
    List<TranscriptSegment> rawSegments, {
    PostProcessingLevel level = PostProcessingLevel.medium,
    bool preserveTimestamps = true,
  }) {
    if (level == PostProcessingLevel.none) {
      return PostProcessingResult(
        text: rawText,
        segments: rawSegments,
        level: level,
        elapsedMs: 0,
      );
    }

    final stopwatch = Stopwatch()..start();

    var text = rawText;
    var segments = List<TranscriptSegment>.from(rawSegments);

    if (text.trim().isNotEmpty) {
      text = _cleanFillerWords(text);
      text = _normalizeWhitespace(text);
      text = _polishSentences(text);
    }

    if (level == PostProcessingLevel.medium ||
        level == PostProcessingLevel.high) {
      if (preserveTimestamps && segments.isNotEmpty) {
        segments = _mergeAdjacentSegments(segments);
      }
      if (text.trim().isNotEmpty) {
        text = _joinShortSentences(text);
      }
    }

    if (level == PostProcessingLevel.high) {
      if (text.trim().isNotEmpty) {
        text = _reorderParentheticals(text);
        text = _capitalizeProperly(text);
      }
      if (preserveTimestamps && segments.isNotEmpty) {
        segments = _normalizeTimestamps(segments);
      }
    }

    if (text.trim().isNotEmpty) {
      text = _normalizeWhitespace(text);
    }

    stopwatch.stop();

    return PostProcessingResult(
      text: text,
      segments: segments,
      level: level,
      elapsedMs: stopwatch.elapsedMilliseconds,
    );
  }

  String _cleanFillerWords(String text) {
    var result = text;
    for (final filler in _fillerWordsEs) {
      final escaped = RegExp.escape(filler);
      final pattern = filler.endsWith(',')
          ? RegExp('\\b$escaped\\b\\s*', caseSensitive: false)
          : RegExp('\\b$escaped\\b[,.]?\\s*', caseSensitive: false);
      result = result.replaceAll(pattern, '');
    }
    return result;
  }

  String _normalizeWhitespace(String text) {
    return text
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAllMapped(
          RegExp(r'\s+([.,;:!?])'),
          (match) => match[1]!,
        )
        .replaceAll(RegExp(r'\.\.+'), '.')
        .trim();
  }

  String _polishSentences(String text) {
    var result = text;

    result = result.replaceAll(RegExp(r'\s*,\s*,\s*'), ', ');

    result = result.replaceAllMapped(
      RegExp(r'([.!?])\s*([a-záéíóúñü])'),
      (match) => '${match[1]} ${match[2]!.toUpperCase()}',
    );

    if (result.isNotEmpty && result[0] != result[0].toUpperCase()) {
      result = result[0].toUpperCase() + result.substring(1);
    }

    result = result.replaceAllMapped(
      RegExp(r'\b(y|o|pero|porque|aunque|si|cuando|que|e|u)\s+([a-záéíóúñü])'),
      (match) => '${match[1]} ${match[2]}',
    );

    return result;
  }

  List<TranscriptSegment> _mergeAdjacentSegments(
      List<TranscriptSegment> segments) {
    if (segments.length <= 1) return segments;

    final merged = <TranscriptSegment>[];
    var current = segments.first;

    for (var i = 1; i < segments.length; i++) {
      final next = segments[i];
      final gap = next.startTime - current.endTime;
      final currentLen = current.text.trim().length;
      final nextLen = next.text.trim().length;

      if (gap < 0.5 && (currentLen < _shortSentenceThreshold || nextLen < _shortSentenceThreshold)) {
        current = TranscriptSegment(
          startTime: current.startTime,
          endTime: next.endTime,
          text: '${current.text.trim()} ${next.text.trim()}',
          speaker: current.speaker ?? next.speaker,
        );
      } else {
        merged.add(current);
        current = next;
      }
    }
    merged.add(current);

    return merged;
  }

  String _joinShortSentences(String text) {
    final sentences = text.split(RegExp(r'(?<=[.!?])\s+'));
    final result = <String>[];
    var buffer = StringBuffer();

    for (final sentence in sentences) {
      final trimmed = sentence.trim();
      if (trimmed.isEmpty) continue;

      if (buffer.isNotEmpty) {
        buffer.write(' $trimmed');
        if (buffer.length >= _shortSentenceThreshold) {
          result.add(buffer.toString());
          buffer.clear();
        }
      } else if (trimmed.length < _shortSentenceThreshold) {
        buffer.write(trimmed);
      } else {
        result.add(trimmed);
      }
    }

    if (buffer.isNotEmpty) {
      result.add(buffer.toString());
    }

    return result.join(' ');
  }

  List<TranscriptSegment> _normalizeTimestamps(List<TranscriptSegment> segments) {
    if (segments.isEmpty) return segments;

    final normalized = <TranscriptSegment>[];
    for (var i = 0; i < segments.length; i++) {
      final seg = segments[i];
      final start = i == 0
          ? seg.startTime
          : seg.startTime < normalized.last.endTime
              ? normalized.last.endTime
              : seg.startTime;
      final end = seg.endTime < start ? start + 1.0 : seg.endTime;

      normalized.add(TranscriptSegment(
        startTime: start,
        endTime: end,
        text: seg.text,
        speaker: seg.speaker,
      ));
    }

    return normalized;
  }

  String _reorderParentheticals(String text) {
    return text.replaceAllMapped(
      RegExp(r'\s*\(([^)]+)\)\s*'),
      (match) => '. (${match[1]})',
    );
  }

  String _capitalizeProperly(String text) {
    var result = text;

    result = result.replaceAllMapped(
      RegExp(r'\.\s+([a-záéíóúñü])'),
      (match) => '. ${match[1]!.toUpperCase()}',
    );

    result = result.replaceAllMapped(
      RegExp(r'^([a-záéíóúñü])'),
      (match) => match[1]!.toUpperCase(),
    );

    return result;
  }
}
