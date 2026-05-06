import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'audio_chunker_service.dart';
import 'transcription_service.dart';

class OpenAITranscriptionService implements TranscriptionService {
  OpenAITranscriptionService({
    required this.apiKey,
    this.baseUrl = 'https://api.openai.com/v1',
    this.model = 'whisper-1',
    this.enableChunking = false,
    this.engineType = TranscriptionEngine.openai,
  });

  final String apiKey;
  final String baseUrl;
  final String model;
  final bool enableChunking;
  final TranscriptionEngine engineType;

  static const int maxGroqFileBytes = 25 * 1024 * 1024;

  @override
  TranscriptionEngine get engine => engineType;

  @override
  Future<bool> isAvailable() async {
    return apiKey.isNotEmpty;
  }

  @override
  Future<TranscriptionResult> transcribe(String audioPath) async {
    final file = File(audioPath);
    if (!await file.exists()) {
      throw Exception('Audio file not found: $audioPath');
    }

    if (enableChunking) {
      final fileSize = await file.length();
      if (fileSize > maxGroqFileBytes) {
        return _transcribeWithChunking(audioPath);
      }
    }

    return _transcribeSingle(audioPath);
  }

  Future<TranscriptionResult> _transcribeSingle(String audioPath) async {
    final uri = Uri.parse('$baseUrl/audio/transcriptions');
    final request = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] = 'Bearer $apiKey'
      ..fields['model'] = model
      ..fields['language'] = 'es'
      ..fields['response_format'] = 'verbose_json'
      ..files.add(await http.MultipartFile.fromPath('file', audioPath));

    final response = await request.send();
    final body = await response.stream.bytesToString();

    if (response.statusCode != 200) {
      throw Exception('API error: ${response.statusCode} - $body');
    }

    return _parseResponse(body);
  }

  Future<TranscriptionResult> _transcribeWithChunking(String audioPath) async {
    final chunker = AudioChunkerService();
    final chunkResult = await chunker.prepareForUploadWithConversion(
      audioPath,
      maxBytes: maxGroqFileBytes,
    );

    try {
      if (!chunkResult.isChunked) {
        return _transcribeSingle(audioPath);
      }

      final allText = StringBuffer();
      final allSegments = <TranscriptSegment>[];
      double timeOffset = 0;

      for (var i = 0; i < chunkResult.chunks.length; i++) {
        final chunkPath = chunkResult.chunks[i];
        final result = await _transcribeSingle(chunkPath);

        if (i == 0) {
          allText.write(result.text);
        } else {
          final overlapText = _findOverlapSuffix(
            allText.toString(),
            result.text,
          );
          if (overlapText.isNotEmpty) {
            allText.write(result.text.substring(overlapText.length));
          } else {
            allText.write(' ${result.text}');
          }
        }

        for (final seg in result.segments) {
          allSegments.add(TranscriptSegment(
            startTime: seg.startTime + timeOffset,
            endTime: seg.endTime + timeOffset,
            text: seg.text,
            speaker: seg.speaker,
          ));
        }

        timeOffset += result.durationSeconds ?? 0;
      }

      return TranscriptionResult(
        text: allText.toString(),
        engine: engine,
        language: 'es',
        segments: allSegments,
        durationSeconds: timeOffset,
      );
    } finally {
      await chunker.cleanup(chunkResult.tempFiles);
    }
  }

  String _findOverlapSuffix(String previousText, String currentText) {
    final prevWords = previousText.split(RegExp(r'\s+'));
    final currWords = currentText.split(RegExp(r'\s+'));

    if (prevWords.isEmpty || currWords.isEmpty) return '';

    var matchLen = 0;
    final maxCheck = prevWords.length.clamp(0, 30);

    for (var len = 1; len <= maxCheck && len <= currWords.length; len++) {
      final prevSlice = prevWords.sublist(prevWords.length - len);
      final currSlice = currWords.sublist(0, len);
      var match = true;
      for (var j = 0; j < len; j++) {
        if (prevSlice[j].toLowerCase().replaceAll(RegExp(r'[.,!?;:]'), '') !=
            currSlice[j].toLowerCase().replaceAll(RegExp(r'[.,!?;:]'), '')) {
          match = false;
          break;
        }
      }
      if (match) matchLen = len;
    }

    if (matchLen == 0) return '';
    return currWords.sublist(0, matchLen).join(' ');
  }

  TranscriptionResult _parseResponse(String body) {
    final json = jsonDecode(body) as Map<String, dynamic>;
    final segments = <TranscriptSegment>[];

    if (json['segments'] != null) {
      for (final seg in json['segments'] as List) {
        segments.add(
          TranscriptSegment(
            startTime: (seg['start'] as num).toDouble(),
            endTime: (seg['end'] as num).toDouble(),
            text: seg['text'] as String? ?? '',
          ),
        );
      }
    }

    return TranscriptionResult(
      text: json['text'] as String? ?? '',
      engine: engine,
      language: json['language'] as String? ?? 'es',
      segments: segments,
      durationSeconds: (json['duration'] as num?)?.toDouble(),
    );
  }
}

