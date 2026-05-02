import 'package:flutter_test/flutter_test.dart';
import 'package:sami_transcribe/core/services/post_processing_service.dart';
import 'package:sami_transcribe/core/services/transcription_service.dart';

void main() {
  late PostProcessingService service;

  setUp(() {
    service = PostProcessingService();
  });

  group('cleanFillerWords', () {
    test('removes common Spanish filler words', () {
      const input = 'ehm bueno hoy estuvimos hablando de este tema';
      final result = service.process(input, [],
          level: PostProcessingLevel.low);
      expect(result.text.toLowerCase(), contains('hoy estuvimos hablando'));
      expect(result.text, isNot(contains('ehm')));
    });

    test('removes multiple filler words', () {
      const input = 'este o sea digamos que la reunion fue productiva';
      final result = service.process(input, [],
          level: PostProcessingLevel.low);
      expect(result.text, isNot(contains('este')));
      expect(result.text, isNot(contains('o sea')));
      expect(result.text, isNot(contains('digamos')));
      expect(result.text, contains('reunion fue productiva'));
    });

    test('preserves meaningful content', () {
      const input = 'La reunion fue importante y productiva';
      final result = service.process(input, [],
          level: PostProcessingLevel.low);
      expect(result.text, contains('reunion fue importante'));
    });
  });

  group('polishSentences', () {
    test('capitalizes after period', () {
      const input = 'hola. esto es una prueba. otra frase.';
      final result = service.process(input, [],
          level: PostProcessingLevel.low);
      expect(result.text, contains('Hola'));
      expect(result.text, contains('Esto es'));
    });

    test('removes double commas', () {
      const input = 'el proyecto,, avanzo bien';
      final result = service.process(input, [],
          level: PostProcessingLevel.low);
      expect(result.text, isNot(contains(',,')));
    });

    test('capitalizes first letter', () {
      const input = 'la reunion empezo a las tres';
      final result = service.process(input, [],
          level: PostProcessingLevel.low);
      expect(result.text, startsWith('L'));
    });
  });

  group('normalizeWhitespace', () {
    test('collapses multiple spaces', () {
      const input = 'texto   con    espacios   multiples';
      final result = service.process(input, [],
          level: PostProcessingLevel.low);
      expect(result.text, isNot(contains('  ')));
    });

    test('fixes spaces before punctuation', () {
      const input = 'hola , mundo .';
      final result = service.process(input, [],
          level: PostProcessingLevel.low);
      expect(result.text, contains('Hola, mundo.'));
    });
  });

  group('mergeAdjacentSegments', () {
    test('merges short adjacent segments', () {
      final segments = [
        const TranscriptSegment(startTime: 0, endTime: 1, text: 'hola'),
        const TranscriptSegment(startTime: 1.1, endTime: 2, text: 'buenos'),
        const TranscriptSegment(
            startTime: 2.2, endTime: 5, text: 'una frase mas larga para conservar'),
      ];
      final result = service.process('', segments,
          level: PostProcessingLevel.medium);
      expect(result.segments.length, lessThan(segments.length));
    });

    test('preserves long segments', () {
      final segments = [
        const TranscriptSegment(
            startTime: 0,
            endTime: 5,
            text: 'Esta es una frase bastante larga que no deberia fusionarse'),
        const TranscriptSegment(
            startTime: 5.5,
            endTime: 10,
            text: 'Y esta otra frase tambien es suficientemente larga por si sola'),
      ];
      final result = service.process('', segments,
          level: PostProcessingLevel.medium);
      expect(result.segments.length, equals(2));
    });
  });

  group('levels', () {
    test('none returns original text', () {
      const input = 'ehm bueno texto   sucio ,, prueba';
      final result = service.process(input, [],
          level: PostProcessingLevel.none);
      expect(result.text, equals(input));
    });

    test('low applies basic cleanup', () {
      const input = 'ehm bueno la reunion fue bien';
      final result = service.process(input, [],
          level: PostProcessingLevel.low);
      expect(result.text, isNot(contains('ehm')));
      expect(result.elapsedMs, greaterThanOrEqualTo(0));
    });

    test('high applies all processing', () {
      const input = 'ehm bueno. esto es una prueba. (aclaracion)';
      final result = service.process(input, [],
          level: PostProcessingLevel.high);
      expect(result.text, isNot(contains('ehm')));
      expect(result.elapsedMs, greaterThanOrEqualTo(0));
    });
  });

  group('empty and edge cases', () {
    test('empty text returns empty', () {
      final result =
          service.process('', [], level: PostProcessingLevel.medium);
      expect(result.text, isEmpty);
    });

    test('whitespace only text gets trimmed', () {
      final result = service.process(
          '   ', [], level: PostProcessingLevel.medium);
      expect(result.text.trim(), isEmpty);
    });

    test('single segment is not modified', () {
      final segments = [
        const TranscriptSegment(
            startTime: 0, endTime: 5, text: 'Frase unica'),
      ];
      final result = service.process('Frase unica', segments,
          level: PostProcessingLevel.medium);
      expect(result.segments.length, equals(1));
    });
  });
}
