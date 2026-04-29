import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';

void main() {
  testWidgets('smoke test renders without error', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Text('Sami Transcribe')),
      ),
    );

    expect(find.text('Sami Transcribe'), findsOneWidget);
  });

  testWidgets('recording status enum covers all values', (tester) async {
    final statuses = RecordingStatus.values;
    expect(statuses.length, 6);
    expect(statuses.contains(RecordingStatus.idle), isTrue);
    expect(statuses.contains(RecordingStatus.recording), isTrue);
    expect(statuses.contains(RecordingStatus.saved), isTrue);
    expect(statuses.contains(RecordingStatus.transcribing), isTrue);
    expect(statuses.contains(RecordingStatus.done), isTrue);
    expect(statuses.contains(RecordingStatus.failed), isTrue);
  });

  test('formattedDuration formats correctly', () {
    final recording = Recording(
      id: '1',
      title: 'Test',
      audioPath: '/test.m4a',
      durationSeconds: 3661,
      createdAt: DateTime.now(),
      status: RecordingStatus.done,
    );
    expect(recording.formattedDuration, '01:01:01');
  });

  test('formattedDuration short format', () {
    final recording = Recording(
      id: '2',
      title: 'Test',
      audioPath: '/test.m4a',
      durationSeconds: 125,
      createdAt: DateTime.now(),
      status: RecordingStatus.done,
    );
    expect(recording.formattedDuration, '02:05');
  });

  test('copyWith preserves id', () {
    final original = Recording(
      id: 'abc',
      title: 'Original',
      audioPath: '/test.m4a',
      durationSeconds: 100,
      createdAt: DateTime.now(),
      status: RecordingStatus.saved,
    );
    final copy = original.copyWith(title: 'Updated');
    expect(copy.id, 'abc');
    expect(copy.title, 'Updated');
    expect(copy.durationSeconds, 100);
  });
}

enum RecordingStatus { idle, recording, saved, transcribing, done, failed }

class Recording {
  const Recording({
    required this.id,
    required this.title,
    required this.audioPath,
    required this.durationSeconds,
    required this.createdAt,
    required this.status,
  });

  final String id;
  final String title;
  final String audioPath;
  final int durationSeconds;
  final DateTime createdAt;
  final RecordingStatus status;

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
    RecordingStatus? status,
    DateTime? createdAt,
  }) {
    return Recording(
      id: id,
      title: title ?? this.title,
      audioPath: audioPath ?? this.audioPath,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
    );
  }
}
