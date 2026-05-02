import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';

import '../core/database/app_database.dart';
import '../core/services/audio_recorder_service.dart';
import '../core/services/theme_service.dart';
import '../core/services/transcription_config.dart';
import '../core/theme/app_theme.dart';
import '../features/recordings/data/sqlite_recording_repository.dart';
import '../features/recordings/data/recording_repository.dart';
import '../features/recordings/presentation/recording_provider.dart';
import '../features/recordings/presentation/transcription_provider.dart';
import '../features/recordings/presentation/home_screen.dart';

class SamiApp extends StatelessWidget {
  SamiApp({super.key});

  final _db = AppDatabase();
  final _themeService = ThemeService();
  final _transcriptionConfig = TranscriptionConfig();

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _themeService),
        Provider<RecordingRepository>(
          create: (_) => SqliteRecordingRepository(_db),
        ),
        Provider<AudioRecorderService>(
          create: (_) => AudioRecorderService(AudioRecorder()),
        ),
        ChangeNotifierProvider.value(value: _transcriptionConfig),
        ChangeNotifierProxyProvider<RecordingRepository, RecordingProvider>(
          create: (ctx) => RecordingProvider(
            ctx.read<RecordingRepository>(),
            ctx.read<AudioRecorderService>(),
          )..init(),
          update: (_, repo, prev) => prev ??
              RecordingProvider(repo, context.read<AudioRecorderService>())
            ..init(),
        ),
        ChangeNotifierProxyProvider<RecordingRepository, TranscriptionProvider>(
          create: (ctx) => TranscriptionProvider(
            ctx.read<RecordingRepository>(),
            _db,
            _transcriptionConfig,
          ),
          update: (_, repo, prev) =>
              prev ??
              TranscriptionProvider(
                repo,
                _db,
                _transcriptionConfig,
              ),
        ),
      ],
      child: Consumer<ThemeService>(
        builder: (context, themeService, _) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'Sami Transcribe',
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: themeService.mode,
            home: const HomeScreen(),
          );
        },
      ),
    );
  }
}
