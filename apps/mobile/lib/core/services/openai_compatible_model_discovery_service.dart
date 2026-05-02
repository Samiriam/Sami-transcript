import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

class OpenAiCompatiblePreset {
  const OpenAiCompatiblePreset({
    required this.id,
    required this.label,
    required this.baseUrl,
    required this.description,
    this.prioritizeFreeModels = false,
  });

  final String id;
  final String label;
  final String baseUrl;
  final String description;
  final bool prioritizeFreeModels;
}

class SummaryModelOption {
  const SummaryModelOption({
    required this.id,
    required this.displayName,
    required this.isFree,
  });

  final String id;
  final String displayName;
  final bool isFree;
}

class OpenAiCompatibleModelDiscoveryService {
  static const presets = [
    OpenAiCompatiblePreset(
      id: 'openai',
      label: 'OpenAI',
      baseUrl: 'https://api.openai.com/v1',
      description: 'API oficial OpenAI compatible.',
    ),
    OpenAiCompatiblePreset(
      id: 'openrouter',
      label: 'OpenRouter',
      baseUrl: 'https://openrouter.ai/api/v1',
      description: 'Compatible OpenAI; prioriza modelos gratuitos.',
      prioritizeFreeModels: true,
    ),
    OpenAiCompatiblePreset(
      id: 'custom',
      label: 'Personalizado',
      baseUrl: '',
      description: 'Servidor compatible OpenAI definido por el usuario.',
    ),
  ];

  Future<List<SummaryModelOption>> fetchModels({
    required String baseUrl,
    required String apiKey,
    bool prioritizeFreeModels = false,
  }) async {
    final normalizedBaseUrl = normalizeBaseUrl(baseUrl);
    if (apiKey.trim().isEmpty) {
      throw const ModelDiscoveryException('La API key no puede estar vacia.');
    }

    final uri = Uri.parse('$normalizedBaseUrl/models');
    http.Response response;
    try {
      response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer ${apiKey.trim()}',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 20));
    } on TimeoutException {
      throw const ModelDiscoveryException(
          'La validacion excedio el tiempo de espera.');
    } on SocketException catch (e) {
      throw ModelDiscoveryException(
          'No se pudo conectar al servidor: ${e.message}');
    } catch (e) {
      throw ModelDiscoveryException(
          'Fallo inesperado al consultar modelos: $e');
    }

    if (response.statusCode != 200) {
      final bodyPreview = response.body.length > 280
          ? '${response.body.substring(0, 280)}...'
          : response.body;
      throw ModelDiscoveryException(
        'La API respondio ${response.statusCode}. Detalle: $bodyPreview',
      );
    }

    final json = jsonDecode(response.body);
    if (json is! Map<String, dynamic> || json['data'] is! List) {
      throw const ModelDiscoveryException(
        'La respuesta del endpoint /models no tiene el formato esperado.',
      );
    }

    final items = <SummaryModelOption>[];
    for (final item in json['data'] as List) {
      if (item is! Map<String, dynamic>) continue;
      final id = item['id']?.toString().trim() ?? '';
      if (id.isEmpty) continue;
      final isFree = id.toLowerCase().contains(':free') ||
          id.toLowerCase().contains('/free');
      items.add(
        SummaryModelOption(
          id: id,
          displayName: isFree ? '$id (gratis)' : id,
          isFree: isFree,
        ),
      );
    }

    if (items.isEmpty) {
      throw const ModelDiscoveryException(
          'La API no devolvio modelos utilizables.');
    }

    items.sort((a, b) {
      if (prioritizeFreeModels && a.isFree != b.isFree) {
        return a.isFree ? -1 : 1;
      }
      return a.id.toLowerCase().compareTo(b.id.toLowerCase());
    });

    return items;
  }

  String normalizeBaseUrl(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      throw const ModelDiscoveryException('La URL base no puede estar vacia.');
    }
    final uri = Uri.tryParse(trimmed);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      throw const ModelDiscoveryException('La URL base no es valida.');
    }
    return trimmed.endsWith('/')
        ? trimmed.substring(0, trimmed.length - 1)
        : trimmed;
  }
}

class ModelDiscoveryException implements Exception {
  const ModelDiscoveryException(this.message);

  final String message;

  @override
  String toString() => message;
}
