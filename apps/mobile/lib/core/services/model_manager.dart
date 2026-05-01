import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:whisper_flutter_new/download_model.dart' show downloadModel;
import 'package:whisper_flutter_new/whisper_flutter_new.dart' show WhisperModel;

class ModelManager {
  static final Map<WhisperModel, int> _expectedSizes = {
    WhisperModel.tiny: 75 * 1024 * 1024,
    WhisperModel.base: 142 * 1024 * 1024,
    WhisperModel.small: 466 * 1024 * 1024,
    WhisperModel.medium: 1500 * 1024 * 1024,
    WhisperModel.largeV1: 2900 * 1024 * 1024,
    WhisperModel.largeV2: 2900 * 1024 * 1024,
  };

  Future<String> _modelDir() async {
    final directory = Platform.isAndroid
        ? await getApplicationSupportDirectory()
        : await getLibraryDirectory();
    return directory.path;
  }

  Future<bool> isAvailable(WhisperModel model) async {
    try {
      final dir = await _modelDir();
      final file = File(model.getPath(dir));
      if (!file.existsSync()) return false;
      final size = await file.length();
      final minSize = _expectedSizes[model] ?? 0;
      if (minSize > 0 && size < minSize ~/ 2) {
        _log('isAvailable: ${model.modelName} existe pero tamaño $size < ${minSize ~/ 2}, probablemente corrupto');
        return false;
      }
      _log('isAvailable: ${model.modelName} OK (size=$size)');
      return true;
    } catch (e) {
      _log('isAvailable error: $e');
      return false;
    }
  }

  Future<String> getModelPath(WhisperModel model) async {
    final dir = await _modelDir();
    return model.getPath(dir);
  }

  Future<void> ensureModel(
    WhisperModel model, {
    String? downloadHost,
    void Function(double progress)? onProgress,
  }) async {
    final available = await isAvailable(model);
    if (available) {
      _log('ensureModel: ${model.modelName} ya disponible');
      onProgress?.call(1.0);
      return;
    }

    _log('ensureModel: descargando ${model.modelName}...');
    onProgress?.call(0.1);

    final dir = await _modelDir();
    final dirPath = Directory(dir);
    if (!dirPath.existsSync()) {
      dirPath.createSync(recursive: true);
    }

    try {
      await downloadModel(
        model: model,
        destinationPath: dir,
        downloadHost: downloadHost,
      );
      _log('ensureModel: descarga completada ${model.modelName}');
    } catch (e) {
      _log('ensureModel: error descargando ${model.modelName}: $e');
      final filePath = model.getPath(dir);
      final file = File(filePath);
      if (file.existsSync()) {
        await file.delete();
        _log('ensureModel: archivo corrupto eliminado');
      }
      rethrow;
    }

    final verified = await isAvailable(model);
    if (!verified) {
      throw ModelManagerException('Modelo descargado pero verificacion fallida: ${model.modelName}');
    }

    onProgress?.call(1.0);
  }

  Future<void> deleteModel(WhisperModel model) async {
    final dir = await _modelDir();
    final file = File(model.getPath(dir));
    if (file.existsSync()) {
      await file.delete();
      _log('deleteModel: ${model.modelName} eliminado');
    }
  }

  Future<ModelInfo?> getModelInfo(WhisperModel model) async {
    final dir = await _modelDir();
    final file = File(model.getPath(dir));
    if (!file.existsSync()) return null;
    final stat = await file.stat();
    final size = await file.length();
    return ModelInfo(
      model: model,
      path: file.path,
      sizeBytes: size,
      lastModified: stat.modified,
    );
  }

  void _log(String message) {
    debugPrint('[ModelManager] $message');
  }
}

class ModelInfo {
  const ModelInfo({
    required this.model,
    required this.path,
    required this.sizeBytes,
    required this.lastModified,
  });

  final WhisperModel model;
  final String path;
  final int sizeBytes;
  final DateTime lastModified;

  String get sizeFormatted {
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class ModelManagerException implements Exception {
  ModelManagerException(this.message);
  final String message;
  @override
  String toString() => message;
}
