import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:whisper_flutter_new/whisper_flutter_new.dart';

import 'assemblyai_service.dart';
import 'local_whisper_service.dart';
import 'openai_service.dart';
import 'transcription_service.dart';

class TranscriptionConfig extends ChangeNotifier {
  static const _keyEngine = 'transcription_engine';
  static const _keyOpenAiKey = 'openai_api_key';
  static const _keyOpenAiBaseUrl = 'openai_base_url';
  static const _keyOpenAiModel = 'openai_model';
  static const _keyAssemblyAiKey = 'assemblyai_api_key';
  static const _keyWhisperModel = 'whisper_model';
  static const _keySummaryEngine = 'summary_engine';

  TranscriptionEngine _engine = TranscriptionEngine.local;
  String _openAiKey = '';
  String _openAiBaseUrl = 'https://api.openai.com/v1';
  String _openAiModel = 'whisper-1';
  String _assemblyAiKey = '';
  String _whisperModel = 'tiny';
  SummaryEngine _summaryEngine = SummaryEngine.local;

  TranscriptionEngine get engine => _engine;
  String get openAiKey => _openAiKey;
  String get openAiBaseUrl => _openAiBaseUrl;
  String get openAiModel => _openAiModel;
  String get assemblyAiKey => _assemblyAiKey;
  String get whisperModel => _whisperModel;
  SummaryEngine get summaryEngine => _summaryEngine;

  bool get isOpenAiConfigured => _openAiKey.isNotEmpty;
  bool get isAssemblyAiConfigured => _assemblyAiKey.isNotEmpty;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _engine = TranscriptionEngine.values.firstWhere(
      (e) => e.name == (prefs.getString(_keyEngine) ?? 'local'),
      orElse: () => TranscriptionEngine.local,
    );
    _openAiKey = prefs.getString(_keyOpenAiKey) ?? '';
    _openAiBaseUrl =
        prefs.getString(_keyOpenAiBaseUrl) ?? 'https://api.openai.com/v1';
    _openAiModel = prefs.getString(_keyOpenAiModel) ?? 'whisper-1';
    _assemblyAiKey = prefs.getString(_keyAssemblyAiKey) ?? '';
    _whisperModel = prefs.getString(_keyWhisperModel) ?? 'tiny';
    _summaryEngine = SummaryEngine.values.firstWhere(
      (e) => e.name == (prefs.getString(_keySummaryEngine) ?? 'local'),
      orElse: () => SummaryEngine.local,
    );
  }

  Future<void> setEngine(TranscriptionEngine engine) async {
    _engine = engine;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyEngine, engine.name);
    notifyListeners();
  }

  Future<void> setOpenAiConfig({
    required String apiKey,
    String? baseUrl,
    String? model,
  }) async {
    _openAiKey = apiKey;
    _openAiBaseUrl = baseUrl ?? _openAiBaseUrl;
    _openAiModel = model ?? _openAiModel;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyOpenAiKey, apiKey);
    if (baseUrl != null) await prefs.setString(_keyOpenAiBaseUrl, baseUrl);
    if (model != null) await prefs.setString(_keyOpenAiModel, model);
    notifyListeners();
  }

  Future<void> setAssemblyAiKey(String apiKey) async {
    _assemblyAiKey = apiKey;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyAssemblyAiKey, apiKey);
    notifyListeners();
  }

  Future<void> setWhisperModel(String model) async {
    _whisperModel = model;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyWhisperModel, model);
    notifyListeners();
  }

  Future<void> setSummaryEngine(SummaryEngine engine) async {
    _summaryEngine = engine;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keySummaryEngine, engine.name);
    notifyListeners();
  }

  TranscriptionService createService() {
    return switch (_engine) {
      TranscriptionEngine.local => LocalWhisperService(
          model: _parseWhisperModel(_whisperModel),
        ),
      TranscriptionEngine.openai => OpenAITranscriptionService(
          apiKey: _openAiKey,
          baseUrl: _openAiBaseUrl,
          model: _openAiModel,
        ),
      TranscriptionEngine.assemblyai => AssemblyAITranscriptionService(
          apiKey: _assemblyAiKey,
        ),
    };
  }

  SummaryService? createSummaryService() {
    return switch (_summaryEngine) {
      SummaryEngine.local => null,
      SummaryEngine.openai => _openAiKey.isEmpty
          ? null
          : OpenAISummaryService(
              apiKey: _openAiKey,
              baseUrl: _openAiBaseUrl,
            ),
      SummaryEngine.assemblyai => _assemblyAiKey.isEmpty
          ? null
          : AssemblyAISummaryService(
              apiKey: _assemblyAiKey,
            ),
    };
  }

  SummaryService? createTranscriptionEngineSummaryService() {
    return switch (_engine) {
      TranscriptionEngine.openai => OpenAISummaryService(
          apiKey: _openAiKey,
          baseUrl: _openAiBaseUrl,
        ),
      TranscriptionEngine.assemblyai => AssemblyAISummaryService(
          apiKey: _assemblyAiKey,
        ),
      TranscriptionEngine.local => null,
    };
  }

  WhisperModel _parseWhisperModel(String name) {
    return switch (name) {
      'tiny' => WhisperModel.tiny,
      'base' => WhisperModel.base,
      'small' => WhisperModel.small,
      'medium' => WhisperModel.medium,
      'large-v1' => WhisperModel.largeV1,
      'large-v2' => WhisperModel.largeV2,
      _ => WhisperModel.tiny,
    };
  }
}
