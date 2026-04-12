import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:music/l10n/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/models/source_profile.dart';
import '../../../core/models/source_protocol.dart';
import '../../../core/widgets/studio_chrome.dart';
import '../../sources/data/cloud189/cloud189_api_client.dart';
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
  final _cloud189AppKeyController = TextEditingController();
  final _cloud189AppSecretController = TextEditingController();
  final _cloud189RedirectUriController = TextEditingController();
  final _cloud189AuthorizationCodeController = TextEditingController();
  final _rootPathController = TextEditingController(text: '/');

  final List<String> _scanDirectories = <String>[];
  final List<String> _excludedScanDirectories = <String>[];

  bool _obscurePassword = true;
  bool _didInitializeProfile = false;
  SourceProtocol _protocol = SourceProtocol.webdav;
  Cloud189AuthMode _cloud189AuthMode = Cloud189AuthMode.openListPassword;
  Cloud189TVLoginMode _cloud189TVLoginMode = Cloud189TVLoginMode.scanCode;
  final _cloud189DeviceIdController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _urlController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _cloud189AppKeyController.dispose();
    _cloud189AppSecretController.dispose();
    _cloud189RedirectUriController.dispose();
    _cloud189AuthorizationCodeController.dispose();
    _cloud189DeviceIdController.dispose();
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

    if (isEditing && editingProfile == null && !_didInitializeProfile) {
      return Scaffold(
        backgroundColor: colorScheme.surface.withValues(alpha: 0),
        body: StudioBackdrop(
          maxContentWidth: 980,
          padding: const EdgeInsets.all(16),
          child: SafeArea(
            child: _AddSourceEmptyState(
              title: l10n.settingsEditSourceTitle,
              description: l10n.sourceNotFoundMessage,
              actionLabel: MaterialLocalizations.of(context).backButtonTooltip,
              onPressed: () => context.pop(),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: colorScheme.surface.withValues(alpha: 0),
      body: StudioBackdrop(
        maxContentWidth: 1180,
        padding: const EdgeInsets.all(16),
        child: SafeArea(
          child: Form(
            key: _formKey,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: _AddSourceHero(
                    isEditing: isEditing,
                    protocol: _protocol,
                    scanDirectoryCount: _scanDirectories.length,
                    excludedDirectoryCount: _excludedScanDirectories.length,
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 18)),
                SliverToBoxAdapter(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final wide = constraints.maxWidth >= 1000;

                      return wide
                          ? Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: 10,
                                  child: _ConnectionFormDeck(
                                    nameController: _nameController,
                                    urlController: _urlController,
                                    usernameController: _usernameController,
                                    passwordController: _passwordController,
                                    cloud189AppKeyController: _cloud189AppKeyController,
                                    cloud189AppSecretController: _cloud189AppSecretController,
                                    cloud189RedirectUriController: _cloud189RedirectUriController,
                                    cloud189AuthorizationCodeController: _cloud189AuthorizationCodeController,
                                    rootPathController: _rootPathController,
                                    protocol: _protocol,
                                    cloud189AuthMode: _cloud189AuthMode,
                                    onProtocolChanged: (value) {
                                      setState(() {
                                        _protocol = value;
                                        if (value == SourceProtocol.cloudDrive && _nameController.text.trim().isEmpty) {
                                          _nameController.text = l10n.cloud189DefaultSourceName;
                                        }
                                      });
                                    },
                                    onCloud189AuthModeChanged: (value) {
                                      setState(() {
                                        _cloud189AuthMode = value;
                                      });
                                    },
                                    obscurePassword: _obscurePassword,
                                    onTogglePassword: () {
                                      setState(() {
                                        _obscurePassword = !_obscurePassword;
                                      });
                                    },
                                    onOpenCloud189Authorization: () => _openCloud189Authorization(context),
                                  ),
                                ),
                                const SizedBox(width: 18),
                                Expanded(
                                  flex: 8,
                                  child: _DirectoryDeck(
                                    scanDirectories: _scanDirectories,
                                    excludedScanDirectories: _excludedScanDirectories,
                                    onAddScanDirectory: () async {
                                      final result = await _promptDirectoryPath(
                                        context,
                                        title: l10n.addScanDirectoryDialogTitle,
                                        description: l10n.scanDirectoriesDialogDescription,
                                      );
                                      if (result == null) {
                                        return;
                                      }
                                      setState(() {
                                        _appendDirectory(_scanDirectories, result);
                                      });
                                    },
                                    onRemoveScanDirectory: (value) {
                                      setState(() {
                                        _scanDirectories.remove(value);
                                      });
                                    },
                                    onAddExcludedDirectory: () async {
                                      final result = await _promptDirectoryPath(
                                        context,
                                        title: l10n.addExcludedScanDirectoryDialogTitle,
                                        description: l10n.excludedScanDirectoriesDialogDescription,
                                      );
                                      if (result == null) {
                                        return;
                                      }
                                      setState(() {
                                        _appendDirectory(_excludedScanDirectories, result);
                                      });
                                    },
                                    onRemoveExcludedDirectory: (value) {
                                      setState(() {
                                        _excludedScanDirectories.remove(value);
                                      });
                                    },
                                  ),
                                ),
                              ],
                            )
                          : Column(
                              children: [
                                _ConnectionFormDeck(
                                  nameController: _nameController,
                                  urlController: _urlController,
                                  usernameController: _usernameController,
                                  passwordController: _passwordController,
                                  cloud189AppKeyController: _cloud189AppKeyController,
                                  cloud189AppSecretController: _cloud189AppSecretController,
                                  cloud189RedirectUriController: _cloud189RedirectUriController,
                                  cloud189AuthorizationCodeController: _cloud189AuthorizationCodeController,
                                  rootPathController: _rootPathController,
                                  protocol: _protocol,
                                  cloud189AuthMode: _cloud189AuthMode,
                                  onProtocolChanged: (value) {
                                    setState(() {
                                      _protocol = value;
                                      if (value == SourceProtocol.cloudDrive && _nameController.text.trim().isEmpty) {
                                        _nameController.text = l10n.cloud189DefaultSourceName;
                                      }
                                    });
                                  },
                                  onCloud189AuthModeChanged: (value) {
                                    setState(() {
                                      _cloud189AuthMode = value;
                                    });
                                  },
                                  obscurePassword: _obscurePassword,
                                  onTogglePassword: () {
                                    setState(() {
                                      _obscurePassword = !_obscurePassword;
                                    });
                                  },
                                  onOpenCloud189Authorization: () => _openCloud189Authorization(context),
                                ),
                                const SizedBox(height: 18),
                                _DirectoryDeck(
                                  scanDirectories: _scanDirectories,
                                  excludedScanDirectories: _excludedScanDirectories,
                                  onAddScanDirectory: () async {
                                    final result = await _promptDirectoryPath(
                                      context,
                                      title: l10n.addScanDirectoryDialogTitle,
                                      description: l10n.scanDirectoriesDialogDescription,
                                    );
                                    if (result == null) {
                                      return;
                                    }
                                    setState(() {
                                      _appendDirectory(_scanDirectories, result);
                                    });
                                  },
                                  onRemoveScanDirectory: (value) {
                                    setState(() {
                                      _scanDirectories.remove(value);
                                    });
                                  },
                                  onAddExcludedDirectory: () async {
                                    final result = await _promptDirectoryPath(
                                      context,
                                      title: l10n.addExcludedScanDirectoryDialogTitle,
                                      description: l10n.excludedScanDirectoriesDialogDescription,
                                    );
                                    if (result == null) {
                                      return;
                                    }
                                    setState(() {
                                      _appendDirectory(_excludedScanDirectories, result);
                                    });
                                  },
                                  onRemoveExcludedDirectory: (value) {
                                    setState(() {
                                      _excludedScanDirectories.remove(value);
                                    });
                                  },
                                ),
                              ],
                            );
                    },
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 18)),
                SliverToBoxAdapter(
                  child: StudioPanel(
                    radius: 36,
                    tint: colorScheme.surfaceContainerHighest,
                    child: Wrap(
                      spacing: 14,
                      runSpacing: 14,
                      children: [
                        OutlinedButton.icon(
                          onPressed: controllerState.isLoading
                              ? null
                              : () async {
                                  if (!_formKey.currentState!.validate()) {
                                    return;
                                  }

                                  final messenger = ScaffoldMessenger.of(context);

                                  try {
                                    if (_protocol == SourceProtocol.cloudDrive) {
                                      await controller.testCloud189Connection(
                                        _createCloud189Draft(),
                                        captchaResolver: _promptCloud189Captcha,
                                      );
                                    } else {
                                      await controller.testConnection(_createWebDavDraft());
                                    }
                                    if (!mounted) {
                                      return;
                                    }
                                    messenger.showSnackBar(SnackBar(content: Text(l10n.connectionTestSuccess)));
                                    await _showCloud189DebugLog(controller);
                                  } catch (_) {
                                    if (!mounted) {
                                      return;
                                    }
                                    messenger.showSnackBar(SnackBar(content: Text(_connectionFailedMessage(l10n))));
                                    await _showCloud189DebugLog(controller);
                                  }
                                },
                          icon: const Icon(Icons.wifi_find_rounded),
                          label: Text(l10n.testConnectionAction),
                        ),
                        FilledButton.icon(
                          onPressed: controllerState.isLoading
                              ? null
                              : () async {
                                  if (!_formKey.currentState!.validate()) {
                                    return;
                                  }

                                  final messenger = ScaffoldMessenger.of(context);
                                  final router = GoRouter.of(context);

                                  try {
                                    if (_protocol == SourceProtocol.cloudDrive) {
                                      await controller.saveCloud189Source(
                                        _createCloud189Draft(),
                                        captchaResolver: _promptCloud189Captcha,
                                      );
                                    } else {
                                      await controller.saveWebDavSource(_createWebDavDraft());
                                    }
                                    if (!mounted) {
                                      return;
                                    }
                                    messenger.showSnackBar(
                                      SnackBar(
                                        content: Text(isEditing ? l10n.sourceUpdatedSuccess : l10n.sourceSavedSuccess),
                                      ),
                                    );
                                    await _showCloud189DebugLog(controller);
                                    if (!mounted) {
                                      return;
                                    }
                                    router.pop();
                                  } catch (_) {
                                    if (!mounted) {
                                      return;
                                    }
                                    messenger.showSnackBar(SnackBar(content: Text(_connectionFailedMessage(l10n))));
                                    await _showCloud189DebugLog(controller);
                                  }
                                },
                          icon: controllerState.isLoading
                              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.save_rounded),
                          label: Text(isEditing ? l10n.saveSourceChangesAction : l10n.saveSourceAction),
                        ),
                      ],
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 20)),
              ],
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
    _protocol = profile.protocol;
    final cloud189Draft = profile.protocol == SourceProtocol.cloudDrive
        ? Cloud189SourceDraft.fromProfile(profile)
        : null;
    if (cloud189Draft != null) {
      _cloud189AuthMode = cloud189Draft.authMode;
      _cloud189TVLoginMode = cloud189Draft.tvLoginMode;
      _cloud189DeviceIdController.text = cloud189Draft.deviceId;
      _cloud189AppKeyController.text = cloud189Draft.appKey;
      _cloud189AppSecretController.text = cloud189Draft.appSecret;
      _cloud189RedirectUriController.text = cloud189Draft.redirectUri;
      _cloud189AuthorizationCodeController.text = cloud189Draft.authorizationCode;
    }
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

  Future<String?> _promptDirectoryPath(BuildContext context, {required String title, required String description}) {
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
            TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: Text(materialL10n.cancelButtonLabel)),
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

  String _connectionFailedMessage(AppLocalizations l10n) {
    return _protocol == SourceProtocol.cloudDrive ? l10n.cloud189ConnectionFailedMessage : l10n.connectionFailedMessage;
  }

  Future<void> _showCloud189DebugLog(AddSourceController controller) async {
    if (_protocol != SourceProtocol.cloudDrive || !mounted) {
      return;
    }

    final log = controller.connectionDebugLog().trim();
    if (log.isEmpty) {
      return;
    }

    final l10n = AppLocalizations.of(context)!;
    final materialL10n = MaterialLocalizations.of(context);
    final theme = Theme.of(context);
    final maxHeight = MediaQuery.sizeOf(context).height * 0.58;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(l10n.cloud189DebugLogDialogTitle),
          content: SizedBox(
            width: 640,
            height: maxHeight,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.cloud189DebugLogDialogDescription,
                  style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: SingleChildScrollView(
                    child: SelectableText(log, style: theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace')),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: Text(materialL10n.closeButtonLabel)),
          ],
        );
      },
    );
  }

  Future<String?> _promptCloud189Captcha(Uint8List captchaImageBytes) async {
    if (!mounted) {
      return null;
    }

    final l10n = AppLocalizations.of(context)!;
    final materialL10n = MaterialLocalizations.of(context);
    final codeController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    try {
      return await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return AlertDialog(
            title: Text(l10n.cloud189CaptchaDialogTitle),
            content: SizedBox(
              width: 420,
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.cloud189CaptchaDialogDescription),
                    const SizedBox(height: 16),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        color: Theme.of(dialogContext).colorScheme.surfaceContainerHighest,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Center(
                          child: Image.memory(
                            captchaImageBytes,
                            fit: BoxFit.contain,
                            filterQuality: FilterQuality.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: codeController,
                      autofocus: true,
                      textInputAction: TextInputAction.done,
                      decoration: InputDecoration(
                        labelText: l10n.cloud189CaptchaCodeLabel,
                        hintText: l10n.cloud189CaptchaCodeHint,
                      ),
                      validator: (value) {
                        if ((value ?? '').trim().isEmpty) {
                          return l10n.requiredFieldError;
                        }
                        return null;
                      },
                      onFieldSubmitted: (_) {
                        if (formKey.currentState?.validate() != true) {
                          return;
                        }
                        Navigator.of(dialogContext).pop(codeController.text.trim());
                      },
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text(materialL10n.cancelButtonLabel),
              ),
              FilledButton(
                onPressed: () {
                  if (formKey.currentState?.validate() != true) {
                    return;
                  }
                  Navigator.of(dialogContext).pop(codeController.text.trim());
                },
                child: Text(materialL10n.okButtonLabel),
              ),
            ],
          );
        },
      );
    } finally {
      codeController.dispose();
    }
  }

  Future<void> _openCloud189Authorization(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final appKey = _cloud189AppKeyController.text.trim();
    final redirectUri = _cloud189RedirectUriController.text.trim();
    if (appKey.isEmpty || redirectUri.isEmpty) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.cloud189AppAuthorizationConfigRequired)));
      return;
    }

    final uri = Uri.parse(Cloud189Constants.oauthAuthorizeUrl).replace(
      queryParameters: {
        'clientId': appKey,
        'responseType': 'code',
        'redirectUri': redirectUri,
        'state': DateTime.now().millisecondsSinceEpoch.toString(),
      },
    );
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!context.mounted) {
      return;
    }
    messenger.showSnackBar(
      SnackBar(
        content: Text(launched ? l10n.cloud189AuthorizationOpenedMessage : l10n.cloud189AuthorizationOpenFailedMessage),
      ),
    );
  }

  WebDavSourceDraft _createWebDavDraft() {
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

  Cloud189SourceDraft _createCloud189Draft() {
    return Cloud189SourceDraft(
      sourceId: widget.sourceId,
      name: _nameController.text,
      authMode: _cloud189AuthMode,
      username: _usernameController.text,
      refreshToken: _passwordController.text,
      appKey: _cloud189AppKeyController.text,
      appSecret: _cloud189AppSecretController.text,
      redirectUri: _cloud189RedirectUriController.text,
      authorizationCode: _cloud189AuthorizationCodeController.text,
      tvLoginMode: _cloud189TVLoginMode,
      deviceId: _cloud189DeviceIdController.text,
      rootPath: _rootPathController.text,
      scanDirectories: List<String>.from(_scanDirectories),
      excludedScanDirectories: List<String>.from(_excludedScanDirectories),
    );
  }
}

