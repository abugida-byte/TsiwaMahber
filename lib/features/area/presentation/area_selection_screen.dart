import 'package:flutter/material.dart';
import 'package:tsiwa_mahber/core/theme/app_theme.dart';
import 'package:tsiwa_mahber/core/widgets/app_popup_menu.dart';
import 'package:tsiwa_mahber/core/widgets/loading_state.dart';
import 'package:tsiwa_mahber/features/area/data/area_repository.dart';
import 'package:tsiwa_mahber/features/area/domain/area.dart';
import 'package:tsiwa_mahber/features/area/presentation/area_home_screen.dart';
import 'package:tsiwa_mahber/features/area/presentation/area_trash_screen.dart';
import 'package:tsiwa_mahber/features/auth/domain/app_user.dart';
import 'package:tsiwa_mahber/features/developer/data/developer_service.dart';
import 'package:tsiwa_mahber/core/l10n/app_strings.dart';

class AreaSelectionScreen extends StatefulWidget {
  final AppUser? currentUser;
  final ThemeProvider themeProvider;
  final LocaleProvider localeProvider;

  const AreaSelectionScreen({
    super.key,
    this.currentUser,
    required this.themeProvider,
    required this.localeProvider,
  });

  @override
  State<AreaSelectionScreen> createState() => _AreaSelectionScreenState();
}

class _AreaSelectionScreenState extends State<AreaSelectionScreen> {
  final _areaRepository = AreaRepository();
  final _developerService = DeveloperService();
  bool _showHidden = false;

  @override
  void initState() {
    super.initState();
    _initDefaults();
  }

  Future<void> _initDefaults() async {
    try {
      await _areaRepository.ensureDefaultArea();
      await _developerService.ensureDefaultDevelopers();
    } catch (_) {}
  }

