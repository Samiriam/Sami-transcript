import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:whisper_flutter_new/whisper_flutter_new.dart';

import 'assemblyai_service.dart';
import 'local_whisper_service.dart';
import 'openai_compatible_model_discovery_service.dart';
import 'openai_service.dart';
import 'post_processing_service.dart';
import 'transcription_service.dart';

class TranscriptionConfig extends ChangeNotifier {
  static const _keyEngine = 'transcription_engine';
  static const _keyOpenAiKey = 'openai_api_key';
  static const _keyOpenAiBaseUrl = 'openai_base_url';
  static const _keyOpenAiModel = 'openai_model';
  static const _keyGroqKey = 'groq_api_key';
  static const _keyGroqModel = 'groq_model';
  static const _keyAssemblyAiKey = 'assemblyai_api_key';
  static const _keyWhisperModel = 'whisper_model';
  static const _keySummaryEngine = 'summary_engine';
  static const _keySummaryMode = 'summary_mode';
  static const _keySummaryOpenAiKey = 'summary_openai_api_key';
  static const _keySummaryOpenAiBaseUrl = 'summary_openai_base_url';
  static const _keySummaryOpenAiModel = 'summary_openai_model';
  static const _keySummaryAssemblyAiKey = 'summary_assemblyai_api_key';
  static const _keySummaryOpenAiPresetId = 'summary_openai_preset_id';
  static const _keyPostProcessingEnabled = 'post_processing_enabled';
  static const _keyPostProcessingLevel = 'post_processing_level';

  static const groqModels = [
    'whisper-large-v3-turbo',
    'whisper-large-v3',
    'distil-whisper-large-v3-en',
  ];

  TranscriptionEngine _engine = TranscriptionEngine.local;
  String _openAiKey = '';
  String _openAiBaseUrl = 'https://api.openai.com/v1';
  String _openAiModel = 'whisper-1';
  String _groqKey = '';
  String _groqModel = 'whisper-large-v3-turbo';
  String _assemblyAiKey = '';
  String _whisperModel = 'tiny';
  SummaryEngine _summaryEngine = SummaryEngine.local;
  SummaryMode _summaryMode = SummaryMode.meeting;
  String _summaryOpenAiKey = '';
  String _summaryOpenAiBaseUrl = 'https://api.openai.com/v1';
  String _summaryOpenAiModel = 'gpt-4o-mini';
  String _summaryAssemblyAiKey = '';
  String _summaryOpenAiPresetId = 'openai';
  bool _postProcessingEnabled = true;
  PostProcessingLevel _postProcessingLevel = PostProcessingLevel.medium;

  TranscriptionEngine get engine => _engine;
  String get openAiKey => _openAiKey;
  String get openAiBaseUrl => _openAiBaseUrl;
  String get openAiModel => _openAiModel;
  String get groqKey => _groqKey;
  String get groqModel => _groqModel;
  String get assemblyAiKey => _assemblyAiKey;
  String get whisperModel => _whisperModel;
  SummaryEngine get summaryEngine => _summaryEngine;
  SummaryMode get summaryMode => _summaryMode;
  String get summaryOpenAiKey => _summaryOpenAiKey;
  String get summaryOpenAiBaseUrl => _summaryOpenAiBaseUrl;
  String get summaryOpenAiModel => _summaryOpenAiModel;
  String get summaryAssemblyAiKey => _summaryAssemblyAiKey;
  String get summaryOpenAiPresetId => _summaryOpenAiPresetId;
  bool get postProcessingEnabled => _postProcessingEnabled;
  PostProcessingLevel get postProcessingLevel => _postProcessingLevel;
  List<OpenAiCompatiblePreset> get summaryOpenAiPresets =>
      OpenAiCompatibleModelDiscoveryService.presets;
  OpenAiCompatiblePreset get selectedSummaryOpenAiPreset =>
      summaryOpenAiPresets.firstWhere(
        (preset) => preset.id == _summaryOpenAiPresetId,
        orElse: () => OpenAiCompatibleModelDiscoveryService.presets.first,
      );

  bool get isOpenAiConfigured => _openAiKey.isNotEmpty;
  bool get isGroqConfigured => _groqKey.isNotEmpty;
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
    _groqKey = prefs.getString(_keyGroqKey) ?? '';
    _groqModel = prefs.getString(_keyGroqModel) ?? 'whisper-large-v3-turbo';
    _assemblyAiKey = prefs.getString(_keyAssemblyAiKey) ?? '';
    _whisperModel = prefs.getString(_keyWhisperModel) ?? 'tiny';
    _summaryEngine = SummaryEngine.values.firstWhere(
      (e) => e.name == (prefs.getString(_keySummaryEngine) ?? 'local'),
      orElse: () => SummaryEngine.local,
    );
    _summaryMode = SummaryMode.values.firstWhere(
      (e) => e.name == (prefs.getString(_keySummaryMode) ?? 'meeting'),
      orElse: () => SummaryMode.meeting,
    );
    _summaryOpenAiKey = prefs.getString(_keySummaryOpenAiKey) ?? '';
    _summaryOpenAiBaseUrl = prefs.getString(_keySummaryOpenAiBaseUrl) ??
        'https://api.openai.com/v1';
    _summaryOpenAiModel =
        prefs.getString(_keySummaryOpenAiModel) ?? 'gpt-4o-mini';
    _summaryAssemblyAiKey = prefs.getString(_keySummaryAssemblyAiKey) ?? '';
    _summaryOpenAiPresetId =
        prefs.getString(_keySummaryOpenAiPresetId) ?? 'openai';
    _postProcessingEnabled =
        prefs.getBool(_keyPostProcessingEnabled) ?? true;
    _postProcessingLevel = PostProcessingLevel.values.firstWhere(
      (e) => e.name == (prefs.getString(_keyPostProcessingLevel) ?? 'medium'),
      orElse: () => PostProcessingLevel.medium,
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

  Future<void> setGroqConfig({
    required String apiKey,
    String? model,
  }) async {
    _groqKey = apiKey;
    _groqModel = model ?? _groqModel;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyGroqKey, apiKey);
    if (model != null) await prefs.setString(_keyGroqModel, model);
    notifyListeners();
  }