class _AddSourceHero extends StatelessWidget {
  const _AddSourceHero({
    required this.isEditing,
    required this.protocol,
    required this.scanDirectoryCount,
    required this.excludedDirectoryCount,
  });

  final bool isEditing;
  final SourceProtocol protocol;
  final int scanDirectoryCount;
  final int excludedDirectoryCount;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    return StudioPanel(
      radius: 40,
      tint: colorScheme.primaryContainer,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              StudioPanel(
                padding: EdgeInsets.zero,
                radius: 22,
                tint: colorScheme.surfaceContainerHighest,
                child: IconButton(onPressed: () => context.pop(), icon: const Icon(Icons.arrow_back_rounded)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: StudioSectionTitle(
                  eyebrow: (isEditing ? l10n.settingsEditSourceTitle : l10n.settingsAddSourceTitle).toUpperCase(),
                  title: isEditing ? l10n.settingsEditSourceTitle : l10n.settingsAddSourceTitle,
                  description: l10n.architectureReadyDescription,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 14,
            runSpacing: 14,
            children: [
              StudioStatBlock(
                icon: Icons.cloud_done_rounded,
                label: l10n.sourceProtocolLabel,
                value: protocol == SourceProtocol.cloudDrive ? l10n.cloud189Protocol : l10n.webdavProtocol,
              ),
              StudioStatBlock(
                icon: Icons.folder_special_rounded,
                label: l10n.scanDirectoriesTitle,
                value: '$scanDirectoryCount',
              ),
              StudioStatBlock(
                icon: Icons.block_rounded,
                label: l10n.excludedScanDirectoriesTitle,
                value: '$excludedDirectoryCount',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ConnectionFormDeck extends StatelessWidget {
  const _ConnectionFormDeck({
    required this.nameController,
    required this.urlController,
    required this.usernameController,
    required this.passwordController,
    required this.cloud189AppKeyController,
    required this.cloud189AppSecretController,
    required this.cloud189RedirectUriController,
    required this.cloud189AuthorizationCodeController,
    required this.rootPathController,
    required this.protocol,
    required this.cloud189AuthMode,
    required this.onProtocolChanged,
    required this.onCloud189AuthModeChanged,
    required this.obscurePassword,
    required this.onTogglePassword,
    required this.onOpenCloud189Authorization,
  });

  final TextEditingController nameController;
  final TextEditingController urlController;
  final TextEditingController usernameController;
  final TextEditingController passwordController;
  final TextEditingController cloud189AppKeyController;
  final TextEditingController cloud189AppSecretController;
  final TextEditingController cloud189RedirectUriController;
  final TextEditingController cloud189AuthorizationCodeController;
  final TextEditingController rootPathController;
  final SourceProtocol protocol;
  final Cloud189AuthMode cloud189AuthMode;
  final ValueChanged<SourceProtocol> onProtocolChanged;
  final ValueChanged<Cloud189AuthMode> onCloud189AuthModeChanged;
  final bool obscurePassword;
  final VoidCallback onTogglePassword;
  final VoidCallback onOpenCloud189Authorization;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final isCloud189 = protocol == SourceProtocol.cloudDrive;

    return StudioPanel(
      radius: 40,
      tint: colorScheme.surfaceContainerHighest,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StudioSectionTitle(
            eyebrow: l10n.sourceProtocolLabel.toUpperCase(),
            title: isCloud189 ? l10n.cloud189SourceTypeTitle : l10n.webdavSourceTypeTitle,
            description: isCloud189 ? l10n.cloud189SourceDescription : l10n.webdavSourceDescription,
          ),
          const SizedBox(height: 18),
          SegmentedButton<SourceProtocol>(
            segments: [
              ButtonSegment(
                value: SourceProtocol.webdav,
                icon: const Icon(Icons.dns_rounded),
                label: Text(l10n.webdavProtocol),
              ),
              ButtonSegment(
                value: SourceProtocol.cloudDrive,
                icon: const Icon(Icons.cloud_queue_rounded),
                label: Text(l10n.cloud189Protocol),
              ),
            ],
            selected: {protocol},
            onSelectionChanged: (selection) {
              onProtocolChanged(selection.first);
            },
          ),
          const SizedBox(height: 22),
          TextFormField(
            controller: nameController,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(labelText: l10n.sourceNameLabel, hintText: l10n.sourceNameHint),
          ),
          const SizedBox(height: 16),
          if (isCloud189) ...[
            SegmentedButton<Cloud189AuthMode>(
              segments: [
                ButtonSegment(
                  value: Cloud189AuthMode.openListPassword,
                  icon: const Icon(Icons.storage_rounded),
                  label: Text(l10n.cloud189OpenListModeLabel),
                ),
                ButtonSegment(
                  value: Cloud189AuthMode.appAuthorization,
                  icon: const Icon(Icons.app_settings_alt_rounded),
                  label: Text(l10n.cloud189AppAuthorizationModeLabel),
                ),
              ],
              selected: {cloud189AuthMode},
              onSelectionChanged: (selection) {
                onCloud189AuthModeChanged(selection.first);
              },
            ),
            const SizedBox(height: 16),
            Text(
              cloud189AuthMode == Cloud189AuthMode.openListPassword
                  ? l10n.cloud189OpenListModeDescription
                  : l10n.cloud189AppAuthorizationModeDescription,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            if (cloud189AuthMode == Cloud189AuthMode.openListPassword) ...[
              TextFormField(
                controller: usernameController,
                textInputAction: TextInputAction.next,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: l10n.cloud189OpenListUsernameLabel,
                  hintText: l10n.cloud189OpenListUsernameHint,
                  helperText: l10n.cloud189OpenListUsernameHelpText,
                ),
                validator: (value) {
                  if ((value ?? '').trim().isEmpty) {
                    return l10n.requiredFieldError;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: passwordController,
                obscureText: obscurePassword,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: l10n.cloud189OpenListPasswordLabel,
                  hintText: l10n.cloud189OpenListPasswordHint,
                  helperText: l10n.cloud189OpenListPasswordHelpText,
                  suffixIcon: IconButton(
                    onPressed: onTogglePassword,
                    icon: Icon(obscurePassword ? Icons.visibility_rounded : Icons.visibility_off_rounded),
                  ),
                ),
                validator: (value) {
                  if ((value ?? '').trim().isEmpty) {
                    return l10n.requiredFieldError;
                  }
                  return null;
                },
              ),
            ] else ...[
              TextFormField(
                controller: cloud189AppKeyController,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: l10n.cloud189AppKeyLabel,
                  hintText: l10n.cloud189AppKeyHint,
                  helperText: l10n.cloud189AppKeyHelpText,
                ),
                validator: (value) {
                  if ((value ?? '').trim().isEmpty) {
                    return l10n.requiredFieldError;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: cloud189AppSecretController,
                obscureText: obscurePassword,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: l10n.cloud189AppSecretLabel,
                  hintText: l10n.cloud189AppSecretHint,
                  suffixIcon: IconButton(
                    onPressed: onTogglePassword,
                    icon: Icon(obscurePassword ? Icons.visibility_rounded : Icons.visibility_off_rounded),
                  ),
                ),
                validator: (value) {
                  if ((value ?? '').trim().isEmpty) {
                    return l10n.requiredFieldError;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: cloud189RedirectUriController,
                textInputAction: TextInputAction.next,
                keyboardType: TextInputType.url,
                decoration: InputDecoration(
                  labelText: l10n.cloud189RedirectUriLabel,
                  hintText: l10n.cloud189RedirectUriHint,
                  helperText: l10n.cloud189RedirectUriHelpText,
                ),
                validator: (value) {
                  final trimmed = value?.trim() ?? '';
                  if (trimmed.isEmpty) {
                    return l10n.requiredFieldError;
                  }
                  final uri = Uri.tryParse(trimmed);
                  if (uri == null || !uri.hasScheme) {
                    return l10n.invalidUrlError;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              FilledButton.tonalIcon(
                onPressed: onOpenCloud189Authorization,
                icon: const Icon(Icons.open_in_new_rounded),
                label: Text(l10n.cloud189OpenAuthorizationAction),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: cloud189AuthorizationCodeController,
                minLines: 1,
                maxLines: 3,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: l10n.cloud189AuthorizationCodeLabel,
                  hintText: l10n.cloud189AuthorizationCodeHint,
                  helperText: l10n.cloud189AuthorizationCodeHelpText,
                ),
                validator: (value) {
                  final code = value?.trim() ?? '';
                  final token = passwordController.text.trim();
                  if (code.isEmpty && token.isEmpty) {
                    return l10n.cloud189AuthorizationCredentialRequiredError;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: passwordController,
                obscureText: obscurePassword,
                minLines: 1,
                maxLines: obscurePassword ? 1 : 4,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: l10n.cloud189AppRefreshTokenLabel,
                  hintText: l10n.cloud189AppRefreshTokenHint,
                  helperText: l10n.cloud189AppRefreshTokenHelpText,
                  suffixIcon: IconButton(
                    onPressed: onTogglePassword,
                    icon: Icon(obscurePassword ? Icons.visibility_rounded : Icons.visibility_off_rounded),
                  ),
                ),
              ),
            ],
          ] else ...[
            TextFormField(
              controller: urlController,
              textInputAction: TextInputAction.next,
              keyboardType: TextInputType.url,
              decoration: InputDecoration(labelText: l10n.serverUrlLabel, hintText: l10n.serverUrlHint),
              validator: (value) {
                final trimmed = value?.trim() ?? '';
                if (trimmed.isEmpty) {
                  return l10n.requiredFieldError;
                }
                final uri = Uri.tryParse(trimmed);
                if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
                  return l10n.invalidUrlError;
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: usernameController,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(labelText: l10n.usernameLabel),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: passwordController,
              obscureText: obscurePassword,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: l10n.passwordLabel,
                suffixIcon: IconButton(
                  onPressed: onTogglePassword,
                  icon: Icon(obscurePassword ? Icons.visibility_rounded : Icons.visibility_off_rounded),
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          TextFormField(
            controller: rootPathController,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              labelText: l10n.rootPathLabel,
              hintText: isCloud189 ? l10n.cloud189RootPathHint : l10n.rootPathHint,
              helperText: isCloud189 ? l10n.cloud189RootPathHelpText : l10n.rootPathHelpText,
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
    );
  }
}

class _DirectoryDeck extends StatelessWidget {
  const _DirectoryDeck({
    required this.scanDirectories,
    required this.excludedScanDirectories,
    required this.onAddScanDirectory,
    required this.onRemoveScanDirectory,
    required this.onAddExcludedDirectory,
    required this.onRemoveExcludedDirectory,
  });

  final List<String> scanDirectories;
  final List<String> excludedScanDirectories;
  final Future<void> Function() onAddScanDirectory;
  final ValueChanged<String> onRemoveScanDirectory;
  final Future<void> Function() onAddExcludedDirectory;
  final ValueChanged<String> onRemoveExcludedDirectory;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    return StudioPanel(
      radius: 40,
      tint: colorScheme.surfaceContainerHighest,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StudioSectionTitle(
            eyebrow: l10n.scanDirectoriesTitle.toUpperCase(),
            title: l10n.scanDirectoriesTitle,
            description: l10n.scanDirectoriesDescription,
          ),
          const SizedBox(height: 18),
          _PathGroupEditor(
            title: l10n.scanDirectoriesTitle,
            description: l10n.scanDirectoriesDescription,
            emptyDescription: l10n.scanDirectoriesDefaultRootDescription,
            addActionLabel: l10n.addScanDirectoryAction,
            entries: scanDirectories,
            onAdd: onAddScanDirectory,
            onRemove: onRemoveScanDirectory,
          ),
          const SizedBox(height: 24),
          _PathGroupEditor(
            title: l10n.excludedScanDirectoriesTitle,
            description: l10n.excludedScanDirectoriesDescription,
            emptyDescription: l10n.excludedScanDirectoriesEmptyDescription,
            addActionLabel: l10n.addExcludedScanDirectoryAction,
            entries: excludedScanDirectories,
            onAdd: onAddExcludedDirectory,
            onRemove: onRemoveExcludedDirectory,
          ),
        ],
      ),
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 6),
                  Text(description, style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            FilledButton.tonalIcon(onPressed: onAdd, icon: const Icon(Icons.add_rounded), label: Text(addActionLabel)),
          ],
        ),
        const SizedBox(height: 14),
        if (entries.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.surface.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.28)),
            ),
            child: Text(
              emptyDescription,
              style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
          )
        else
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [for (final entry in entries) InputChip(label: Text(entry), onDeleted: () => onRemove(entry))],
          ),
      ],
    );
  }
}

class _AddSourceEmptyState extends StatelessWidget {
  const _AddSourceEmptyState({
    required this.title,
    required this.description,
    required this.actionLabel,
    required this.onPressed,
  });

  final String title;
  final String description;
  final String actionLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 700),
        child: StudioPanel(
          radius: 40,
          tint: colorScheme.primaryContainer,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: Theme.of(context).textTheme.displaySmall, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              Text(
                description,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: colorScheme.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 22),
              FilledButton.icon(
                onPressed: onPressed,
                icon: const Icon(Icons.arrow_back_rounded),
                label: Text(actionLabel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
