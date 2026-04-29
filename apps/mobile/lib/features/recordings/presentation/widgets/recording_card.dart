import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../domain/recording.dart';

class RecordingCard extends StatelessWidget {
  const RecordingCard({
    super.key,
    required this.recording,
    this.onTap,
    this.onDelete,
  });

  final Recording recording;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final dateFormat = DateFormat('dd MMM yyyy, HH:mm');

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              _StatusIcon(status: recording.status),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      recording.title,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.schedule,
                          size: 14,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          recording.formattedDuration,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                        ),
                        const SizedBox(width: 12),
                        Icon(
                          Icons.calendar_today_outlined,
                          size: 14,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          dateFormat.format(recording.createdAt),
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    _StatusChip(status: recording.status),
                  ],
                ),
              ),
              if (onDelete != null)
                IconButton(
                  icon: Icon(
                    Icons.delete_outline,
                    color: colorScheme.error,
                    size: 20,
                  ),
                  onPressed: onDelete,
                  tooltip: 'Eliminar',
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusIcon extends StatelessWidget {
  const _StatusIcon({required this.status});

  final RecordingStatus status;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return switch (status) {
      RecordingStatus.recording => CircleAvatar(
        backgroundColor: colorScheme.errorContainer,
        child: Icon(Icons.fiber_manual_record, color: colorScheme.error, size: 20),
      ),
      RecordingStatus.saved => CircleAvatar(
        backgroundColor: colorScheme.primaryContainer,
        child: Icon(Icons.check_circle_outline, color: colorScheme.primary, size: 20),
      ),
      RecordingStatus.transcribing => CircleAvatar(
        backgroundColor: colorScheme.tertiaryContainer,
        child: Icon(Icons.auto_fix_high, color: colorScheme.tertiary, size: 20),
      ),
      RecordingStatus.done => CircleAvatar(
        backgroundColor: colorScheme.secondaryContainer,
        child: Icon(Icons.description_outlined, color: colorScheme.secondary, size: 20),
      ),
      RecordingStatus.failed => CircleAvatar(
        backgroundColor: colorScheme.errorContainer,
        child: Icon(Icons.error_outline, color: colorScheme.error, size: 20),
      ),
      RecordingStatus.idle => CircleAvatar(
        backgroundColor: colorScheme.surfaceContainerHighest,
        child: Icon(Icons.hourglass_empty, color: colorScheme.outline, size: 20),
      ),
    };
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final RecordingStatus status;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final (label, bgColor, fgColor) = switch (status) {
      RecordingStatus.idle => ('Pendiente', colorScheme.surfaceContainerHighest, colorScheme.outline),
      RecordingStatus.recording => ('Grabando', colorScheme.errorContainer, colorScheme.error),
      RecordingStatus.saved => ('Guardado', colorScheme.primaryContainer, colorScheme.primary),
      RecordingStatus.transcribing => ('Transcribiendo', colorScheme.tertiaryContainer, colorScheme.tertiary),
      RecordingStatus.done => ('Completado', colorScheme.secondaryContainer, colorScheme.secondary),
      RecordingStatus.failed => ('Error', colorScheme.errorContainer, colorScheme.error),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: fgColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
