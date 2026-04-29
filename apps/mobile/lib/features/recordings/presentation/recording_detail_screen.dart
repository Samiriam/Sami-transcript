import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../domain/recording.dart';

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
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Transcripcion disponible en Sprint 2'),
                    ),
                  );
                  break;
                case 'export':
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Exportacion disponible en Sprint 3'),
                    ),
                  );
                  break;
              }
            },
            itemBuilder:
                (_) => [
                  const PopupMenuItem(value: 'rename', child: Text('Renombrar')),
                  const PopupMenuItem(
                    value: 'transcribe',
                    child: Text('Transcribir'),
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
                            value:
                                _duration.inMilliseconds > 0
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
      RecordingStatus.saved => 'Guardado',
      RecordingStatus.transcribing => 'Transcribiendo',
      RecordingStatus.done => 'Completado',
      RecordingStatus.failed => 'Error',
    };
  }

  void _showRenameDialog(BuildContext context) {
    final controller = TextEditingController(text: widget.recording.title);
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
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
