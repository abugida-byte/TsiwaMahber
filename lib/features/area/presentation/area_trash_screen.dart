import 'package:flutter/material.dart';
import 'package:tsiwa_mahber/core/theme/app_theme.dart';
import 'package:tsiwa_mahber/core/widgets/loading_state.dart';
import 'package:tsiwa_mahber/features/area/data/area_repository.dart';
import 'package:tsiwa_mahber/features/area/domain/area.dart';
import 'package:tsiwa_mahber/core/l10n/app_strings.dart';

class AreaTrashScreen extends StatelessWidget {
  const AreaTrashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final areaRepository = AreaRepository();

    return Scaffold(
      appBar: AppBar(title: Text(S.trash)),
      body: StreamBuilder<List<Area>>(
        stream: areaRepository.watchDeletedAreas(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return LoadingState(message: S.loading);
          }

          final areas = snapshot.data ?? [];

          if (areas.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.delete_outline,
                      size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text(
                    S.noDeletedAreas,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade400,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: areas.length,
            itemBuilder: (context, index) {
              final area = areas[index];
              return _TrashAreaCard(
                area: area,
                onRestore: () => _restore(context, areaRepository, area),
                onPermanentDelete: () =>
                    _permanentDelete(context, areaRepository, area),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _restore(
    BuildContext context,
    AreaRepository repo,
    Area area,
  ) async {
    try {
      await repo.restoreArea(area.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(S.areaRestored)),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(S.saveFailed)),
        );
      }
    }
  }

  Future<void> _permanentDelete(
    BuildContext context,
    AreaRepository repo,
    Area area,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(S.permanentDelete),
        content: Text(S.permanentDeleteConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(S.cancel),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: Text(S.delete),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await repo.deleteArea(area.id);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(S.deleteFailed)),
        );
      }
    }
  }
}

class _TrashAreaCard extends StatelessWidget {
  final Area area;
  final VoidCallback onRestore;
  final VoidCallback onPermanentDelete;

  const _TrashAreaCard({
    required this.area,
    required this.onRestore,
    required this.onPermanentDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.church, color: Colors.red, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    area.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (area.deletedBy.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      area.deletedBy,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.restore, color: Colors.green),
              tooltip: S.restore,
              onPressed: onRestore,
            ),
            IconButton(
              icon: const Icon(Icons.delete_forever, color: Colors.red),
              tooltip: S.permanentDelete,
              onPressed: onPermanentDelete,
            ),
          ],
        ),
      ),
    );
  }
}
