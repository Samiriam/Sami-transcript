import 'dart:async';

import 'package:flutter/foundation.dart';

import '../domain/recording.dart';
import '../data/recording_repository.dart';
import '../../../core/services/audio_recorder_service.dart';

class RecordingProvider extends ChangeNotifier {
  RecordingProvider(this._repository, this._recorderService);

  final RecordingRepository _repository;
  final AudioRecorderService _recorderService;

  List<Recording> _recordings = [];
  List<Recording> get recordings => _recordings;

  bool _isRecording = false;
  bool get isRecording => _isRecording;

  int _elapsedSeconds = 0;
  int get elapsedSeconds => _elapsedSeconds;
  String get formattedElapsed {
    final minutes = (_elapsedSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (_elapsedSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  String? _currentRecordingId;
  String? get currentRecordingId => _currentRecordingId;

  StreamSubscription<List<Recording>>? _subscription;
  Timer? _timer;

  void init() {
    _loadRecordings();
  }

  Future<void> _loadRecordings() async {
    _recordings = await _repository.list();
    notifyListeners();
  }

  Future<void> startRecording() async {
    final hasPermission = await _recorderService.hasPermission();
    if (!hasPermission) return;

    final path = await _recorderService.start();
    if (path == null) return;

    _isRecording = true;
    _elapsedSeconds = 0;
    _currentRecordingId = DateTime.now().millisecondsSinceEpoch.toString();

    final recording = Recording(
      id: _currentRecordingId!,
      title: 'Grabacion ${_recordings.length + 1}',
      audioPath: path,
      durationSeconds: 0,
      source: RecordingSource.app,
      status: RecordingStatus.recording,
      createdAt: DateTime.now(),
    );

    await _repository.save(recording);

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _elapsedSeconds++;
      notifyListeners();
    });

    notifyListeners();
  }

  Future<void> stopRecording() async {
    final result = await _recorderService.stop();
    _timer?.cancel();
    _timer = null;
    _isRecording = false;

    if (result != null && _currentRecordingId != null) {
      try {
        final existing = await _repository.getById(_currentRecordingId!);
        final updated = existing.copyWith(
          durationSeconds: result.durationSeconds,
          status: RecordingStatus.saved,
          updatedAt: DateTime.now(),
        );
        await _repository.update(updated);
      } catch (_) {}
    }

    _currentRecordingId = null;
    _elapsedSeconds = 0;
    await _loadRecordings();
    notifyListeners();
  }

  Future<void> deleteRecording(String id) async {
    await _repository.delete(id);
    await _loadRecordings();
  }

  Future<void> updateTitle(String id, String newTitle) async {
    final existing = await _repository.getById(id);
    final updated = existing.copyWith(
      title: newTitle,
      updatedAt: DateTime.now(),
    );
    await _repository.update(updated);
    await _loadRecordings();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _timer?.cancel();
    _recorderService.dispose();
    super.dispose();
  }
}
