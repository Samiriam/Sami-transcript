import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/services/theme_service.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeService = context.watch<ThemeService>();

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
          _SectionHeader(title: 'Grabacion'),
          ListTile(
            leading: const Icon(Icons.audiotrack_outlined),
            title: const Text('Formato de audio'),
            subtitle: const Text('AAC (.m4a)'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.folder_outlined),
            title: const Text('Carpeta de grabaciones'),
            subtitle: const Text('Documentos/sami_transcribe/recordings'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
          _SectionHeader(title: 'Transcripcion'),
          ListTile(
            leading: const Icon(Icons.translate),
            title: const Text('Idioma predeterminado'),
            subtitle: const Text('Espanol'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.smart_toy_outlined),
            title: const Text('Motor de transcripcion'),
            subtitle: const Text('No configurado'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
          _SectionHeader(title: 'Datos'),
          ListTile(
            leading: const Icon(Icons.storage_outlined),
            title: const Text('Base de datos local'),
            subtitle: const Text('SQLite / Drift'),
          ),
          ListTile(
            leading: Icon(
              Icons.info_outline,
              color: Theme.of(context).colorScheme.outline,
            ),
            title: const Text('Version'),
            subtitle: const Text('0.1.0+1 (beta personal)'),
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
