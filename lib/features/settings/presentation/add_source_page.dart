import 'dart:async';
import 'dart:math' as math;

import 'package:file_selector/file_selector.dart' as file_selector;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:music/core/i18n/localizations.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/models/source_profile.dart';
import '../../../core/models/source_protocol.dart';
import '../../../core/utils/path_nesting_validator.dart';
import '../../../core/widgets/glacier_dialog.dart';
import '../../../core/widgets/studio_chrome.dart';
import '../../../core/widgets/top_snackbar.dart';
import '../../library/application/library_catalog_controller.dart';
import '../../sources/data/cloud189/cloud189_api_client.dart';
import '../../sources/application/sources_controller.dart';
import '../application/add_source_controller.dart';
import '../application/app_settings_controller.dart';

final Set<NavigatorState> _activePickers = <NavigatorState>{};

Future<void> showSourceTypePicker(BuildContext context) async {
  final navigator = Navigator.of(context, rootNavigator: true);
  if (_activePickers.contains(navigator)) {
    return;
  }
  _activePickers.add(navigator);
  try {
    await showDialog<void>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      builder: (dialogContext) => ProviderScope(
        overrides: [
          addSourceControllerProvider.overrideWith(AddSourceController.new),
        ],
        child: const _AddSourceDialog(),
      ),
    );
  } finally {
    _activePickers.remove(navigator);
  }
}

class _AddSourceDialog extends StatefulWidget {
  const _AddSourceDialog();

  @override
  State<_AddSourceDialog> createState() => _AddSourceDialogState();
}

class _AddSourceDialogState extends State<_AddSourceDialog> {
  SourceProtocol? _selectedProtocol;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final protocols = _availableSourceProtocols();
    final mediaQuery = MediaQuery.of(context);
    final availableHeight =
        mediaQuery.size.height -
        mediaQuery.padding.vertical -
        mediaQuery.viewInsets.bottom;
    final maxDialogHeight = availableHeight * 0.85;

