import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'transcription_service.dart';

class OpenAITranscriptionService implements TranscriptionService {
  OpenAITranscriptionService({
    required this.apiKey,
    this.baseUrl = 'https://api.openai.com/v1',
    this.model = 'whisper-1',
  });

  final String apiKey;
  final String baseUrl;
  final String model;

  @override
  TranscriptionEngine get engine => TranscriptionEngine.openai;

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
      throw Exception('OpenAI API error: ${response.statusCode} - $body');
    }

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
  });

  final String apiKey;
  final String baseUrl;
  final String model;

  @override
  Future<SummaryResult> summarize(String fullText) async {
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
            'content': 'Eres un editor experto de transcripciones en espanol. '
                'La transcripcion puede contener errores de reconocimiento. '
                'No inventes datos, pero corrige redaccion evidente, agrupa ideas y genera un resumen profesional. '
                'Usa esta estructura: 1) Resumen ejecutivo, 2) Temas tratados, 3) Acuerdos o decisiones, '
                '4) Acciones pendientes, 5) Riesgos o dudas. Si una seccion no aplica, escribe "No identificado".',
          },
          {
            'role': 'user',
            'content': 'Transcripcion a resumir y estructurar:\n\n$fullText'
          },
        ],
        'max_tokens': 1000,
        'temperature': 0.3,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('OpenAI API error: ${response.statusCode}');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final content = json['choices']?[0]?['message']?['content'] as String? ??
        'No se pudo generar el resumen.';

    return SummaryResult(summary: content, engine: TranscriptionEngine.openai);
  }
}
