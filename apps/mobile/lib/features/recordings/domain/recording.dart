enum RecordingStatus { idle, recording, saved, transcribing, done, failed }

enum RecordingSource { app, import }

class Recording {
  const Recording({
    required this.id,
    required this.title,
    required this.audioPath,
    required this.durationSeconds,
    required this.createdAt,
    required this.status,
    this.source = RecordingSource.app,
    this.updatedAt,
  });

  final String id;
  final String title;
  final String audioPath;
  final int durationSeconds;
  final RecordingSource source;
  final RecordingStatus status;
  final DateTime createdAt;
  final DateTime? updatedAt;

  String get formattedDuration {
    final hours = durationSeconds ~/ 3600;
    final minutes = (durationSeconds % 3600) ~/ 60;
    final seconds = durationSeconds % 60;
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Recording copyWith({
    String? title,
    String? audioPath,
    int? durationSeconds,
    RecordingSource? source,
    RecordingStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Recording(
      id: id,
      title: title ?? this.title,
      audioPath: audioPath ?? this.audioPath,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      source: source ?? this.source,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