    return Dialog(
      key: const Key('add-source-dialog'),
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: AnimatedContainer(
        duration: mediaQuery.disableAnimations
            ? Duration.zero
            : const Duration(milliseconds: 180),
        constraints: BoxConstraints(maxWidth: 640, maxHeight: maxDialogHeight),
        child: Material(
          color: colorScheme.surfaceContainerHigh.withValues(
            alpha: isDark ? 0.94 : 0.98,
          ),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
            side: BorderSide(
              color: colorScheme.outlineVariant.withValues(
                alpha: isDark ? 0.42 : 0.62,
              ),
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: AnimatedSwitcher(
            duration: mediaQuery.disableAnimations
                ? Duration.zero
                : const Duration(milliseconds: 200),
            switchInCurve: const Cubic(0.2, 0.0, 0.0, 1.0),
            switchOutCurve: const Cubic(0.2, 0.0, 0.0, 1.0),
            transitionBuilder: (child, animation) {
              return FadeTransition(opacity: animation, child: child);
            },
            child: _selectedProtocol == null
                ? PopScope(
                    key: const ValueKey('step-protocol-chooser'),
                    canPop: true,
                    child: Shortcuts(
                      shortcuts: <ShortcutActivator, Intent>{
                        LogicalKeySet(LogicalKeyboardKey.escape):
                            const DismissIntent(),
                      },
                      child: Actions(
                        actions: <Type, Action<Intent>>{
                          DismissIntent: CallbackAction<DismissIntent>(
                            onInvoke: (_) => Navigator.of(context).pop(),
                          ),
                        },
                        child: _buildProtocolSelectionStep(
                          context,
                          l10n,
                          colorScheme,
                          protocols,
                        ),
                      ),
                    ),
                  )
                : AddSourcePage(
                    key: const Key('source-config-step'),
                    initialProtocol: _selectedProtocol!,
                    embedded: true,
                    onBack: () => setState(() => _selectedProtocol = null),
                    onClose: () => Navigator.of(context).pop(),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildProtocolSelectionStep(
    BuildContext context,
    AppLocalizations l10n,
    ColorScheme colorScheme,
    List<SourceProtocol> protocols,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 12, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  l10n.settingsAddSourceTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                key: const Key('add-source-close'),
                tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
        Expanded(
          child: Container(
            key: const Key('source-type-step'),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              children: [
                Text(
                  l10n.sourceTypeSelectionTitle,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.sourceTypeSelectionDescription,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 14),
                for (final protocol in protocols) ...[
                  _SourceTypeCard(
                    protocol: protocol,
                    onTap: () {
                      setState(() {
                        _selectedProtocol = protocol;
                      });
                    },
                  ),
                  const SizedBox(height: 10),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class SourceTypeSelectionPage extends StatelessWidget {
  const SourceTypeSelectionPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final protocols = _availableSourceProtocols();

    return Scaffold(
      backgroundColor: colorScheme.surface.withValues(alpha: 0),
      body: StudioBackdrop(
        maxContentWidth: 860,
        padding: const EdgeInsets.all(16),
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: StudioPanel(
                  radius: 36,
                  tint: colorScheme.primaryContainer,
                  child: Row(
                    children: [
                      StudioPanel(
                        padding: EdgeInsets.zero,
                        radius: 22,
                        tint: colorScheme.surfaceContainerHighest,
                        child: IconButton(
                          onPressed: () => context.pop(),
                          icon: const Icon(Icons.arrow_back_rounded),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: StudioSectionTitle(
                          eyebrow: l10n.sourceProtocolLabel.toUpperCase(),
                          title: l10n.sourceTypeSelectionTitle,
                          description: l10n.sourceTypeSelectionDescription,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 16)),
              SliverList.separated(
                itemCount: protocols.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final protocol = protocols[index];
                  return _SourceTypeCard(
                    protocol: protocol,
                    onTap: () => context.push(
                      '/settings/add-source/${protocol.storageValue}',
                    ),
                  );
                },
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 20)),
            ],
          ),
        ),
      ),
    );
  }
}

class AddSourcePage extends ConsumerStatefulWidget {
  const AddSourcePage({
    super.key,
    this.sourceId,
    this.initialProtocol = SourceProtocol.webdav,
    this.embedded = false,
    this.onBack,
    this.onClose,
  });

  final String? sourceId;
  final SourceProtocol initialProtocol;
  final bool embedded;
  final VoidCallback? onBack;
  final VoidCallback? onClose;

  @override
  ConsumerState<AddSourcePage> createState() => _AddSourcePageState();
}

@immutable
class _AddSourceFormSnapshot {
  const _AddSourceFormSnapshot({
    required this.name,
    required this.baseUrl,
    required this.username,
    required this.password,
    required this.rootPath,
    required this.protocol,
    required this.cloud189AuthMode,
    required this.cloud189TVLoginMode,
    required this.cloud189DeviceId,
    required this.cloud189AppKey,
    required this.cloud189AppSecret,
    required this.cloud189RedirectUri,
    required this.cloud189AuthorizationCode,
    required this.scanDirectories,
    required this.excludedScanDirectories,
  });

  final String name;
  final String baseUrl;
  final String username;
  final String password;
  final String rootPath;
  final SourceProtocol protocol;
  final Cloud189AuthMode cloud189AuthMode;
  final Cloud189TVLoginMode cloud189TVLoginMode;
  final String cloud189DeviceId;
  final String cloud189AppKey;
  final String cloud189AppSecret;
  final String cloud189RedirectUri;
  final String cloud189AuthorizationCode;
  final List<String> scanDirectories;
  final List<String> excludedScanDirectories;

  bool matches({
    required String name,
    required String baseUrl,
    required String username,
    required String password,
    required String rootPath,
    required SourceProtocol protocol,
    required Cloud189AuthMode cloud189AuthMode,
    required Cloud189TVLoginMode cloud189TVLoginMode,
    required String cloud189DeviceId,
    required String cloud189AppKey,
    required String cloud189AppSecret,
    required String cloud189RedirectUri,
    required String cloud189AuthorizationCode,
    required List<String> scanDirectories,
    required List<String> excludedScanDirectories,
  }) {
    return this.name == name &&
        this.baseUrl == baseUrl &&
        this.username == username &&
        this.password == password &&
        this.rootPath == rootPath &&
        this.protocol == protocol &&
        this.cloud189AuthMode == cloud189AuthMode &&
        this.cloud189TVLoginMode == cloud189TVLoginMode &&
        this.cloud189DeviceId == cloud189DeviceId &&
        this.cloud189AppKey == cloud189AppKey &&
        this.cloud189AppSecret == cloud189AppSecret &&
        this.cloud189RedirectUri == cloud189RedirectUri &&
        this.cloud189AuthorizationCode == cloud189AuthorizationCode &&
        listEquals(this.scanDirectories, scanDirectories) &&
        listEquals(this.excludedScanDirectories, excludedScanDirectories);
  }
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
  late SourceProtocol _protocol;
  Cloud189AuthMode _cloud189AuthMode = Cloud189AuthMode.openListPassword;
  Cloud189TVLoginMode _cloud189TVLoginMode = Cloud189TVLoginMode.scanCode;
  final _cloud189DeviceIdController = TextEditingController();

  late final String _draftSourceId;
  int _currentOpId = 0;
  bool _isShowingConfirmDialog = false;
  bool _isClosedOrDisposed = false;
  final Set<Route<dynamic>> _activeAuxiliaryRoutes = <Route<dynamic>>{};
  AddSourceController? _scopedController;
  _AddSourceFormSnapshot? _initialSnapshot;

  @override
  void initState() {
    super.initState();
    _protocol = SourceProtocolX.sanitizeForCurrentPlatform(
      widget.initialProtocol,
    );
    _draftSourceId =
        widget.sourceId ??
        '${_protocol.storageValue}_${DateTime.now().microsecondsSinceEpoch}';
    if (widget.sourceId == null) {
      _initialSnapshot = _takeSnapshot();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scopedController = ref.read(addSourceControllerProvider.notifier);
  }

  void _dismissOwnedAuxiliaryRoutes() {
    for (final route in _activeAuxiliaryRoutes.toList()) {
      if (route.isActive) {
        route.navigator?.removeRoute(route);
      }
    }
    _activeAuxiliaryRoutes.clear();
  }

  Future<T?> _showOwnedDialog<T>({
    required BuildContext context,
    required WidgetBuilder builder,
    bool barrierDismissible = true,
  }) async {
    if (!mounted || _isClosedOrDisposed) return null;
    final capturedRoute = DialogRoute<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: builder,
    );
    _activeAuxiliaryRoutes.add(capturedRoute);
    capturedRoute.completed.whenComplete(() {
      _activeAuxiliaryRoutes.remove(capturedRoute);
    });
    return Navigator.of(context, rootNavigator: false).push<T>(capturedRoute);
  }

  @override
  void dispose() {
    _currentOpId++;
    _isClosedOrDisposed = true;
    _dismissOwnedAuxiliaryRoutes();
    // Do NOT call ref.read in dispose!
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

  _AddSourceFormSnapshot _takeSnapshot() {
    return _AddSourceFormSnapshot(
      name: _nameController.text,
      baseUrl: _urlController.text,
      username: _usernameController.text,
      password: _passwordController.text,
      rootPath: _rootPathController.text,
      protocol: _protocol,
      cloud189AuthMode: _cloud189AuthMode,
      cloud189TVLoginMode: _cloud189TVLoginMode,
      cloud189DeviceId: _cloud189DeviceIdController.text,
      cloud189AppKey: _cloud189AppKeyController.text,
      cloud189AppSecret: _cloud189AppSecretController.text,
      cloud189RedirectUri: _cloud189RedirectUriController.text,
      cloud189AuthorizationCode: _cloud189AuthorizationCodeController.text,
      scanDirectories: List<String>.from(_scanDirectories),
      excludedScanDirectories: List<String>.from(_excludedScanDirectories),
    );
  }

  bool _isFormDirty() {
    if (_initialSnapshot == null) {
      return false;
    }
    return !_initialSnapshot!.matches(
      name: _nameController.text,
      baseUrl: _urlController.text,
      username: _usernameController.text,
      password: _passwordController.text,
      rootPath: _rootPathController.text,
      protocol: _protocol,
      cloud189AuthMode: _cloud189AuthMode,
      cloud189TVLoginMode: _cloud189TVLoginMode,
      cloud189DeviceId: _cloud189DeviceIdController.text,
      cloud189AppKey: _cloud189AppKeyController.text,
      cloud189AppSecret: _cloud189AppSecretController.text,
      cloud189RedirectUri: _cloud189RedirectUriController.text,
      cloud189AuthorizationCode: _cloud189AuthorizationCodeController.text,
      scanDirectories: _scanDirectories,
      excludedScanDirectories: _excludedScanDirectories,
    );
  }

  Future<bool> _shouldDiscard() async {
    final controller =
        _scopedController ??
        (mounted ? ref.read(addSourceControllerProvider.notifier) : null);
    if (controller?.isCommitting == true) {
      return false;
    }
    if (_isShowingConfirmDialog) {
      return false;
    }
    if (!_isFormDirty()) {
      return true;
    }
    _isShowingConfirmDialog = true;
    try {
      final l10n = AppLocalizations.of(context)!;
      final result = await _showOwnedDialog<bool>(
        context: context,
        builder: (dialogContext) => GlacierDialog(
          title: Text(l10n.discardChangesConfirmationTitle),
          content: Text(l10n.discardChangesConfirmationDescription),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.continueEditingAction),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(l10n.discardChangesAction),
            ),
          ],
        ),
      );
      return result ?? false;
    } finally {
      _isShowingConfirmDialog = false;
    }
  }

  Future<void> _handleBack() async {
    if (_isClosedOrDisposed) return;
    final controller =
        _scopedController ??
        (mounted ? ref.read(addSourceControllerProvider.notifier) : null);
    if (controller?.isCommitting == true) {
      return;
    }
    final opId = ++_currentOpId;
    controller?.cancelPendingOperation();
    final shouldDiscard = await _shouldDiscard();
    if (!mounted || _isClosedOrDisposed || opId != _currentOpId) {
      return;
    }
    if (shouldDiscard) {
      _isClosedOrDisposed = true;
      _dismissOwnedAuxiliaryRoutes();
      if (mounted) {
        setState(() {});
      }
      if (widget.onBack != null) {
        widget.onBack!();
      } else {
        context.pop();
      }
    }
  }

  Future<void> _handleClose() async {
    if (_isClosedOrDisposed) return;
    final controller =
        _scopedController ??
        (mounted ? ref.read(addSourceControllerProvider.notifier) : null);
    if (controller?.isCommitting == true) {
      return;
    }
    final opId = ++_currentOpId;
    controller?.cancelPendingOperation();
    final shouldDiscard = await _shouldDiscard();
    if (!mounted || _isClosedOrDisposed || opId != _currentOpId) {
      return;
    }
    if (shouldDiscard) {
      _isClosedOrDisposed = true;
      _dismissOwnedAuxiliaryRoutes();
      if (mounted) {
        setState(() {});
      }
      if (widget.onClose != null) {
        widget.onClose!();
      } else {
        context.pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
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
        backgroundColor: colorScheme.surface,
        body: SafeArea(
          child: _AddSourceEmptyState(
            title: l10n.settingsEditSourceTitle,
            description: l10n.sourceNotFoundMessage,
            actionLabel: MaterialLocalizations.of(context).backButtonTooltip,
            onPressed: () => context.pop(),
          ),
        ),
      );
    }

    final isBusy = controllerState.isLoading || controller.isCommitting;

    final formContent = Form(
      key: _formKey,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isLargeFont =
              MediaQuery.textScalerOf(context).scale(14.0) > 18.0;
          final isCompact =
              constraints.maxWidth < 300 ||
              constraints.maxHeight < 400 ||
              isLargeFont;

          final header = isCompact
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (widget.embedded && widget.onBack != null) ...[
                      IconButton(
                        key: const Key('add-source-back'),
                        tooltip: MaterialLocalizations.of(
                          context,
                        ).backButtonTooltip,
                        constraints: const BoxConstraints(
                          minWidth: 48,
                          minHeight: 48,
                        ),
                        icon: const Icon(Icons.arrow_back_rounded),
                        onPressed: controller.isCommitting ? null : _handleBack,
                      ),
                      const SizedBox(width: 4),
                    ],
                    Expanded(
                      child: Text(
                        isEditing
                            ? l10n.settingsEditSourceTitle
                            : l10n.settingsAddSourceTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      key: const Key('add-source-close'),
                      tooltip: MaterialLocalizations.of(
                        context,
                      ).closeButtonTooltip,
                      constraints: const BoxConstraints(
                        minWidth: 48,
                        minHeight: 48,
                      ),
                      icon: const Icon(Icons.close_rounded),
                      onPressed: controller.isCommitting ? null : _handleClose,
                    ),
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (widget.embedded && widget.onBack != null) ...[
                      IconButton(
                        key: const Key('add-source-back'),
                        tooltip: MaterialLocalizations.of(
                          context,
                        ).backButtonTooltip,
                        constraints: const BoxConstraints(
                          minWidth: 48,
                          minHeight: 48,
                        ),
                        icon: const Icon(Icons.arrow_back_rounded),
                        onPressed: controller.isCommitting ? null : _handleBack,
                      ),
                      const SizedBox(width: 4),
                    ],
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: colorScheme.primary.withValues(alpha: 0.1),
                        border: Border.all(
                          color: colorScheme.primary.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Icon(
                        _protocolIcon(_protocol),
                        color: colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            isEditing
                                ? l10n.settingsEditSourceTitle
                                : l10n.settingsAddSourceTitle,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _sourceTypeTitle(l10n, _protocol),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      key: const Key('add-source-close'),
                      tooltip: MaterialLocalizations.of(
                        context,
                      ).closeButtonTooltip,
                      constraints: const BoxConstraints(
                        minWidth: 48,
                        minHeight: 48,
                      ),
                      icon: const Icon(Icons.close_rounded),
                      onPressed: controller.isCommitting ? null : _handleClose,
                    ),
                  ],
                );

          final decks = <Widget>[
            if (isCompact) ...[
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: colorScheme.primary.withValues(alpha: 0.1),
                      border: Border.all(
                        color: colorScheme.primary.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Icon(
                      _protocolIcon(_protocol),
                      size: 18,
                      color: colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _sourceTypeTitle(l10n, _protocol),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
            _ConnectionFormDeck(
              nameController: _nameController,
              urlController: _urlController,
              usernameController: _usernameController,
              passwordController: _passwordController,
              cloud189AppKeyController: _cloud189AppKeyController,
              cloud189AppSecretController: _cloud189AppSecretController,
              cloud189RedirectUriController: _cloud189RedirectUriController,
              cloud189AuthorizationCodeController:
                  _cloud189AuthorizationCodeController,
              rootPathController: _rootPathController,
              protocol: _protocol,
              cloud189AuthMode: _cloud189AuthMode,
              onProtocolChanged: (value) => _setProtocol(l10n, value),
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
              onOpenCloud189Authorization: () =>
                  _openCloud189Authorization(context),
              enabled: !isBusy,
            ),
            const SizedBox(height: 12),
            _DirectoryDeck(
              scanDirectories: _scanDirectories,
              excludedScanDirectories: _excludedScanDirectories,
              onAddScanDirectory: isBusy
                  ? null
                  : () async {
                      if (_protocol == SourceProtocol.local) {
                        await _addLocalScanDirectory(l10n);
                        return;
                      }
                      final opId = _currentOpId;
                      final result = await _promptDirectoryPath(
                        context,
                        title: l10n.addScanDirectoryDialogTitle,
                        description: l10n.scanDirectoriesDialogDescription,
                      );
                      if (!mounted ||
                          _isClosedOrDisposed ||
                          opId != _currentOpId ||
                          result == null) {
                        return;
                      }
                      final conflict = PathNestingValidator.findConflict(
                        result,
                        _scanDirectories,
                      );
                      if (conflict != null) {
                        if (!mounted) return;
                        showTopSnackBar(
                          this.context,
                          l10n.nestedDirectoryError(conflict),
                        );
                        return;
                      }
                      setState(() {
                        _appendDirectory(_scanDirectories, result);
                      });
                    },
              onRemoveScanDirectory: isBusy
                  ? null
                  : (value) {
                      setState(() {
                        _scanDirectories.remove(value);
                      });
                    },
              onAddExcludedDirectory: isBusy
                  ? null
                  : () async {
                      final opId = _currentOpId;
                      if (!mounted) return;
                      final result = _protocol == SourceProtocol.local
                          ? await _promptLocalDirectoryPath(
                              this.context,
                              title: l10n.addExcludedScanDirectoryDialogTitle,
                              description:
                                  l10n.excludedScanDirectoriesDialogDescription,
                            )
                          : await _promptDirectoryPath(
                              this.context,
                              title: l10n.addExcludedScanDirectoryDialogTitle,
                              description:
                                  l10n.excludedScanDirectoriesDialogDescription,
                            );
                      if (!mounted ||
                          _isClosedOrDisposed ||
                          opId != _currentOpId ||
                          result == null) {
                        return;
                      }
                      setState(() {
                        _appendDirectory(_excludedScanDirectories, result);
                      });
                    },
              onRemoveExcludedDirectory: isBusy
                  ? null
                  : (value) {
                      setState(() {
                        _excludedScanDirectories.remove(value);
                      });
                    },
            ),
          ];

          final body = isCompact
              ? SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ...decks,
                      const SizedBox(height: 16),
                      _buildFooterButtons(
                        l10n,
                        controller,
                        controllerState,
                        isEditing,
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: decks,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildFooterButtons(
                      l10n,
                      controller,
                      controllerState,
                      isEditing,
                    ),
                  ],
                );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              header,
              const SizedBox(height: 12),
              Expanded(child: body),
            ],
          );
        },
      ),
    );

    return Shortcuts(
      shortcuts: <ShortcutActivator, Intent>{
        LogicalKeySet(LogicalKeyboardKey.escape): const DismissIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          DismissIntent: CallbackAction<DismissIntent>(
            onInvoke: (_) {
              if (!controller.isCommitting) {
                _handleClose();
              }
              return null;
            },
          ),
        },
        child: PopScope(
          canPop: _isClosedOrDisposed && !controller.isCommitting,
          onPopInvokedWithResult: (didPop, result) async {
            if (didPop) return;
            if (_isClosedOrDisposed) {
              Navigator.of(context).pop();
              return;
            }
            if (!controller.isCommitting) {
              await _handleBack();
            }
          },
          child: widget.embedded
              ? Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: formContent,
                )
              : Scaffold(
                  backgroundColor: colorScheme.surface,
                  body: LayoutBuilder(
                    builder: (context, constraints) {
                      final maxCardHeight = math.max(
                        0.0,
                        constraints.maxHeight - 24.0,
                      );
                      return Container(
                        decoration: BoxDecoration(
                          color: colorScheme.surface,
                          gradient: RadialGradient(
                            center: Alignment.topCenter,
                            radius: 1.2,
                            colors: [
                              colorScheme.primary.withValues(
                                alpha: isDark ? 0.14 : 0.08,
                              ),
                              colorScheme.surface,
                            ],
                          ),
                        ),
                        child: SafeArea(
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 420,
                                ),
                                child: Material(
                                  color: colorScheme.surfaceContainerHigh
                                      .withValues(alpha: isDark ? 0.94 : 0.98),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(28),
                                    side: BorderSide(
                                      color: colorScheme.outlineVariant
                                          .withValues(
                                            alpha: isDark ? 0.42 : 0.62,
                                          ),
                                    ),
                                  ),
                                  child: Container(
                                    constraints: BoxConstraints(
                                      maxHeight: maxCardHeight,
                                    ),
                                    padding: const EdgeInsets.all(20),
                                    child: formContent,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
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
      _cloud189AuthorizationCodeController.text =
          cloud189Draft.authorizationCode;
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
    _initialSnapshot = _takeSnapshot();
  }

  void _setProtocol(AppLocalizations l10n, SourceProtocol value) {
    setState(() {
      _protocol = value;
      if (_nameController.text.trim().isEmpty) {
        _nameController.text = _defaultSourceName(l10n, value);
      }
    });
  }

  void _appendDirectory(List<String> directories, String value) {
    if (_protocol == SourceProtocol.local) {
      final normalized = PathNestingValidator.normalize(value);
      if (normalized.isNotEmpty && !directories.contains(normalized)) {
        directories.add(normalized);
      }
      return;
    }
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

  Future<void> _addLocalScanDirectory(
    AppLocalizations l10n,
  ) async {
    final opId = _currentOpId;
    final result = await _promptLocalDirectoryPath(
      context,
      title: l10n.addLocalDirectoryDialogTitle,
      description: l10n.addLocalDirectoryDialogDescription,
    );
    if (!mounted ||
        _isClosedOrDisposed ||
        opId != _currentOpId ||
        result == null) {
      return;
    }
    final normalized = PathNestingValidator.normalize(result);
    if (normalized.isEmpty) return;

    final conflict = PathNestingValidator.findConflict(
      normalized,
      _scanDirectories,
    );
    if (conflict != null) {
      if (!mounted) return;
      showTopSnackBar(context, l10n.nestedDirectoryError(conflict));
      return;
    }
    setState(() {
      _appendDirectory(_scanDirectories, normalized);
    });
  }

  Future<String?> _promptLocalDirectoryPath(
    BuildContext context, {
    required String title,
    required String description,
  }) async {
    if (!mounted || _isClosedOrDisposed) return null;
    final l10n = AppLocalizations.of(context)!;
    final materialL10n = MaterialLocalizations.of(context);
    final controller = TextEditingController(
      text: _scanDirectories.isNotEmpty
          ? _scanDirectories.last
          : (defaultTargetPlatform == TargetPlatform.android
              ? '/storage/emulated/0/Music'
              : ''),
    );

    try {
      final result = await _showOwnedDialog<String>(
        context: context,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              return GlacierDialog(
                title: Text(title),
                content: SizedBox(
                  width: 440,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(description),
                      const SizedBox(height: 16),
                      if (!kIsWeb) ...[
                        OutlinedButton.icon(
                          onPressed: () async {
                            try {
                              final selected =
                                  await file_selector.getDirectoryPath(
                                confirmButtonText: l10n.selectDirectoryAction,
                              );
                              if (selected != null &&
                                  selected.trim().isNotEmpty) {
                                controller.text = selected.trim();
                                setDialogState(() {});
                              }
                            } catch (_) {}
                          },
                          icon: const Icon(Icons.folder_open_rounded),
                          label: Text(l10n.addLocalDirectoryAction),
                        ),
                        const SizedBox(height: 12),
                      ],
                      TextField(
                        controller: controller,
                        autofocus: kIsWeb,
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
        },
      );
      return result;
    } finally {
      controller.dispose();
    }
  }

  Future<String?> _promptDirectoryPath(
    BuildContext context, {
    required String title,
    required String description,
  }) async {
    if (!mounted || _isClosedOrDisposed) return null;
    final l10n = AppLocalizations.of(context)!;
    final materialL10n = MaterialLocalizations.of(context);
    final controller = TextEditingController(text: '/');

    try {
      final result = await _showOwnedDialog<String>(
        context: context,
        builder: (dialogContext) {
          return GlacierDialog(
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
      return result;
    } finally {
      controller.dispose();
    }
  }

  String _connectionFailedMessage(AppLocalizations l10n) {
    return _protocol == SourceProtocol.cloudDrive
        ? l10n.cloud189ConnectionFailedMessage
        : l10n.connectionFailedMessage;
  }

  Future<String?> _promptCloud189Captcha(Uint8List captchaImageBytes) async {
    if (!mounted || _isClosedOrDisposed) {
      return null;
    }

    final l10n = AppLocalizations.of(context)!;
    final materialL10n = MaterialLocalizations.of(context);
    final codeController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    try {
      return await _showOwnedDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return Shortcuts(
            shortcuts: <ShortcutActivator, Intent>{
              LogicalKeySet(LogicalKeyboardKey.escape): const DismissIntent(),
            },
            child: Actions(
              actions: <Type, Action<Intent>>{
                DismissIntent: CallbackAction<DismissIntent>(
                  onInvoke: (_) {
                    Navigator.of(dialogContext).pop();
                    return null;
                  },
                ),
              },
              child: GlacierDialog(
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
                            color: Theme.of(
                              dialogContext,
                            ).colorScheme.surfaceContainerHighest,
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
                            Navigator.of(
                              dialogContext,
                            ).pop(codeController.text.trim());
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
                      Navigator.of(
                        dialogContext,
                      ).pop(codeController.text.trim());
                    },
                    child: Text(materialL10n.okButtonLabel),
                  ),
                ],
              ),
            ),
          );
        },
      );
    } finally {
      codeController.dispose();
    }
  }

  Future<void> _showCloud189DebugLog(AddSourceController controller) async {
    if (_protocol != SourceProtocol.cloudDrive ||
        !mounted ||
        _isClosedOrDisposed) {
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
    await _showOwnedDialog<void>(
      context: context,
      builder: (dialogContext) {
        return GlacierDialog(
          title: Text(l10n.cloud189DebugLogDialogTitle),
          content: SizedBox(
            width: 640,
            height: maxHeight,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.cloud189DebugLogDialogDescription,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: SingleChildScrollView(
                    child: SelectableText(
                      log,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(materialL10n.closeButtonLabel),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openCloud189Authorization(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final appKey = _cloud189AppKeyController.text.trim();
    final redirectUri = _cloud189RedirectUriController.text.trim();
    if (appKey.isEmpty || redirectUri.isEmpty) {
      showTopSnackBar(context, l10n.cloud189AppAuthorizationConfigRequired);
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
    final opId = _currentOpId;
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!mounted ||
        _isClosedOrDisposed ||
        opId != _currentOpId ||
        !context.mounted) {
      return;
    }
    showTopSnackBar(
      context,
      launched
          ? l10n.cloud189AuthorizationOpenedMessage
          : l10n.cloud189AuthorizationOpenFailedMessage,
    );
  }

  WebDavSourceDraft _createWebDavDraft() {
    return WebDavSourceDraft(
      sourceId: widget.sourceId ?? _draftSourceId,
      protocol: _protocol,
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
      sourceId: widget.sourceId ?? _draftSourceId,
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

  LocalSourceDraft _createLocalDraft(AppLocalizations l10n) {
    return LocalSourceDraft(
      sourceId: widget.sourceId ?? _draftSourceId,
      name: _nameController.text.trim().isEmpty
          ? _defaultSourceName(l10n, SourceProtocol.local)
          : _nameController.text.trim(),
      scanDirectories: List<String>.from(_scanDirectories),
      excludedScanDirectories: List<String>.from(_excludedScanDirectories),
    );
  }

  Widget _buildFooterButtons(
    AppLocalizations l10n,
    AddSourceController controller,
    AsyncValue<void> controllerState,
    bool isEditing,
  ) {
    final materialL10n = MaterialLocalizations.of(context);
    final isBusy = controllerState.isLoading || controller.isCommitting;
    final showDebugLog =
        _protocol == SourceProtocol.cloudDrive &&
        (ref
                .watch(appSettingsControllerProvider)
                .valueOrNull
                ?.enableDebugMode ??
            false) &&
        controller.connectionDebugLog().trim().isNotEmpty;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.end,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (showDebugLog)
          TextButton.icon(
            onPressed: () => _showCloud189DebugLog(controller),
            icon: const Icon(Icons.description_outlined, size: 18),
            label: Text(l10n.debugLogsTitle),
          ),
        TextButton(
          onPressed: controller.isCommitting
              ? null
              : () async {
                  await _handleClose();
                },
          child: Text(materialL10n.cancelButtonLabel),
        ),
        OutlinedButton(
          onPressed: isBusy
              ? null
              : () async {
                  if (!_formKey.currentState!.validate()) {
                    return;
                  }
                  final opId = ++_currentOpId;
                  try {
                    if (_protocol == SourceProtocol.cloudDrive) {
                      await controller.testCloud189Connection(
                        _createCloud189Draft(),
                        captchaResolver: _promptCloud189Captcha,
                      );
                    } else if (_protocol == SourceProtocol.local) {
                      if (_scanDirectories.isEmpty) {
                        showTopSnackBar(context, l10n.noDirectoriesSelectedError);
                        return;
                      }
                      await controller.testLocalConnection(
                        _createLocalDraft(l10n),
                      );
                    } else {
                      await controller.testConnection(_createWebDavDraft());
                    }
                    if (!mounted ||
                        _isClosedOrDisposed ||
                        opId != _currentOpId) {
                      return;
                    }
                    showTopSnackBar(context, l10n.connectionTestSuccess);
                  } catch (_) {
                    if (!mounted ||
                        _isClosedOrDisposed ||
                        opId != _currentOpId) {
                      return;
                    }
                    showTopSnackBar(context, _connectionFailedMessage(l10n));
                  }
                },
          child: Text(l10n.testConnectionAction),
        ),
        FilledButton(
          onPressed: isBusy
              ? null
              : () async {
                  if (!_formKey.currentState!.validate()) {
                    return;
                  }
                  if (_protocol == SourceProtocol.local &&
                      _scanDirectories.isEmpty) {
                    showTopSnackBar(context, l10n.noDirectoriesSelectedError);
                    return;
                  }
                  final opId = ++_currentOpId;
                  try {
                    final isNewSource = !isEditing;
                    final savedProfile = _protocol == SourceProtocol.cloudDrive
                        ? await controller.saveCloud189Source(
                            _createCloud189Draft(),
                            captchaResolver: _promptCloud189Captcha,
                          )
                        : _protocol == SourceProtocol.local
                            ? await controller.saveLocalSource(
                                _createLocalDraft(l10n),
                              )
                            : await controller.saveWebDavSource(
                                _createWebDavDraft(),
                              );
                    if (!mounted ||
                        _isClosedOrDisposed ||
                        opId != _currentOpId) {
                      return;
                    }
                    showTopSnackBar(
                      context,
                      isEditing
                          ? l10n.sourceUpdatedSuccess
                          : l10n.sourceSavedSuccess,
                    );
                    if (isNewSource) {
                      unawaited(
                        ref
                            .read(libraryCatalogControllerProvider.notifier)
                            .rescanSource(savedProfile.id),
                      );
                    }
                    _isClosedOrDisposed = true;
                    _dismissOwnedAuxiliaryRoutes();
                    if (mounted) {
                      setState(() {});
                    }
                    if (widget.onClose != null) {
                      widget.onClose!();
                    } else {
                      context.pop();
                    }
                  } catch (_) {
                    if (!mounted ||
                        _isClosedOrDisposed ||
                        opId != _currentOpId) {
                      return;
                    }
                    showTopSnackBar(context, _connectionFailedMessage(l10n));
                  }
                },
          child: controllerState.isLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(
                  isEditing
                      ? l10n.saveSourceChangesAction
                      : l10n.saveSourceAction,
                ),
        ),
      ],
    );
  }
}

class _SourceTypeCard extends StatelessWidget {
  const _SourceTypeCard({required this.protocol, required this.onTap});

  final SourceProtocol protocol;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    return StudioPanel(
      radius: 28,
      tint: colorScheme.surfaceContainerHighest,
      padding: EdgeInsets.zero,
      child: StudioPressable(
        borderRadius: BorderRadius.circular(28),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              StudioPanel(
                radius: 22,
                tint: colorScheme.primaryContainer,
                child: Icon(_protocolIcon(protocol)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _sourceTypeTitle(l10n, protocol),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _sourceTypeDescription(l10n, protocol),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
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
    this.enabled = true,
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
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final isCloud189 = protocol == SourceProtocol.cloudDrive;
    final isLocal = protocol == SourceProtocol.local;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 2),
        TextFormField(
          controller: nameController,
          enabled: enabled,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            labelText: l10n.sourceNameLabel,
            hintText: l10n.sourceNameHint,
          ),
        ),
        const SizedBox(height: 16),
        if (isLocal) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: colorScheme.outlineVariant.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.folder_special_rounded,
                  color: colorScheme.primary,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    l10n.localSourceDeckDescription,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ] else if (isCloud189) ...[
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: SegmentedButton<Cloud189AuthMode>(
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
              onSelectionChanged: enabled
                  ? (selection) {
                      onCloud189AuthModeChanged(selection.first);
                    }
                  : null,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            cloud189AuthMode == Cloud189AuthMode.openListPassword
                ? l10n.cloud189OpenListModeDescription
                : l10n.cloud189AppAuthorizationModeDescription,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          if (cloud189AuthMode == Cloud189AuthMode.openListPassword) ...[
            TextFormField(
              controller: usernameController,
              enabled: enabled,
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
              enabled: enabled,
              obscureText: obscurePassword,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: l10n.cloud189OpenListPasswordLabel,
                hintText: l10n.cloud189OpenListPasswordHint,
                helperText: l10n.cloud189OpenListPasswordHelpText,
                suffixIcon: IconButton(
                  onPressed: enabled ? onTogglePassword : null,
                  icon: Icon(
                    obscurePassword
                        ? Icons.visibility_rounded
                        : Icons.visibility_off_rounded,
                  ),
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
              enabled: enabled,
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
              enabled: enabled,
              obscureText: obscurePassword,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: l10n.cloud189AppSecretLabel,
                hintText: l10n.cloud189AppSecretHint,
                suffixIcon: IconButton(
                  onPressed: enabled ? onTogglePassword : null,
                  icon: Icon(
                    obscurePassword
                        ? Icons.visibility_rounded
                        : Icons.visibility_off_rounded,
                  ),
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
              enabled: enabled,
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
              onPressed: enabled ? onOpenCloud189Authorization : null,
              icon: const Icon(Icons.open_in_new_rounded),
              label: Text(l10n.cloud189OpenAuthorizationAction),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: cloud189AuthorizationCodeController,
              enabled: enabled,
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
              enabled: enabled,
              obscureText: obscurePassword,
              minLines: 1,
              maxLines: obscurePassword ? 1 : 4,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: l10n.cloud189AppRefreshTokenLabel,
                hintText: l10n.cloud189AppRefreshTokenHint,
                helperText: l10n.cloud189AppRefreshTokenHelpText,
                suffixIcon: IconButton(
                  onPressed: enabled ? onTogglePassword : null,
                  icon: Icon(
                    obscurePassword
                        ? Icons.visibility_rounded
                        : Icons.visibility_off_rounded,
                  ),
                ),
              ),
            ),
          ],
        ] else ...[
          TextFormField(
            controller: urlController,
            enabled: enabled,
            textInputAction: TextInputAction.next,
            keyboardType: TextInputType.url,
            decoration: InputDecoration(
              labelText: l10n.serverUrlLabel,
              hintText: _serverUrlHint(l10n, protocol),
            ),
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
            enabled: enabled,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(labelText: l10n.usernameLabel),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: passwordController,
            enabled: enabled,
            obscureText: obscurePassword,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: _passwordLabel(l10n, protocol),
              suffixIcon: IconButton(
                onPressed: enabled ? onTogglePassword : null,
                icon: Icon(
                  obscurePassword
                      ? Icons.visibility_rounded
                      : Icons.visibility_off_rounded,
                ),
              ),
            ),
          ),
        ],
        if (!isLocal) ...[
          const SizedBox(height: 16),
          TextFormField(
            controller: rootPathController,
            enabled: enabled,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              labelText: l10n.rootPathLabel,
              hintText: isCloud189
                  ? l10n.cloud189RootPathHint
                  : _rootPathHint(l10n, protocol),
              helperText: isCloud189
                  ? l10n.cloud189RootPathHelpText
                  : _rootPathHelpText(l10n, protocol),
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
      ],
    );
  }
}

class _DirectoryDeck extends StatelessWidget {
  const _DirectoryDeck({
    required this.scanDirectories,
    required this.excludedScanDirectories,
    this.onAddScanDirectory,
    this.onRemoveScanDirectory,
    this.onAddExcludedDirectory,
    this.onRemoveExcludedDirectory,
  });

  final List<String> scanDirectories;
  final List<String> excludedScanDirectories;
  final Future<void> Function()? onAddScanDirectory;
  final ValueChanged<String>? onRemoveScanDirectory;
  final Future<void> Function()? onAddExcludedDirectory;
  final ValueChanged<String>? onRemoveExcludedDirectory;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Divider(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
        const SizedBox(height: 10),
        Row(
          children: [
            Icon(Icons.folder_open_rounded, color: colorScheme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                l10n.scanDirectoriesTitle,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          l10n.scanDirectoriesDescription,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
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
    this.onAdd,
    this.onRemove,
  });

  final String title;
  final String description;
  final String emptyDescription;
  final String addActionLabel;
  final List<String> entries;
  final Future<void> Function()? onAdd;
  final ValueChanged<String>? onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.start,
          spacing: 12,
          runSpacing: 10,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
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
            FilledButton.tonal(
              onPressed: onAdd,
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Icon(Icons.add_rounded, size: 18),
                  const SizedBox(width: 8),
                  Text(addActionLabel),
                ],
              ),
            ),
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
              border: Border.all(
                color: colorScheme.outlineVariant.withValues(alpha: 0.28),
              ),
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
                InputChip(
                  label: Text(entry),
                  onDeleted: onRemove == null ? null : () => onRemove!(entry),
                ),
            ],
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
              Text(
                title,
                style: Theme.of(context).textTheme.displaySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                description,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
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

String _sourceTypeTitle(AppLocalizations l10n, SourceProtocol protocol) {
  return switch (protocol) {
    SourceProtocol.webdav => l10n.webdavSourceTypeTitle,
    SourceProtocol.sftp => l10n.sftpSourceTypeTitle,
    SourceProtocol.ftp => l10n.ftpSourceTypeTitle,
    SourceProtocol.samba => l10n.sambaSourceTypeTitle,
    SourceProtocol.cloudDrive => l10n.cloud189SourceTypeTitle,
    SourceProtocol.local => l10n.localSourceTypeTitle,
  };
}

String _sourceTypeDescription(AppLocalizations l10n, SourceProtocol protocol) {
  return switch (protocol) {
    SourceProtocol.webdav => l10n.webdavSourceDescription,
    SourceProtocol.sftp => l10n.sftpSourceDescription,
    SourceProtocol.ftp => l10n.ftpSourceDescription,
    SourceProtocol.samba => l10n.sambaSourceDescription,
    SourceProtocol.cloudDrive => l10n.cloud189SourceDescription,
    SourceProtocol.local => l10n.localSourceDescription,
  };
}

String _defaultSourceName(AppLocalizations l10n, SourceProtocol protocol) {
  return switch (protocol) {
    SourceProtocol.webdav => l10n.webdavProtocol,
    SourceProtocol.sftp => l10n.sftpProtocol,
    SourceProtocol.ftp => l10n.ftpProtocol,
    SourceProtocol.samba => l10n.sambaProtocol,
    SourceProtocol.cloudDrive => l10n.cloud189DefaultSourceName,
    SourceProtocol.local => l10n.localProtocol,
  };
}

String _serverUrlHint(AppLocalizations l10n, SourceProtocol protocol) {
  return switch (protocol) {
    SourceProtocol.webdav => l10n.serverUrlHint,
    SourceProtocol.sftp => l10n.sftpServerUrlHint,
    SourceProtocol.ftp => l10n.ftpServerUrlHint,
    SourceProtocol.samba => l10n.sambaServerUrlHint,
    SourceProtocol.cloudDrive => l10n.serverUrlHint,
    SourceProtocol.local => '',
  };
}

String _rootPathHint(AppLocalizations l10n, SourceProtocol protocol) {
  return switch (protocol) {
    SourceProtocol.samba => l10n.sambaRootPathHint,
    _ => l10n.rootPathHint,
  };
}

String _rootPathHelpText(AppLocalizations l10n, SourceProtocol protocol) {
  return switch (protocol) {
    SourceProtocol.sftp => l10n.sftpRootPathHelpText,
    SourceProtocol.ftp => l10n.ftpRootPathHelpText,
    SourceProtocol.samba => l10n.sambaRootPathHelpText,
    _ => l10n.rootPathHelpText,
  };
}

String _passwordLabel(AppLocalizations l10n, SourceProtocol protocol) {
  return switch (protocol) {
    SourceProtocol.sftp => l10n.passwordLabel,
    SourceProtocol.ftp => l10n.passwordLabel,
    SourceProtocol.samba => l10n.sambaPasswordLabel,
    _ => l10n.passwordLabel,
  };
}

IconData _protocolIcon(SourceProtocol protocol) {
  return switch (protocol) {
    SourceProtocol.webdav => Icons.dns_rounded,
    SourceProtocol.sftp => Icons.terminal_rounded,
    SourceProtocol.ftp => Icons.swap_vert_circle_rounded,
    SourceProtocol.samba => Icons.lan_rounded,
    SourceProtocol.cloudDrive => Icons.cloud_queue_rounded,
    SourceProtocol.local => Icons.folder_special_rounded,
  };
}

List<SourceProtocol> _availableSourceProtocols({SourceProtocol? current}) {
  final protocols = kIsWeb
      ? <SourceProtocol>[SourceProtocol.webdav, SourceProtocol.cloudDrive]
      : SourceProtocol.values;
  if (current == null || protocols.contains(current)) {
    return protocols;
  }
  return protocols;
}