class OpenAISummaryService implements SummaryService {
  OpenAISummaryService({
    required this.apiKey,
    this.baseUrl = 'https://api.openai.com/v1',
    this.model = 'gpt-4o-mini',
    this.engineType = TranscriptionEngine.openai,
  });

  final String apiKey;
  final String baseUrl;
  final String model;
  final TranscriptionEngine engineType;

  static const _meetingSystemPrompt =
      'Eres un secretario ejecutivo experto en reuniones de trabajo. '
      'Recibiras la transcripcion de una reunion que puede contener errores de reconocimiento de voz. '
      'Tu trabajo es:\n'
      '1. Corregir errores evidentes de transcripcion preservando el significado.\n'
      '2. Identificar los temas principales tratados.\n'
      '3. Extraer acuerdos, decisiones y compromisos concretos.\n'
      '4. Listar acciones pendientes indicando responsable si se menciona.\n'
      '5. Senalar riesgos, dudas o puntos sin resolver.\n\n'
      'Usa esta estructura:\n'
      '## Resumen ejecutivo\n(2-3 frases con el objetivo y resultado general de la reunion)\n\n'
      '## Temas tratados\n- Tema 1: descripcion breve\n- Tema 2: ...\n\n'
      '## Acuerdos y decisiones\n- Acuerdo 1\n- Acuerdo 2\n(si no hay, escribir "Sin acuerdos formales identificados")\n\n'
      '## Acciones pendientes\n- [ ] Accion 1 (responsable, si aplica)\n- [ ] Accion 2\n(si no hay, escribir "Sin acciones pendientes explicitas")\n\n'
      '## Riesgos y dudas\n- Riesgo o duda identificada\n(si no hay, escribir "Sin riesgos evidentes")\n\n'
      'No inventes informacion que no este en la transcripcion. Si algo es ambiguo, indicalo.';

  static const _notesSystemPrompt =
      'Eres un asistente academico experto en organizar apuntes y notas de estudio. '
      'Recibiras la transcripcion de una nota de voz o clase que puede contener errores de reconocimiento de voz. '
      'Tu trabajo es:\n'
      '1. Corregir errores evidentes de transcripcion preservando el significado.\n'
      '2. Organizar el contenido en temas y subtemas logicos.\n'
      '3. Identificar conceptos clave, definiciones y formulas si las hay.\n'
      '4. Extraer ejemplos mencionados.\n'
      '5. Generar preguntas de repaso basadas en el contenido.\n\n'
      'Usa esta estructura:\n'
      '## Tema principal\n(1-2 frases describiendo el tema general)\n\n'
      '## Conceptos clave\n- **Concepto 1**: definicion o explicacion breve\n- **Concepto 2**: ...\n\n'
      '## Desarrollo\n(organizacion del contenido en subtemas con explicaciones claras)\n\n'
      '## Ejemplos\n- Ejemplo 1\n- Ejemplo 2\n(si no hay, escribir "Sin ejemplos explicitos")\n\n'
      '## Preguntas de repaso\n1. Pregunta 1\n2. Pregunta 2\n3. Pregunta 3\n\n'
      'No inventes informacion que no este en la transcripcion. Si algo es ambiguo, indicalo.';

  @override
  Future<SummaryResult> summarize(String fullText, {SummaryMode mode = SummaryMode.meeting}) async {
    final systemPrompt = mode == SummaryMode.meeting
        ? _meetingSystemPrompt
        : _notesSystemPrompt;

    final modeLabel = mode == SummaryMode.meeting ? 'reunion' : 'apuntes';
    final uri = Uri.parse('$baseUrl/chat/completions');
    final response = await http.post(
      uri,
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': model,
        'messages': [
          {
            'role': 'system',
            'content': systemPrompt,
          },
          {
            'role': 'user',
            'content': 'Transcripcion de $modeLabel a resumir y estructurar:\n\n$fullText'
          },
        ],
        'max_tokens': 1500,
        'temperature': 0.3,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('OpenAI API error: ${response.statusCode}');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final content = json['choices']?[0]?['message']?['content'] as String? ??
        'No se pudo generar el resumen.';

    return SummaryResult(summary: content, engine: engineType);
  }
}
