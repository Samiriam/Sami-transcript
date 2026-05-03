import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../domain/recording.dart';
import 'transcription_provider.dart';
import 'transcription_screen.dart';

class RecordingDetailScreen extends StatefulWidget {
  const RecordingDetailScreen({super.key, required this.recording});

  final Recording recording;

  @override
  State<RecordingDetailScreen> createState() => _RecordingDetailScreenState();
}

class _RecordingDetailScreenState extends State<RecordingDetailScreen> {
  late final AudioPlayer _player;
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _setupPlayer();
  }

  void _setupPlayer() {
    _player.onPlayerStateChanged.listen((state) {
      if (!mounted) return;
      setState(() {
        _isPlaying = state == PlayerState.playing;
      });
    });

    _player.onDurationChanged.listen((d) {
      if (!mounted) return;
      setState(() => _duration = d);
    });

    _player.onPositionChanged.listen((p) {
      if (!mounted) return;
      setState(() => _position = p);
    });
  }

  Future<void> _togglePlayback() async {
    if (_isPlaying) {
      await _player.pause();
    } else {
      final file = File(widget.recording.audioPath);
      if (await file.exists()) {
        await _player.play(DeviceFileSource(widget.recording.audioPath));
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Archivo de audio no encontrado')),
        );
      }
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '${d.inHours > 0 ? '${d.inHours}:' : ''}$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.recording;
    final dateFormat = DateFormat('dd MMM yyyy, HH:mm');
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(r.title),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'rename':
                  _showRenameDialog(context);
                  break;
                case 'transcribe':
                  _openTranscriptionScreen(context);
                  break;
                case 'export':
                  _exportTranscription(context);
                  break;
                case 'share_audio':
                  _shareAudio(context);
                  break;
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'rename', child: Text('Renombrar')),
              const PopupMenuItem(
                value: 'transcribe',
                child: Text('Abrir transcripcion'),
              ),
              const PopupMenuItem(
                value: 'share_audio',
                child: Text('Compartir audio'),
              ),
              const PopupMenuItem(value: 'export', child: Text('Exportar')),
            ],
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Icon(
                      Icons.audiotrack,
                      size: 48,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      r.title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      dateFormat.format(r.createdAt),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Duracion: ${r.formattedDuration}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Text(
                          _formatDuration(_position),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        Expanded(
                          child: Slider(
                            value: _duration.inMilliseconds > 0
                                ? _position.inMilliseconds /
                                    _duration.inMilliseconds
                                : 0,
                            onChanged: (value) {
                              final pos = Duration(
                                milliseconds:
                                    (value * _duration.inMilliseconds).round(),
                              );
                              _player.seek(pos);
                            },
                          ),
                        ),
                        Text(
                          _formatDuration(_duration),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton.outlined(
                          onPressed: () {
                            _player.seek(Duration.zero);
                          },
                          icon: const Icon(Icons.replay_10),
                        ),
                        const SizedBox(width: 16),
                        FloatingActionButton(
                          onPressed: _togglePlayback,
                          child: Icon(
                            _isPlaying ? Icons.pause : Icons.play_arrow,
                          ),
                        ),
                        const SizedBox(width: 16),
                        IconButton.outlined(
                          onPressed: () {
                            _player.seek(
                              _position + const Duration(seconds: 10),
                            );
                          },
                          icon: const Icon(Icons.forward_10),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            _TranscriptionCallout(
              status: r.status,
              onTap: r.status == RecordingStatus.transcribing
                  ? null
                  : () => _openTranscriptionScreen(context),
            ),
            const SizedBox(height: 20),
            Text(
              'Informacion',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 8),
            _InfoRow(label: 'Estado', value: _statusLabel(r.status)),
            _InfoRow(
              label: 'Fuente',
              value: r.source == RecordingSource.app ? 'App' : 'Importado',
            ),
            _InfoRow(
              label: 'Creada',
              value: dateFormat.format(r.createdAt),
            ),
            if (r.updatedAt != null)
              _InfoRow(
                label: 'Actualizada',
                value: dateFormat.format(r.updatedAt!),
              ),
          ],
        ),
      ),
    );
  }

  String _statusLabel(RecordingStatus status) {
    return switch (status) {
      RecordingStatus.idle => 'Pendiente',
      RecordingStatus.recording => 'Grabando',
      RecordingStatus.saved => 'Listo para transcribir',
      RecordingStatus.transcribing => 'Transcribiendo',
      RecordingStatus.done => 'Transcripcion lista',
      RecordingStatus.failed => 'Error, reintentar',
    };
  }

  void _openTranscriptionScreen(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TranscriptionScreen(recording: widget.recording),
      ),
    );
  }

  Future<void> _exportTranscription(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final provider = context.read<TranscriptionProvider>();
      final path = await provider.saveExportAs(
        widget.recording.id,
        recordingTitle: widget.recording.title,
        format: ExportFormat.pdf,
      );
      if (path == null) return;
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Transcripcion guardada en $path')),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('No se pudo exportar la transcripcion: $e')),
      );
    }
  }

  Future<void> _shareAudio(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final audioFile = File(widget.recording.audioPath);
    if (!await audioFile.exists()) {
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(
            content: Text('El archivo de audio no existe en el dispositivo')),
      );
      return;
    }

    await Share.shareXFiles(
      [XFile(audioFile.path)],
      text: 'Audio de ${widget.recording.title}',
    );
  }

  void _showRenameDialog(BuildContext context) {
    final controller = TextEditingController(text: widget.recording.title);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Renombrar grabacion'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Nombre',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }
}

class _TranscriptionCallout extends StatelessWidget {
  const _TranscriptionCallout({required this.status, required this.onTap});

  final RecordingStatus status;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final (title, message, icon, emphasized) = switch (status) {
      RecordingStatus.saved => (
          'Siguiente paso recomendado',
          'Este audio ya esta listo. Toca abajo para generar la transcripcion y el resumen.',
          Icons.auto_fix_high,
          true,
        ),
      RecordingStatus.failed => (
          'Transcripcion pendiente',
          'La transcripcion anterior fallo. Vuelve a abrirla para reintentar con otra API o con el motor local.',
          Icons.refresh,
          true,
        ),
      RecordingStatus.transcribing => (
          'Transcripcion en progreso',
          'La app esta procesando este audio en este momento.',
          Icons.hourglass_top,
          false,
        ),
      RecordingStatus.done => (
          'Transcripcion disponible',
          'Abre la transcripcion para leer el texto completo y generar o revisar el resumen.',
          Icons.description_outlined,
          false,
        ),
      _ => (
          'Audio guardado',
          'Desde aqui puedes abrir la transcripcion cuando quieras.',
          Icons.article_outlined,
          false,
        ),
    };

    final buttonLabel = switch (status) {
      RecordingStatus.done => 'Ver transcripcion y resumen',
      RecordingStatus.transcribing => 'Procesando audio...',
      RecordingStatus.failed => 'Reintentar transcripcion',
      _ => 'Transcribir ahora',
    };

    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      color: emphasized
          ? colorScheme.primaryContainer.withValues(alpha: 0.55)
          : colorScheme.surfaceContainerHighest.withValues(alpha: 0.65),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: colorScheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(message, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onTap,
                icon: Icon(status == RecordingStatus.done
                    ? Icons.visibility_outlined
                    : Icons.auto_fix_high),
                label: Text(buttonLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
          Expanded(
            child: Text(value, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}