  bool get _isDev => widget.currentUser?.role.isDeveloper == true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(S.appName),
        actions: [
          if (_isDev)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: S.trash,
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AreaTrashScreen(),
                  ),
                );
              },
            ),
          if (_isDev)
            IconButton(
              icon: Icon(
                _showHidden ? Icons.visibility : Icons.visibility_off,
              ),
              tooltip: S.showHidden,
              onPressed: () => setState(() => _showHidden = !_showHidden),
            ),
          AppPopupMenu(
            themeProvider: widget.themeProvider,
            localeProvider: widget.localeProvider,
          ),
        ],
      ),
      body: StreamBuilder<List<Area>>(
        stream: _areaRepository.watchAllAreas(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return LoadingState(message: S.loading);
          }

          final allAreas = snapshot.data ?? [];

          if (allAreas.isEmpty) {
            return Center(
              child: LoadingState(message: S.preparingData),
            );
          }

          final areas = _showHidden
              ? allAreas
              : allAreas.where((a) => !a.isHidden).toList();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 16),
                child: Text(
                  S.selectArea,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              ...areas.map((area) => _AreaCard(
                    area: area,
                    isDev: _isDev,
                    onTap: () => _openArea(area),
                    onEdit: () => _showEditAreaDialog(area),
                    onHide: () => _toggleHide(area),
                    onDelete: () => _confirmDelete(area),
                  )),
            ],
          );
        },
      ),
      floatingActionButton: _isDev
          ? FloatingActionButton(
              onPressed: _showCreateAreaDialog,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  void _openArea(Area area) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AreaHomeScreen(
          currentUser: widget.currentUser,
          areaId: area.id,
          areaName: area.name,
          themeProvider: widget.themeProvider,
          localeProvider: widget.localeProvider,
        ),
      ),
    );
  }

  // ── Edit ──

  Future<void> _showEditAreaDialog(Area area) async {
    final nameController = TextEditingController(text: area.name);
    final shortNameController = TextEditingController(text: area.shortName);
    final locationController = TextEditingController(text: area.location);
    final descriptionController =
        TextEditingController(text: area.description);

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(S.editArea),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'ስም *'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: shortNameController,
                decoration: const InputDecoration(labelText: 'አጭር ስም *'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: locationController,
                decoration: InputDecoration(labelText: S.address),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descriptionController,
                decoration: InputDecoration(labelText: S.description),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(S.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(S.save),
          ),
        ],
      ),
    );

    if (result == true) {
      final name = nameController.text.trim();
      final shortName = shortNameController.text.trim();

      if (name.isEmpty || shortName.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(S.nameAndShortRequired)),
          );
        }
        return;
      }

      try {
        final updated = area.copyWith(
          name: name,
          shortName: shortName,
          location: locationController.text.trim(),
          description: descriptionController.text.trim(),
        );
        await _areaRepository.updateArea(updated);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(S.saveFailed)),
          );
        }
      }
    }

    nameController.dispose();
    shortNameController.dispose();
    locationController.dispose();
    descriptionController.dispose();
  }

  // ── Hide / Unhide ──

  Future<void> _toggleHide(Area area) async {
    try {
      await _areaRepository.hideArea(area.id, !area.isHidden);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text(area.isHidden ? S.areaVisible : S.areaHidden),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(S.saveFailed)),
        );
      }
    }
  }

  // ── Delete (soft) ──

  Future<void> _confirmDelete(Area area) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(S.deleteAreaTitle),
        content: Text(S.deleteAreaConfirm),
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
      final deletedBy =
          widget.currentUser?.displayName ?? widget.currentUser?.uid ?? '';
      await _areaRepository.softDeleteArea(area.id, deletedBy);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(S.areaDeleted)),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(S.deleteFailed)),
        );
      }
    }
  }

  // ── Create ──

  Future<void> _showCreateAreaDialog() async {
    final nameController = TextEditingController();
    final shortNameController = TextEditingController();
    final locationController = TextEditingController();
    final descriptionController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(S.newArea),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'ስም *'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: shortNameController,
                decoration:
                    const InputDecoration(labelText: 'አጭር ስም *'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: locationController,
                decoration:
                    InputDecoration(labelText: S.address),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descriptionController,
                decoration:
                    InputDecoration(labelText: S.description),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(S.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(S.create),
          ),
        ],
      ),
    );

    if (result == true) {
      final name = nameController.text.trim();
      final shortName = shortNameController.text.trim();

      if (name.isEmpty || shortName.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(S.nameAndShortRequired)),
          );
        }
        return;
      }

      try {
        final area = Area(
          id: '',
          name: name,
          shortName: shortName,
          location: locationController.text.trim(),
          description: descriptionController.text.trim(),
        );
        await _areaRepository.createArea(area);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(S.saveFailed)),
          );
        }
      }
    }

    nameController.dispose();
    shortNameController.dispose();
    locationController.dispose();
    descriptionController.dispose();
  }
}

class _AreaCard extends StatelessWidget {
  final Area area;
  final bool isDev;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onHide;
  final VoidCallback onDelete;

  const _AreaCard({
    required this.area,
    required this.isDev,
    required this.onTap,
    required this.onEdit,
    required this.onHide,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: area.isHidden
                      ? Colors.grey.withValues(alpha: 0.15)
                      : AppTheme.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.church,
                  color: area.isHidden ? Colors.grey : AppTheme.primary,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            area.name,
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              color: area.isHidden ? Colors.grey : null,
                            ),
                          ),
                        ),
                        if (area.isHidden)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.grey.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              S.hidden,
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (area.location.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        area.location,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (isDev)
                PopupMenuButton<String>(
                  onSelected: (value) {
                    switch (value) {
                      case 'edit':
                        onEdit();
                        break;
                      case 'hide':
                        onHide();
                        break;
                      case 'delete':
                        onDelete();
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'edit',
                      child: ListTile(
                        leading: const Icon(Icons.edit),
                        title: Text(S.edit),
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    PopupMenuItem(
                      value: 'hide',
                      child: ListTile(
                        leading: Icon(
                          area.isHidden
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                        title:
                            Text(area.isHidden ? S.unhideArea : S.hideArea),
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: ListTile(
                        leading:
                            const Icon(Icons.delete, color: Colors.red),
                        title: Text(S.delete,
                            style: const TextStyle(color: Colors.red)),
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                )
              else
                const Icon(Icons.chevron_right, color: AppTheme.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}