  Future<void> setSummaryMode(SummaryMode mode) async {
    _summaryMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keySummaryMode, mode.name);
    notifyListeners();
  }

  Future<void> setWhisperModel(String model) async {
    _whisperModel = model;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyWhisperModel, _whisperModel);
    notifyListeners();
  }

  Future<void> setSummaryEngine(SummaryEngine engine) async {
    _summaryEngine = engine;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keySummaryEngine, engine.name);
    notifyListeners();
  }

  Future<void> setSummaryOpenAiConfig({
    required String apiKey,
    String? baseUrl,
    String? model,
    String? presetId,
  }) async {
    _summaryOpenAiKey = apiKey;
    _summaryOpenAiBaseUrl = baseUrl ?? _summaryOpenAiBaseUrl;
    _summaryOpenAiModel = model ?? _summaryOpenAiModel;
    _summaryOpenAiPresetId = presetId ?? _summaryOpenAiPresetId;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keySummaryOpenAiKey, apiKey);
    if (baseUrl != null) {
      await prefs.setString(_keySummaryOpenAiBaseUrl, baseUrl);
    }
    if (model != null) {
      await prefs.setString(_keySummaryOpenAiModel, model);
    }
    if (presetId != null) {
      await prefs.setString(_keySummaryOpenAiPresetId, presetId);
    }
    notifyListeners();
  }

  Future<void> setSummaryAssemblyAiKey(String apiKey) async {
    _summaryAssemblyAiKey = apiKey;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keySummaryAssemblyAiKey, apiKey);
    notifyListeners();
  }

  Future<void> setPostProcessingEnabled(bool enabled) async {
    _postProcessingEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyPostProcessingEnabled, enabled);
    notifyListeners();
  }

  Future<void> setPostProcessingLevel(PostProcessingLevel level) async {
    _postProcessingLevel = level;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyPostProcessingLevel, level.name);
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
          engineType: TranscriptionEngine.openai,
        ),
      TranscriptionEngine.groq => OpenAITranscriptionService(
          apiKey: _groqKey,
          baseUrl: 'https://api.groq.com/openai/v1',
          model: _groqModel,
          enableChunking: true,
          engineType: TranscriptionEngine.groq,
        ),
      TranscriptionEngine.assemblyai => AssemblyAITranscriptionService(
          apiKey: _assemblyAiKey,
        ),
    };
  }

  TranscriptionService createFallbackService() {
    return LocalWhisperService(
      model: _parseWhisperModel(_whisperModel),
    );
  }

  bool get needsApiKeyFallback {
    return switch (_engine) {
      TranscriptionEngine.groq => _groqKey.isEmpty,
      TranscriptionEngine.openai => _openAiKey.isEmpty,
      TranscriptionEngine.assemblyai => _assemblyAiKey.isEmpty,
      TranscriptionEngine.local => false,
    };
  }

  SummaryService? createSummaryService() {
    return switch (_summaryEngine) {
      SummaryEngine.local => null,
      SummaryEngine.openai => _summaryOpenAiKey.isEmpty
          ? null
          : OpenAISummaryService(
              apiKey: _summaryOpenAiKey,
              baseUrl: _summaryOpenAiBaseUrl,
              model: _summaryOpenAiModel,
              engineType: TranscriptionEngine.openai,
            ),
      SummaryEngine.groq => _groqKey.isEmpty
          ? null
          : OpenAISummaryService(
              apiKey: _groqKey,
              baseUrl: 'https://api.groq.com/openai/v1',
              model: 'llama-3.3-70b-versatile',
              engineType: TranscriptionEngine.groq,
            ),
      SummaryEngine.assemblyai => _summaryAssemblyAiKey.isEmpty
          ? null
          : AssemblyAISummaryService(
              apiKey: _summaryAssemblyAiKey,
            ),
    };
  }

  SummaryService? createTranscriptionEngineSummaryService() {
    return switch (_engine) {
      TranscriptionEngine.openai => OpenAISummaryService(
          apiKey: _openAiKey,
          baseUrl: _openAiBaseUrl,
          engineType: TranscriptionEngine.openai,
        ),
      TranscriptionEngine.groq => OpenAISummaryService(
          apiKey: _groqKey,
          baseUrl: 'https://api.groq.com/openai/v1',
          model: 'llama-3.3-70b-versatile',
          engineType: TranscriptionEngine.groq,
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
