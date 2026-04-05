import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/models/remote_entry.dart';
import '../../../core/models/source_profile.dart';
import '../../../core/storage/source_profile_repository.dart';
import '../../player/application/player_controller.dart';
import '../../sources/application/source_session_manager.dart';
import '../../sources/application/sources_controller.dart';
import '../../sources/domain/music_source.dart';

part 'library_controller.g.dart';

class LibraryViewState {
  const LibraryViewState({
    required this.sources,
    required this.selectedSource,
    required this.currentPath,
    required this.entries,
    this.isLoading = false,
    this.errorMessage,
    this.diagnostics,
  });

  final List<SourceProfile> sources;
  final SourceProfile? selectedSource;
  final String currentPath;
  final List<RemoteEntry> entries;
  final bool isLoading;
  final String? errorMessage;
  final DirectoryDiagnostics? diagnostics;

  bool get hasSources => sources.isNotEmpty;

  bool get hasError => errorMessage != null && errorMessage!.isNotEmpty;

  bool get canGoUp =>
      selectedSource != null &&
      currentPath != selectedSource!.effectiveRootPath;

  String get displayPath {
    final source = selectedSource;
    if (source == null) {
      return '/';
    }

    final rootPath = source.effectiveRootPath;
    if (currentPath == rootPath) {
      return '/';
    }

    if (currentPath.startsWith(rootPath)) {
      return '/${currentPath.substring(rootPath.length)}';
    }

    return currentPath;
  }

  LibraryViewState copyWith({
    List<SourceProfile>? sources,
    SourceProfile? selectedSource,
    String? currentPath,
    List<RemoteEntry>? entries,
    bool? isLoading,
    String? errorMessage,
    DirectoryDiagnostics? diagnostics,
    bool clearError = false,
    bool clearDiagnostics = false,
  }) {
    return LibraryViewState(
      sources: sources ?? this.sources,
      selectedSource: selectedSource ?? this.selectedSource,
      currentPath: currentPath ?? this.currentPath,
      entries: entries ?? this.entries,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      diagnostics: clearDiagnostics ? null : diagnostics ?? this.diagnostics,
    );
  }
}

@riverpod
class LibraryController extends _$LibraryController {
  @override
  Future<LibraryViewState> build() async {
    final repository = ref.watch(sourceProfileRepositoryProvider);
    final sources = await ref.watch(sourcesControllerProvider.future);

    if (sources.isEmpty) {
      return const LibraryViewState(
        sources: [],
        selectedSource: null,
        currentPath: '/',
        entries: [],
      );
    }

    final activeSourceId = await repository.loadActiveSourceId();
    final selectedSource = _resolveSelectedSource(sources, activeSourceId);
    await repository.saveActiveSourceId(selectedSource.id);

    try {
      final listing = await _loadEntries(
        selectedSource,
        selectedSource.effectiveRootPath,
      );

      return LibraryViewState(
        sources: sources,
        selectedSource: selectedSource,
        currentPath: selectedSource.effectiveRootPath,
        entries: listing.entries,
        diagnostics: listing.diagnostics,
      );
    } on DirectoryReadFailure catch (error) {
      return LibraryViewState(
        sources: sources,
        selectedSource: selectedSource,
        currentPath: selectedSource.effectiveRootPath,
        entries: const [],
        errorMessage: error.message,
        diagnostics: error.diagnostics,
      );
    } catch (error) {
      return LibraryViewState(
        sources: sources,
        selectedSource: selectedSource,
        currentPath: selectedSource.effectiveRootPath,
        entries: const [],
        errorMessage: error.toString(),
      );
    }
  }

  Future<void> selectSource(String sourceId) async {
    final current = state.valueOrNull;
    final sources = current != null
        ? current.sources
        : await ref.read(sourcesControllerProvider.future);
    final selectedSource = sources.firstWhere((item) => item.id == sourceId);
    await _reload(selectedSource, selectedSource.effectiveRootPath);
  }

