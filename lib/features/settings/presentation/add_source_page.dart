import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:music/l10n/app_localizations.dart';

import '../../../core/models/source_profile.dart';
import '../../sources/application/sources_controller.dart';
import '../application/add_source_controller.dart';

class AddSourcePage extends ConsumerStatefulWidget {
  const AddSourcePage({super.key, this.sourceId});

  final String? sourceId;

  @override
  ConsumerState<AddSourcePage> createState() => _AddSourcePageState();
}

class _AddSourcePageState extends ConsumerState<AddSourcePage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _urlController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _rootPathController = TextEditingController(text: '/');

  final List<String> _scanDirectories = <String>[];
  final List<String> _excludedScanDirectories = <String>[];

  bool _obscurePassword = true;
  bool _didInitializeProfile = false;

  @override
  void dispose() {
    _nameController.dispose();
    _urlController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _rootPathController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final controllerState = ref.watch(addSourceControllerProvider);
    final controller = ref.read(addSourceControllerProvider.notifier);
    final sourcesAsync = ref.watch(sourcesControllerProvider);
    final editingProfile = _resolveEditingProfile(sourcesAsync.valueOrNull);
    final isEditing = widget.sourceId != null;

    if (!_didInitializeProfile && editingProfile != null) {
      _populateFromProfile(editingProfile);
    }

    if (isEditing && sourcesAsync.isLoading && !_didInitializeProfile) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (isEditing && editingProfile == null && _didInitializeProfile == false) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.settingsEditSourceTitle)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              l10n.sourceNotFoundMessage,
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isEditing
              ? l10n.settingsEditSourceTitle
              : l10n.settingsAddSourceTitle,
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.architectureReadyTitle,
                              style: theme.textTheme.headlineSmall,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              l10n.architectureReadyDescription,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: [
                                Chip(
                                  avatar: const Icon(Icons.cloud_done_rounded),
                                  label: Text(l10n.webdavProtocol),
                                ),
                                Chip(
                                  avatar: const Icon(
                                    Icons.folder_special_rounded,
                                  ),
                                  label: Text(l10n.scanDirectoriesTitle),
                                ),
                                Chip(
                                  avatar: const Icon(Icons.block_rounded),
                                  label: Text(
                                    l10n.excludedScanDirectoriesTitle,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            TextFormField(
                              controller: _nameController,
                              textInputAction: TextInputAction.next,
                              decoration: InputDecoration(
                                labelText: l10n.sourceNameLabel,
                                hintText: l10n.sourceNameHint,
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _urlController,
                              textInputAction: TextInputAction.next,
                              keyboardType: TextInputType.url,
                              decoration: InputDecoration(
                                labelText: l10n.serverUrlLabel,
                                hintText: l10n.serverUrlHint,
                              ),
                              validator: (value) {
                                final trimmed = value?.trim() ?? '';
                                if (trimmed.isEmpty) {
                                  return l10n.requiredFieldError;
                                }
                                final uri = Uri.tryParse(trimmed);
                                if (uri == null ||
                                    !uri.hasScheme ||
                                    !uri.hasAuthority) {
                                  return l10n.invalidUrlError;
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _usernameController,
                              textInputAction: TextInputAction.next,
                              decoration: InputDecoration(
                                labelText: l10n.usernameLabel,
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              textInputAction: TextInputAction.next,
                              decoration: InputDecoration(
                                labelText: l10n.passwordLabel,
                                suffixIcon: IconButton(
                                  onPressed: () {
                                    setState(() {
                                      _obscurePassword = !_obscurePassword;
                                    });
                                  },
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_rounded
                                        : Icons.visibility_off_rounded,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _rootPathController,
                              textInputAction: TextInputAction.done,
                              decoration: InputDecoration(
                                labelText: l10n.rootPathLabel,
                                hintText: l10n.rootPathHint,
                                helperText: l10n.rootPathHelpText,
                              ),
                              validator: (value) {
                                final trimmed = value?.trim() ?? '';
                                if (trimmed.isEmpty) {
                                  return l10n.requiredFieldError;
                                }
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _PathGroupEditor(
                              title: l10n.scanDirectoriesTitle,
                              description: l10n.scanDirectoriesDescription,
                              emptyDescription:
                                  l10n.scanDirectoriesDefaultRootDescription,
                              addActionLabel: l10n.addScanDirectoryAction,
                              entries: _scanDirectories,
                              onAdd: () async {
                                final result = await _promptDirectoryPath(
                                  context,
                                  title: l10n.addScanDirectoryDialogTitle,
                                  description:
                                      l10n.scanDirectoriesDialogDescription,
                                );
                                if (result == null) {
                                  return;
                                }
                                setState(() {
                                  _appendDirectory(_scanDirectories, result);
                                });
                              },
                              onRemove: (value) {
                                setState(() {
                                  _scanDirectories.remove(value);
                                });
                              },
                            ),
                            const SizedBox(height: 24),
                            _PathGroupEditor(
                              title: l10n.excludedScanDirectoriesTitle,
                              description:
                                  l10n.excludedScanDirectoriesDescription,
                              emptyDescription:
                                  l10n.excludedScanDirectoriesEmptyDescription,
                              addActionLabel:
                                  l10n.addExcludedScanDirectoryAction,
                              entries: _excludedScanDirectories,
                              onAdd: () async {
                                final result = await _promptDirectoryPath(
                                  context,
                                  title:
                                      l10n.addExcludedScanDirectoryDialogTitle,
                                  description: l10n
                                      .excludedScanDirectoriesDialogDescription,
                                );
                                if (result == null) {
                                  return;
                                }
                                setState(() {
                                  _appendDirectory(
                                    _excludedScanDirectories,
                                    result,
                                  );
                                });
                              },
                              onRemove: (value) {
                                setState(() {
                                  _excludedScanDirectories.remove(value);
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: controllerState.isLoading
                                ? null
                                : () async {
                                    if (!_formKey.currentState!.validate()) {
                                      return;
                                    }

                                    final messenger = ScaffoldMessenger.of(
                                      context,
                                    );

                                    try {
                                      await controller.testConnection(
                                        _createDraft(),
                                      );
                                      if (!mounted) {
                                        return;
                                      }
                                      messenger.showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            l10n.connectionTestSuccess,
                                          ),
                                        ),
                                      );
                                    } catch (_) {
                                      if (!mounted) {
                                        return;
                                      }
                                      messenger.showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            l10n.connectionFailedMessage,
                                          ),
                                        ),
                                      );
                                    }
                                  },
                            child: Text(l10n.testConnectionAction),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: FilledButton(
                            onPressed: controllerState.isLoading
                                ? null
                                : () async {
                                    if (!_formKey.currentState!.validate()) {
                                      return;
                                    }

                                    final messenger = ScaffoldMessenger.of(
                                      context,
                                    );
                                    final router = GoRouter.of(context);

                                    try {
                                      await controller.saveWebDavSource(
                                        _createDraft(),
                                      );
                                      if (!mounted) {
                                        return;
                                      }
                                      messenger.showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            isEditing
                                                ? l10n.sourceUpdatedSuccess
                                                : l10n.sourceSavedSuccess,
                                          ),
                                        ),
                                      );
                                      router.pop();
                                    } catch (_) {
                                      if (!mounted) {
                                        return;
                                      }
                                      messenger.showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            l10n.connectionFailedMessage,
                                          ),
                                        ),
                                      );
                                    }
                                  },
                            child: controllerState.isLoading
                                ? const SizedBox(
                                    height: 18,
                                    width: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(
                                    isEditing
                                        ? l10n.saveSourceChangesAction
                                        : l10n.saveSourceAction,
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  SourceProfile? _resolveEditingProfile(List<SourceProfile>? sources) {
    final sourceId = widget.sourceId;
    if (sourceId == null || sources == null) {
      return null;
    }

    for (final source in sources) {
      if (source.id == sourceId) {
        return source;
      }
    }

    return null;
  }

  void _populateFromProfile(SourceProfile profile) {
    _didInitializeProfile = true;
    _nameController.text = profile.name;
    _urlController.text = profile.baseUrl;
    _usernameController.text = profile.username;
    _passwordController.text = profile.password;
    _rootPathController.text = profile.rootPath;
    _scanDirectories
      ..clear()
      ..addAll(profile.normalizedScanDirectories);
    _excludedScanDirectories
      ..clear()
      ..addAll(profile.normalizedExcludedScanDirectories);
  }

  void _appendDirectory(List<String> directories, String value) {
    var normalized = value.trim();
    if (!normalized.startsWith('/')) {
      normalized = '/$normalized';
    }
    if (!normalized.endsWith('/')) {
      normalized = '$normalized/';
    }

    if (!directories.contains(normalized)) {
      directories.add(normalized);
    }
  }

  Future<String?> _promptDirectoryPath(
    BuildContext context, {
    required String title,
    required String description,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final materialL10n = MaterialLocalizations.of(context);
    final controller = TextEditingController(text: '/');

    return showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(description),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: l10n.directoryPathLabel,
                    hintText: l10n.directoryPathHint,
                    helperText: l10n.directoryPathHelpText,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(materialL10n.cancelButtonLabel),
            ),
            FilledButton(
              onPressed: () {
                final trimmed = controller.text.trim();
                if (trimmed.isEmpty) {
                  return;
                }
                Navigator.of(dialogContext).pop(trimmed);
              },
              child: Text(materialL10n.okButtonLabel),
            ),
          ],
        );
      },
    );
  }

  WebDavSourceDraft _createDraft() {
    return WebDavSourceDraft(
      sourceId: widget.sourceId,
      name: _nameController.text,
      baseUrl: _urlController.text,
      username: _usernameController.text,
      password: _passwordController.text,
      rootPath: _rootPathController.text,
      scanDirectories: List<String>.from(_scanDirectories),
      excludedScanDirectories: List<String>.from(_excludedScanDirectories),
    );
  }
}

class _PathGroupEditor extends StatelessWidget {
  const _PathGroupEditor({
    required this.title,
    required this.description,
    required this.emptyDescription,
    required this.addActionLabel,
    required this.entries,
    required this.onAdd,
    required this.onRemove,
  });

  final String title;
  final String description;
  final String emptyDescription;
  final String addActionLabel;
  final List<String> entries;
  final Future<void> Function() onAdd;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 6),
                  Text(
                    description,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            FilledButton.tonalIcon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded),
              label: Text(addActionLabel),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (entries.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: colorScheme.outlineVariant),
            ),
            child: Text(
              emptyDescription,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          )
        else
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final entry in entries)
                InputChip(label: Text(entry), onDeleted: () => onRemove(entry)),
            ],
          ),
      ],
    );
  }
}
