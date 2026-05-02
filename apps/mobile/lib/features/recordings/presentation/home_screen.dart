import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../domain/recording.dart';
import 'recording_provider.dart';
import 'recording_detail_screen.dart';
import 'widgets/recording_card.dart';
import '../../../core/services/theme_service.dart';
import '../../../core/widgets/gothic_logo.dart';
import 'settings_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const GothicLogo(size: 28, showLabel: false),
        actions: [
          IconButton(
            icon: const Icon(Icons.brightness_6),
            tooltip: 'Cambiar tema',
            onPressed: () {
              context.read<ThemeService>().toggle();
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Ajustes',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: const _HomeBody(),
    );
  }
}

class _HomeBody extends StatelessWidget {
  const _HomeBody();

  Future<void> _importAudio(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await context.read<RecordingProvider>().importAudio();
      messenger.showSnackBar(
        const SnackBar(content: Text('Audio importado correctamente')),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('No se pudo importar el audio: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RecordingProvider>();
    final recordings = provider.recordings;
    final isRecording = provider.isRecording;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isRecording) const _RecordingIndicator(),
          if (!isRecording) ...[
            const GothicLogo(size: 74),
            const SizedBox(height: 4),
            Text(
              'Graba, transcribe y organiza tus audios.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed:
                isRecording ? provider.stopRecording : provider.startRecording,
            icon: Icon(isRecording ? Icons.stop : Icons.mic),
            label: Text(
              isRecording ? 'Detener grabacion' : 'Grabar audio',
            ),
            style: FilledButton.styleFrom(
              backgroundColor:
                  isRecording ? Theme.of(context).colorScheme.error : null,
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: isRecording ? null : () => _importAudio(context),
            icon: const Icon(Icons.folder_open),
            label: const Text('Importar audio'),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Text(
                'Grabaciones recientes',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const Spacer(),
              Text(
                '${recordings.length}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(child: _RecordingList(recordings: recordings)),
        ],
      ),
    );
  }
}

class _RecordingIndicator extends StatelessWidget {
  const _RecordingIndicator();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RecordingProvider>();
    final color = Theme.of(context).colorScheme.error;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _PulsingDot(color: color),
              const SizedBox(width: 12),
              Text(
                'Grabando...',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            provider.formattedElapsed,
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
              fontWeight: FontWeight.w300,
              fontFeatures: [const FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Toca "Detener" para finalizar',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}

class _PulsingDot extends StatefulWidget {
  const _PulsingDot({required this.color});

  final Color color;

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.4, end: 1.0).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _animation,
      child: Container(
        width: 14,
        height: 14,
        decoration: BoxDecoration(
          color: widget.color,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

class _RecordingList extends StatelessWidget {
  const _RecordingList({required this.recordings});

  final List<Recording> recordings;

  @override
  Widget build(BuildContext context) {
    if (recordings.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.mic_none_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              'Sin grabaciones',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Toca "Grabar audio" para comenzar',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      itemCount: recordings.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final recording = recordings[index];
        return RecordingCard(
          recording: recording,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => RecordingDetailScreen(recording: recording),
              ),
            );
          },
          onDelete: () {
            _confirmDelete(context, recording);
          },
        );
      },
    );
  }

  void _confirmDelete(BuildContext context, Recording recording) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar grabacion'),
        content: Text(
          'Se eliminara "${recording.title}". Esta accion no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              context.read<RecordingProvider>().deleteRecording(
                    recording.id,
                  );
              Navigator.of(ctx).pop();
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }
}
