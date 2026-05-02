import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/services/app_logger.dart';
import '../../../core/services/theme_service.dart';
import '../../../core/services/openai_compatible_model_discovery_service.dart';
import '../../../core/services/transcription_config.dart';
import '../../../core/services/transcription_service.dart';
import 'transcription_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    final config = context.read<TranscriptionConfig>();
    await config.load();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final themeService = context.watch<ThemeService>();
    final config = context.watch<TranscriptionConfig>();

    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      body: ListView(
        children: [
          _SectionHeader(title: 'Apariencia'),
          ListTile(
            leading: const Icon(Icons.dark_mode_outlined),
            title: const Text('Tema'),
            subtitle: Text(_themeLabel(themeService.mode)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showThemePicker(context, themeService),
          ),
          _SectionHeader(title: 'Motor de transcripcion'),
          _EngineSelector(config: config),
          if (config.engine == TranscriptionEngine.local) ...[
            ListTile(
              leading: const Icon(Icons.model_training),
              title: const Text('Modelo Whisper'),
              subtitle: Text(_whisperModelLabel(config.whisperModel)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showWhisperModelPicker(context, config),
            ),
            const ListTile(
              leading: Icon(Icons.memory_outlined),
              title: Text('Rendimiento local'),
              subtitle: Text(
                'Tiny es el mas estable. Base puede funcionar en equipos mejores o con paciencia. Para base/small la app desactiva segmentos locales para reducir cierres al finalizar.',
              ),
            ),
          ],
          _SectionHeader(title: 'Resumen'),
          _SummaryEngineSelector(config: config),
          if (config.summaryEngine == SummaryEngine.openai) ...[
            ListTile(
              leading: const Icon(Icons.hub_outlined),
              title: const Text('Proveedor y modelo de resumen'),
              subtitle: Text(
                '${config.selectedSummaryOpenAiPreset.label} · ${config.summaryOpenAiModel}\n${config.summaryOpenAiBaseUrl}',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showSummaryProviderConfigDialog(context, config),
            ),
            const ListTile(
              leading: Icon(Icons.info_outline),
              title: Text('Discovery de modelos'),
              subtitle: Text(
                'El modelo de resumen se selecciona solo desde /models despues de validar credenciales. No se permite ingreso manual.',
              ),
            ),
          ],
          if (config.summaryEngine == SummaryEngine.assemblyai) ...[
            ListTile(
              leading: const Icon(Icons.key),
              title: const Text('API Key resumen'),
              subtitle: Text(
                config.summaryAssemblyAiKey.isEmpty
                    ? 'No configurada'
                    : '${config.summaryAssemblyAiKey.substring(0, 8)}...',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showApiKeyDialog(
                context,
                title: 'AssemblyAI API Key resumen',
                current: config.summaryAssemblyAiKey,
                onSave: (value) => config.setSummaryAssemblyAiKey(value),
              ),
            ),
          ],
          if (config.engine == TranscriptionEngine.openai) ...[
            ListTile(
              leading: const Icon(Icons.key),
              title: const Text('API Key'),
              subtitle: Text(
                config.openAiKey.isEmpty
                    ? 'No configurada'
                    : '${config.openAiKey.substring(0, 8)}...',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showApiKeyDialog(
                context,
                title: 'OpenAI API Key',
                current: config.openAiKey,
                onSave: (value) => config.setOpenAiConfig(apiKey: value),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.link),
              title: const Text('URL base (compatible)'),
              subtitle: Text(
                '${config.openAiBaseUrl}\nPara transcripcion debe exponer /audio/transcriptions. OpenRouter normalmente sirve para resumen via /chat/completions.',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showApiKeyDialog(
                context,
                title: 'URL base de la API',
                current: config.openAiBaseUrl,
                onSave: (value) => config.setOpenAiConfig(
                  apiKey: config.openAiKey,
                  baseUrl: value,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.audiotrack),
              title: const Text('Modelo de transcripcion'),
              subtitle: Text(config.openAiModel),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showApiKeyDialog(
                context,
                title: 'Modelo de transcripcion',
                current: config.openAiModel,
                onSave: (value) => config.setOpenAiConfig(
                  apiKey: config.openAiKey,
                  model: value,
                ),
              ),
            ),
          ],
          if (config.engine == TranscriptionEngine.assemblyai) ...[
            ListTile(
              leading: const Icon(Icons.key),
              title: const Text('API Key'),
              subtitle: Text(
                config.assemblyAiKey.isEmpty
                    ? 'No configurada'
                    : '${config.assemblyAiKey.substring(0, 8)}...',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showApiKeyDialog(
                context,
                title: 'AssemblyAI API Key',
                current: config.assemblyAiKey,
                onSave: (value) => config.setAssemblyAiKey(value),
              ),
            ),
          ],
          _SectionHeader(title: 'Grabacion'),
          ListTile(
            leading: const Icon(Icons.audiotrack_outlined),
            title: const Text('Formato de audio'),
            subtitle: const Text('WAV mono 16 kHz'),
          ),
          _SectionHeader(title: 'Informacion'),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('Version'),
            subtitle: const Text('0.1.0+1 (beta personal)'),
          ),
          ListTile(
            leading: const Icon(Icons.storage_outlined),
            title: const Text('Base de datos'),
            subtitle: const Text('SQLite local'),
          ),
          _SectionHeader(title: 'Depuracion'),
          ListTile(
            leading: const Icon(Icons.bug_report_outlined),
            title: const Text('Ver logs'),
            subtitle: const Text('Registros de actividad y errores'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showLogViewer(context),
          ),
          ListTile(
            leading: const Icon(Icons.delete_sweep_outlined),
            title: const Text('Limpiar logs'),
            subtitle: const Text('Borrar registros de depuracion'),
            onTap: () => _clearLogs(context),
          ),
        ],
      ),
    );
  }

  String _themeLabel(ThemeMode mode) {
    return switch (mode) {
      ThemeMode.system => 'Segun el sistema',
      ThemeMode.light => 'Claro',
      ThemeMode.dark => 'Oscuro',
    };
  }

  String _whisperModelLabel(String model) {
    return switch (model) {
      'tiny' => 'Tiny (~75 MB, recomendado, mas rapido)',
      'base' => 'Base (~140 MB, mas lento y exige mas memoria)',
      'small' => 'Small (~460 MB, alto consumo; puede cerrar la app)',
      _ => model,
    };
  }

  void _showThemePicker(BuildContext context, ThemeService service) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Seleccionar tema',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              for (final mode in ThemeMode.values)
                ListTile(
                  leading: Icon(switch (mode) {
                    ThemeMode.system => Icons.brightness_auto,
                    ThemeMode.light => Icons.light_mode,
                    ThemeMode.dark => Icons.dark_mode,
                  }),
                  title: Text(_themeLabel(mode)),
                  trailing:
                      service.mode == mode ? const Icon(Icons.check) : null,
                  onTap: () {
                    service.setMode(mode);
                    Navigator.of(ctx).pop();
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  void _showWhisperModelPicker(
      BuildContext context, TranscriptionConfig config) {
    final models = ['tiny', 'base', 'small'];
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Modelo Whisper',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              for (final m in models)
                ListTile(
                  title: Text(m.toUpperCase()),
                  subtitle: Text(_whisperModelLabel(m)),
                  trailing:
                      config.whisperModel == m ? const Icon(Icons.check) : null,
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _replaceWhisperModel(context, config, m);
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  void _showApiKeyDialog(
    BuildContext context, {
    required String title,
    required String current,
    required void Function(String) onSave,
  }) {
    final controller = TextEditingController(text: current);
    final obscured = title.contains('Key') || title.contains('API');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          obscureText: obscured,
          decoration: InputDecoration(
            hintText: obscured ? 'sk-...' : null,
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              onSave(controller.text.trim());
              Navigator.of(ctx).pop();
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  Future<void> _replaceWhisperModel(
    BuildContext context,
    TranscriptionConfig config,
    String model,
  ) async {
    if (model == config.whisperModel) return;
    final messenger = ScaffoldMessenger.of(context);
    var progress = 0.0;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Descargando modelo'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Modelo: ${model.toUpperCase()}'),
                  const SizedBox(height: 12),
                  LinearProgressIndicator(
                      value: progress == 0 ? null : progress),
                  const SizedBox(height: 8),
                  const Text(
                    'Al finalizar se eliminara el modelo local anterior para liberar espacio.',
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    try {
      await context.read<TranscriptionProvider>().replaceLocalModel(
        model,
        onProgress: (value) {
          progress = value;
        },
      );
      if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
      messenger.showSnackBar(
        SnackBar(content: Text('Modelo ${model.toUpperCase()} listo')),
      );
    } catch (e) {
      if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
      messenger.showSnackBar(
        SnackBar(content: Text('No se pudo cambiar el modelo: $e')),
      );
    }
  }

  Future<void> _showLogViewer(BuildContext context) async {
    final logger = AppLogger.instance;
    await logger.rotateIfNeeded();
    final content = await logger.getLogContent();

    if (!context.mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _LogViewerScreen(content: content),
      ),
    );
  }

  Future<void> _clearLogs(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Limpiar logs'),
        content: const Text('Se borraran todos los registros de depuracion.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Borrar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await AppLogger.instance.clearLogs();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Logs limpiados')),
    );
  }

  Future<void> _showSummaryProviderConfigDialog(
    BuildContext context,
    TranscriptionConfig config,
  ) async {
    final discoveryService = OpenAiCompatibleModelDiscoveryService();
    final apiKeyController =
        TextEditingController(text: config.summaryOpenAiKey);
    final baseUrlController =
        TextEditingController(text: config.summaryOpenAiBaseUrl);
    var selectedPresetId = config.summaryOpenAiPresetId;
    var selectedModelId = config.summaryOpenAiModel;
    var availableModels = <SummaryModelOption>[];
    var isLoading = false;
    var errorMessage = '';
    var validated = false;

    Future<void> validateAndLoadModels(StateSetter setDialogState) async {
      setDialogState(() {
        isLoading = true;
        errorMessage = '';
        validated = false;
        availableModels = [];
      });
      try {
        final preset = config.summaryOpenAiPresets.firstWhere(
          (item) => item.id == selectedPresetId,
        );
        final models = await discoveryService.fetchModels(
          baseUrl: baseUrlController.text,
          apiKey: apiKeyController.text,
          prioritizeFreeModels: preset.prioritizeFreeModels,
        );
        final selected = models.any((model) => model.id == selectedModelId)
            ? selectedModelId
            : models.first.id;
        setDialogState(() {
          availableModels = models;
          selectedModelId = selected;
          validated = true;
        });
      } catch (e) {
        setDialogState(() {
          errorMessage = e.toString();
        });
      } finally {
        setDialogState(() {
          isLoading = false;
        });
      }
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Configurar resumen OpenAI/OpenRouter'),
              content: SizedBox(
                width: 520,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DropdownButtonFormField<String>(
                        value: selectedPresetId,
                        decoration: const InputDecoration(
                          labelText: 'Directorio de proveedor',
                          border: OutlineInputBorder(),
                        ),
                        items: config.summaryOpenAiPresets
                            .map(
                              (preset) => DropdownMenuItem(
                                value: preset.id,
                                child: Text(preset.label),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value == null) return;
                          final preset = config.summaryOpenAiPresets.firstWhere(
                            (item) => item.id == value,
                          );
                          setDialogState(() {
                            selectedPresetId = value;
                            if (preset.baseUrl.isNotEmpty) {
                              baseUrlController.text = preset.baseUrl;
                            }
                            validated = false;
                            errorMessage = '';
                            availableModels = [];
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      Text(
                        config.summaryOpenAiPresets
                            .firstWhere((item) => item.id == selectedPresetId)
                            .description,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: baseUrlController,
                        decoration: const InputDecoration(
                          labelText: 'URL base compatible',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (_) => setDialogState(() {
                          validated = false;
                          errorMessage = '';
                          availableModels = [];
                        }),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: apiKeyController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'API Key',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (_) => setDialogState(() {
                          validated = false;
                          errorMessage = '';
                          availableModels = [];
                        }),
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: isLoading
                            ? null
                            : () => validateAndLoadModels(setDialogState),
                        icon: const Icon(Icons.cloud_sync_outlined),
                        label: Text(
                          isLoading
                              ? 'Validando...'
                              : 'Validar y cargar modelos',
                        ),
                      ),
                      if (errorMessage.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(
                          errorMessage,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ],
                      if (validated && availableModels.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: selectedModelId,
                          decoration: const InputDecoration(
                            labelText: 'Modelo de resumen',
                            border: OutlineInputBorder(),
                          ),
                          items: availableModels
                              .map(
                                (model) => DropdownMenuItem(
                                  value: model.id,
                                  child: Text(model.displayName),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value == null) return;
                            setDialogState(() => selectedModelId = value);
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: !validated || selectedModelId.isEmpty
                      ? null
                      : () async {
                          await config.setSummaryOpenAiConfig(
                            apiKey: apiKeyController.text.trim(),
                            baseUrl: baseUrlController.text.trim(),
                            model: selectedModelId,
                            presetId: selectedPresetId,
                          );
                          if (dialogContext.mounted) {
                            Navigator.of(dialogContext).pop();
                          }
                        },
                  child: const Text('Guardar configuracion'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _SummaryEngineSelector extends StatelessWidget {
  const _SummaryEngineSelector({required this.config});

  final TranscriptionConfig config;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final engine in SummaryEngine.values)
          RadioListTile<SummaryEngine>(
            value: engine,
            groupValue: config.summaryEngine,
            onChanged: (value) {
              if (value != null) config.setSummaryEngine(value);
            },
            title: Text(_summaryEngineLabel(engine)),
            subtitle: Text(_summaryEngineDescription(engine)),
            secondary: Icon(_summaryEngineIcon(engine)),
          ),
      ],
    );
  }

  String _summaryEngineLabel(SummaryEngine engine) {
    return switch (engine) {
      SummaryEngine.local => 'Resumen local',
      SummaryEngine.openai => 'OpenAI para resumen',
      SummaryEngine.assemblyai => 'AssemblyAI para resumen',
    };
  }

  String _summaryEngineDescription(SummaryEngine engine) {
    return switch (engine) {
      SummaryEngine.local => 'Gratis, rapido, calidad limitada',
      SummaryEngine.openai =>
        'Mejor redaccion y estructura; API separada para OpenAI/OpenRouter',
      SummaryEngine.assemblyai => 'Resumen cloud; requiere API key AssemblyAI',
    };
  }

  IconData _summaryEngineIcon(SummaryEngine engine) {
    return switch (engine) {
      SummaryEngine.local => Icons.phone_android,
      SummaryEngine.openai => Icons.auto_awesome,
      SummaryEngine.assemblyai => Icons.cloud_queue,
    };
  }
}

class _EngineSelector extends StatelessWidget {
  const _EngineSelector({required this.config});

  final TranscriptionConfig config;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final engine in TranscriptionEngine.values)
          RadioListTile<TranscriptionEngine>(
            value: engine,
            groupValue: config.engine,
            onChanged: (value) {
              if (value != null) config.setEngine(value);
            },
            title: Text(_engineLabel(engine)),
            subtitle: Text(_engineDescription(engine)),
            secondary: Icon(_engineIcon(engine)),
          ),
      ],
    );
  }

  String _engineLabel(TranscriptionEngine engine) {
    return switch (engine) {
      TranscriptionEngine.local => 'Whisper Local',
      TranscriptionEngine.openai => 'OpenAI / Compatible',
      TranscriptionEngine.assemblyai => 'AssemblyAI',
    };
  }

  String _engineDescription(TranscriptionEngine engine) {
    return switch (engine) {
      TranscriptionEngine.local => 'Sin internet, gratis, privado',
      TranscriptionEngine.openai => 'API cloud, mas preciso, requiere API key',
      TranscriptionEngine.assemblyai =>
        'API cloud con diarizacion, requiere API key',
    };
  }

  IconData _engineIcon(TranscriptionEngine engine) {
    return switch (engine) {
      TranscriptionEngine.local => Icons.phone_android,
      TranscriptionEngine.openai => Icons.cloud,
      TranscriptionEngine.assemblyai => Icons.cloud_queue,
    };
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class _LogViewerScreen extends StatelessWidget {
  const _LogViewerScreen({required this.content});

  final String content;

  @override
  Widget build(BuildContext context) {
    final lines = content.split('\n');
    return Scaffold(
      appBar: AppBar(title: const Text('Logs de la app')),
      body: ListView.builder(
        itemCount: lines.length,
        itemBuilder: (context, index) {
          final line = lines[index];
          final isError = line.contains('[ERROR]');
          final isWarning = line.contains('[WARN]');
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 1),
            child: SelectableText(
              line,
              style: TextStyle(
                fontSize: 11,
                fontFamily: 'monospace',
                color: isError
                    ? Theme.of(context).colorScheme.error
                    : isWarning
                        ? Colors.orange
                        : null,
              ),
            ),
          );
        },
      ),
    );
  }
}
