import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/services/transcription_config.dart';
import '../../../core/services/transcription_service.dart';
import '../domain/recording.dart';
import '../presentation/transcription_provider.dart';

class TranscriptionScreen extends StatefulWidget {
  const TranscriptionScreen({super.key, required this.recording});

  final Recording recording;

  @override
  State<TranscriptionScreen> createState() => _TranscriptionScreenState();
}

class _TranscriptionScreenState extends State<TranscriptionScreen> {
  String? _fullText;
  List<Map<String, dynamic>> _segments = [];
  bool _isLoading = true;
  String? _summary;
  bool _isSummarizing = false;
  bool _isEditing = false;
  final _editController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadTranscription();
  }

  Future<void> _loadTranscription() async {
    final provider = context.read<TranscriptionProvider>();
    final text = await provider.getTranscriptionText(widget.recording.id);
    final segments = await provider.getSegments(widget.recording.id);

    if (!mounted) return;
    setState(() {
      _fullText = text;
      _segments = segments;
      _isLoading = false;
    });
  }

  Future<void> _startTranscription() async {
    final provider = context.read<TranscriptionProvider>();
    await provider.transcribeRecording(widget.recording.id);
    await _loadTranscription();
  }

  Future<void> _generateSummary() async {
    setState(() => _isSummarizing = true);
    final provider = context.read<TranscriptionProvider>();
    final summary = await provider.generateSummary(widget.recording.id);
    if (!mounted) return;
    setState(() {
      _summary = summary;
      _isSummarizing = false;
    });
  }

  Future<void> _downloadTranscription() async {
    await _showExportOptions(share: false);
  }

  Future<void> _shareTranscription() async {
    await _showExportOptions(share: true);
  }

  Future<void> _confirmDeleteTranscription() async {
    final provider = context.read<TranscriptionProvider>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Borrar transcripcion'),
        content: const Text(
          'Se borrara la transcripcion y sus segmentos. El audio original se conserva.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Borrar'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    try {
      await provider.deleteTranscription(
        widget.recording.id,
      );
      if (!mounted) return;
      setState(() {
        _fullText = null;
        _segments = [];
        _summary = null;
        _isEditing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Transcripcion borrada')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo borrar la transcripcion: $e')),
      );
    }
  }

  Future<void> _showExportOptions({required bool share}) async {
    var format = ExportFormat.pdf;
    var includeSummary = _summary != null && _summary!.trim().isNotEmpty;

    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      share ? 'Compartir documento' : 'Guardar documento',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    SegmentedButton<ExportFormat>(
                      segments: const [
                        ButtonSegment(
                            value: ExportFormat.pdf, label: Text('PDF')),
                        ButtonSegment(
                            value: ExportFormat.txt, label: Text('TXT')),
                      ],
                      selected: {format},
                      onSelectionChanged: (values) {
                        setSheetState(() => format = values.first);
                      },
                    ),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: includeSummary,
                      onChanged: _summary == null
                          ? null
                          : (value) => setSheetState(
                              () => includeSummary = value ?? false),
                      title: const Text('Incluir resumen'),
                    ),
                    const SizedBox(height: 8),
                    FilledButton.icon(
                      onPressed: () async {
                        Navigator.of(sheetContext).pop();
                        await _exportWithOptions(
                          format: format,
                          includeSummary: includeSummary,
                          share: share,
                        );
                      },
                      icon: Icon(share ? Icons.share_outlined : Icons.save_alt),
                      label: Text(
                          share ? 'Compartir' : 'Elegir ubicacion y guardar'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _exportWithOptions({
    required ExportFormat format,
    required bool includeSummary,
    required bool share,
  }) async {
    final provider = context.read<TranscriptionProvider>();
    final summary = includeSummary ? _summary : null;
    try {
      if (share) {
        final file = await provider.exportTranscription(
          widget.recording.id,
          recordingTitle: widget.recording.title,
          summary: summary,
          format: format,
        );
        await Share.shareXFiles(
          [XFile(file.path)],
          text: 'Transcripcion de ${widget.recording.title}',
        );
        return;
      }

      final path = await provider.saveExportAs(
        widget.recording.id,
        recordingTitle: widget.recording.title,
        summary: summary,
        format: format,
      );
      if (!mounted || path == null) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Documento guardado en $path')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo exportar la transcripcion: $e')),
      );
    }
  }

  @override
  void dispose() {
    _editController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final provider = context.watch<TranscriptionProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transcripcion'),
        actions: [
          if (_fullText != null)
            IconButton(
              icon: Icon(_isEditing ? Icons.check : Icons.edit_outlined),
              tooltip: _isEditing ? 'Guardar' : 'Editar',
              onPressed: () {
                if (_isEditing) {
                  setState(() {
                    _fullText = _editController.text;
                    _isEditing = false;
                  });
                } else {
                  _editController.text = _fullText ?? '';
                  setState(() => _isEditing = true);
                }
              },
            ),
          IconButton(
            icon: const Icon(Icons.download_outlined),
            tooltip: 'Descargar transcripcion',
            onPressed: _fullText == null ? null : _downloadTranscription,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Borrar transcripcion',
            onPressed: _fullText == null ? null : _confirmDeleteTranscription,
          ),
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: 'Compartir transcripcion',
            onPressed: _fullText == null ? null : _shareTranscription,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildBody(context, colorScheme, provider),
    );
  }

  Widget _buildBody(
    BuildContext context,
    ColorScheme colorScheme,
    TranscriptionProvider provider,
  ) {
    if (provider.isTranscribing) {
      return _buildTranscribingState(context, provider);
    }

    if (_fullText == null && provider.lastError != null) {
      return _buildErrorState(context, colorScheme, provider);
    }

    if (_fullText == null) {
      return _buildEmptyState(context, colorScheme);
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildEngineBadge(context),
        const SizedBox(height: 16),
        if (_isEditing) _buildEditor() else _buildTranscriptView(context),
        if (_segments.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text(
            'Segmentos',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),
          ..._segments.map((seg) => _SegmentCard(segment: seg)),
        ],
        const SizedBox(height: 24),
        _buildSummarySection(context, colorScheme),
      ],
    );
  }

  Widget _buildTranscribingState(
    BuildContext context,
    TranscriptionProvider provider,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 20),
            Text(
              provider.transcriptionStatus,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 12),
            Text(
              'Tiempo transcurrido: ${provider.transcriptionElapsedLabel}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Si la app se cierra o se cae, esta transcripcion no continua en segundo plano.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
            if (provider.isModelDownloading) ...[
              const SizedBox(height: 16),
              LinearProgressIndicator(value: provider.downloadProgress),
              const SizedBox(height: 8),
              Text(
                'Descargando modelo Whisper...',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(
    BuildContext context,
    ColorScheme colorScheme,
    TranscriptionProvider provider,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: colorScheme.error),
            const SizedBox(height: 16),
            Text(
              'Error en la transcripcion',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: colorScheme.error,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              provider.lastError ?? 'Error desconocido',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.outline,
                  ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _startTranscription,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, ColorScheme colorScheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.transcribe, size: 64, color: colorScheme.outline),
            const SizedBox(height: 16),
            Text(
              'Sin transcripcion',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: colorScheme.outline,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Toca el boton para transcribir este audio',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.outline,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _startTranscription,
              icon: const Icon(Icons.auto_fix_high),
              label: const Text('Transcribir'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEngineBadge(BuildContext context) {
    final config = context.read<TranscriptionConfig>();
    final label = switch (config.engine) {
      TranscriptionEngine.local => 'Whisper Local',
      TranscriptionEngine.openai => 'OpenAI API',
      TranscriptionEngine.assemblyai => 'AssemblyAI',
    };
    final icon = switch (config.engine) {
      TranscriptionEngine.local => Icons.phone_android,
      TranscriptionEngine.openai => Icons.cloud,
      TranscriptionEngine.assemblyai => Icons.cloud,
    };

    return Row(
      children: [
        Icon(icon, size: 16, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 6),
        Text(
          'Motor: $label',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
        ),
      ],
    );
  }

  Widget _buildEditor() {
    return TextField(
      controller: _editController,
      maxLines: null,
      autofocus: true,
      decoration: const InputDecoration(
        border: OutlineInputBorder(),
        hintText: 'Escribe la transcripcion...',
      ),
    );
  }

  Widget _buildTranscriptView(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SelectableText(
          _fullText ?? '',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ),
    );
  }

  Widget _buildSummarySection(BuildContext context, ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Resumen',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const Spacer(),
            if (_summary == null && !_isSummarizing)
              TextButton.icon(
                onPressed: _generateSummary,
                icon: const Icon(Icons.auto_awesome, size: 18),
                label: const Text('Generar resumen'),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (_isSummarizing)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            ),
          ),
        if (_summary != null)
          Card(
            color: colorScheme.secondaryContainer.withValues(alpha: 0.3),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                _summary!,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ),
      ],
    );
  }
}

class _SegmentCard extends StatelessWidget {
  const _SegmentCard({required this.segment});

  final Map<String, dynamic> segment;

  String _formatTime(double seconds) {
    final mins = (seconds ~/ 60).toString().padLeft(2, '0');
    final secs = (seconds % 60).toInt().toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  @override
  Widget build(BuildContext context) {
    final speaker = segment['speaker_label'] as String? ?? 'Hablante 1';
    final start = (segment['start_time'] as num?)?.toDouble() ?? 0.0;
    final end = (segment['end_time'] as num?)?.toDouble() ?? 0.0;
    final text = segment['text'] as String? ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    speaker,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${_formatTime(start)} - ${_formatTime(end)}',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(text, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}
