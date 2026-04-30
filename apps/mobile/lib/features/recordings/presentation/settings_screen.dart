import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/services/theme_service.dart';
import '../../../core/services/transcription_config.dart';
import '../../../core/services/transcription_service.dart';

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
              subtitle: Text(config.openAiBaseUrl),
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
            subtitle: const Text('AAC (.m4a)'),
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
      'tiny' => 'Tiny (~75 MB, rapido, menos preciso)',
      'base' => 'Base (~140 MB, equilibrio)',
      'small' => 'Small (~460 MB, mas preciso)',
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

  void _showWhisperModelPicker(BuildContext context, TranscriptionConfig config) {
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
                      config.whisperModel == m
                          ? const Icon(Icons.check)
                          : null,
                  onTap: () {
                    config.setWhisperModel(m);
                    Navigator.of(ctx).pop();
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
