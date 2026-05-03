import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'transcription_service.dart';

class AssemblyAITranscriptionService implements TranscriptionService {
  AssemblyAITranscriptionService({
    required this.apiKey,
    this.baseUrl = 'https://api.assemblyai.com/v2',
  });

  final String apiKey;
  final String baseUrl;

  @override
  TranscriptionEngine get engine => TranscriptionEngine.assemblyai;

  @override
  Future<bool> isAvailable() async {
    return apiKey.isNotEmpty;
  }

  @override
  Future<TranscriptionResult> transcribe(String audioPath) async {
    final uploadUrl = await _uploadAudio(audioPath);
    final transcriptId = await _submitTranscription(uploadUrl);
    final result = await _pollResult(transcriptId);
    return result;
  }

  Future<String> _uploadAudio(String audioPath) async {
    final file = File(audioPath);
    if (!await file.exists()) {
      throw Exception('Audio file not found: $audioPath');
    }

    final uri = Uri.parse('$baseUrl/upload');
    final request = http.MultipartRequest('POST', uri)
      ..headers['authorization'] = apiKey
      ..files.add(await http.MultipartFile.fromPath('file', audioPath));

    final response = await request.send();
    final body = await response.stream.bytesToString();

    if (response.statusCode != 200) {
      throw Exception('AssemblyAI upload error: ${response.statusCode}');
    }

    return jsonDecode(body)['upload_url'] as String;
  }

  Future<String> _submitTranscription(String audioUrl) async {
    final uri = Uri.parse('$baseUrl/transcript');
    final response = await http.post(
      uri,
      headers: {
        'authorization': apiKey,
        'content-type': 'application/json',
      },
      body: jsonEncode({
        'audio_url': audioUrl,
        'language_code': 'es',
        'speaker_labels': true,
        'punctuate': true,
        'format_text': true,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('AssemblyAI submit error: ${response.statusCode}');
    }

    return jsonDecode(response.body)['id'] as String;
  }

  Future<TranscriptionResult> _pollResult(String transcriptId) async {
    final uri = Uri.parse('$baseUrl/transcript/$transcriptId');

    for (var i = 0; i < 120; i++) {
      final response = await http.get(uri, headers: {'authorization': apiKey});

      if (response.statusCode != 200) {
        throw Exception('AssemblyAI poll error: ${response.statusCode}');
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final status = json['status'] as String;

      if (status == 'completed') {
        final segments = <TranscriptSegment>[];
        final utterances = json['utterances'] as List?;

        if (utterances != null) {
          for (final u in utterances) {
            segments.add(
              TranscriptSegment(
                startTime: ((u['start'] as num).toDouble()) / 1000.0,
                endTime: ((u['end'] as num).toDouble()) / 1000.0,
                text: u['text'] as String? ?? '',
                speaker: u['speaker'] as String?,
              ),
            );
          }
        }

        return TranscriptionResult(
          text: json['text'] as String? ?? '',
          engine: engine,
          language: json['language_code'] as String? ?? 'es',
          segments: segments,
          durationSeconds: (json['audio_duration'] as num?)?.toDouble(),
        );
      }

      if (status == 'error') {
        throw Exception('AssemblyAI transcription failed: ${json['error']}');
      }

      await Future.delayed(const Duration(seconds: 3));
    }

    throw Exception('AssemblyAI transcription timeout');
  }
}

class AssemblyAISummaryService implements SummaryService {
  AssemblyAISummaryService(
      {required this.apiKey, this.baseUrl = 'https://api.assemblyai.com/v2'});

  final String apiKey;
  final String baseUrl;

  @override
  Future<SummaryResult> summarize(String fullText, {SummaryMode mode = SummaryMode.meeting}) async {
    final uri = Uri.parse('$baseUrl/lemlist/summarize');
    final response = await http.post(
      uri,
      headers: {
        'authorization': apiKey,
        'content-type': 'application/json',
      },
      body: jsonEncode({
        'text': fullText,
        'summary_type': 'bullets',
        'summary_length': 'medium',
      }),
    );

    if (response.statusCode != 200) {
      final fallback = _localSummary(fullText, mode: mode);
      return SummaryResult(
          summary: fallback, engine: TranscriptionEngine.assemblyai);
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return SummaryResult(
      summary: json['summary'] as String? ?? 'No se pudo generar resumen.',
      engine: TranscriptionEngine.assemblyai,
    );
  }

  String _localSummary(String text, {SummaryMode mode = SummaryMode.meeting}) {
    final sentences = text
        .split(RegExp(r'[.!?]+'))
        .where((s) => s.trim().isNotEmpty)
        .toList();
    if (sentences.length <= 3) return text;

    final buffer = StringBuffer();
    if (mode == SummaryMode.meeting) {
      buffer.writeln('Resumen de reunion (extractivo)');
      buffer.writeln(sentences.take(5).join('. '));
    } else {
      buffer.writeln('Apuntes (extractivo)');
      buffer.writeln(sentences.take(5).join('. '));
    }
    return '$buffer.';
  }
}
