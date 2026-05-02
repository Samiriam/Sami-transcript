import 'dart:async';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:record/record.dart';
import 'package:uuid/uuid.dart';

class AudioRecorderService {
  AudioRecorderService(this._recorder);

  final AudioRecorder _recorder;
  final _uuid = const Uuid();

  bool _isRecording = false;
  String? _currentRecordingPath;
  DateTime? _recordingStartTime;

  bool get isRecording => _isRecording;
  String? get currentRecordingPath => _currentRecordingPath;

  Future<bool> hasPermission() async {
    return await _recorder.hasPermission();
  }

  Future<String?> start() async {
    if (_isRecording) return null;

    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) return null;

    final directory = await getApplicationDocumentsDirectory();
    final recordingsDirPath = p.join(directory.path, 'recordings');
    final recordingsDir = Directory(recordingsDirPath);
    if (!await recordingsDir.exists()) {
      await recordingsDir.create(recursive: true);
    }

    final fileName = '${_uuid.v4()}.wav';
    _currentRecordingPath = p.join(recordingsDirPath, fileName);

    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: 16000,
        numChannels: 1,
      ),
      path: _currentRecordingPath!,
    );

    _isRecording = true;
    _recordingStartTime = DateTime.now();
    return _currentRecordingPath;
  }

  Future<RecordingResult?> stop() async {
    if (!_isRecording) return null;

    final path = await _recorder.stop();
    _isRecording = false;

    final durationSeconds = _recordingStartTime != null
        ? DateTime.now().difference(_recordingStartTime!).inSeconds
        : 0;

    _recordingStartTime = null;

    if (path == null) return null;
    return RecordingResult(path: path, durationSeconds: durationSeconds);
  }

  Future<void> pause() async {
    if (_isRecording) {
      await _recorder.pause();
    }
  }

  Future<void> resume() async {
    if (_isRecording) {
      await _recorder.resume();
    }
  }

  Future<void> dispose() async {
    await _recorder.dispose();
  }
}

class RecordingResult {
  const RecordingResult({required this.path, required this.durationSeconds});

  final String path;
  final int durationSeconds;
}