  Future<void> openEntry(RemoteEntry entry) async {
    if (entry.isDirectory) {
      await openPath(entry.path);
      return;
    }

    if (!entry.isPlayable) {
      return;
    }

    final current = state.requireValue;
    final selectedSource = current.selectedSource;
    if (selectedSource == null) {
      return;
    }

    await ref
        .read(playerControllerProvider.notifier)
        .playEntry(profile: selectedSource, entry: entry);
  }

  Future<void> openPath(String path) async {
    final current = state.requireValue;
    final selectedSource = current.selectedSource;
    if (selectedSource == null) {
      return;
    }

    await _reload(selectedSource, _normalizeDirectoryPath(path));
  }

  Future<void> goUp() async {
    final current = state.requireValue;
    final selectedSource = current.selectedSource;
    if (selectedSource == null) {
      return;
    }

    await _reload(
      selectedSource,
      _parentPath(current.currentPath, selectedSource.effectiveRootPath),
    );
  }

  Future<void> refresh() async {
    final current = state.requireValue;
    final selectedSource = current.selectedSource;
    if (selectedSource == null) {
      return;
    }

    await _reload(selectedSource, current.currentPath);
  }

  Future<DirectoryListing> _loadEntries(
    SourceProfile profile,
    String path,
  ) async {
    final source = await ref
        .read(musicSourceSessionManagerProvider)
        .get(profile);
    return source.listFiles(path);
  }

  Future<void> _reload(SourceProfile profile, String path) async {
    final current = state.valueOrNull;
    if (current != null) {
      state = AsyncData(
        current.copyWith(
          isLoading: true,
          clearError: true,
          clearDiagnostics: true,
        ),
      );
    }

    try {
      final repository = ref.read(sourceProfileRepositoryProvider);
      await repository.saveActiveSourceId(profile.id);

      final sources = await ref.read(sourcesControllerProvider.future);
      final listing = await _loadEntries(profile, path);

      state = AsyncData(
        LibraryViewState(
          sources: sources,
          selectedSource: profile,
          currentPath: path,
          entries: listing.entries,
          diagnostics: listing.diagnostics,
        ),
      );
    } on DirectoryReadFailure catch (error) {
      final sources = await ref.read(sourcesControllerProvider.future);
      state = AsyncData(
        LibraryViewState(
          sources: sources,
          selectedSource: profile,
          currentPath: path,
          entries: const [],
          errorMessage: error.message,
          diagnostics: error.diagnostics,
        ),
      );
    } catch (error) {
      final sources = await ref.read(sourcesControllerProvider.future);
      state = AsyncData(
        LibraryViewState(
          sources: sources,
          selectedSource: profile,
          currentPath: path,
          entries: const [],
          errorMessage: error.toString(),
        ),
      );
    }
  }

  SourceProfile _resolveSelectedSource(
    List<SourceProfile> sources,
    String? activeSourceId,
  ) {
    for (final source in sources) {
      if (source.id == activeSourceId) {
        return source;
      }
    }
    return sources.first;
  }

  String _normalizeDirectoryPath(String path) {
    if (path.isEmpty) {
      return '/';
    }

    var normalized = path;
    if (!normalized.startsWith('/')) {
      normalized = '/$normalized';
    }
    if (!normalized.endsWith('/')) {
      normalized = '$normalized/';
    }
    return normalized;
  }

  String _parentPath(String currentPath, String rootPath) {
    if (currentPath == rootPath) {
      return rootPath;
    }

    final trimmed = currentPath.endsWith('/')
        ? currentPath.substring(0, currentPath.length - 1)
        : currentPath;
    final separatorIndex = trimmed.lastIndexOf('/');
    if (separatorIndex <= 0) {
      return rootPath;
    }

    final parent = '${trimmed.substring(0, separatorIndex)}/';
    if (parent.length < rootPath.length) {
      return rootPath;
    }
    return parent;
  }
}
