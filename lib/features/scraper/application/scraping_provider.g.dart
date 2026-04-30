// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'scraping_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$scrapingMetadataRepositoryHash() =>
    r'c12d0941fcdb557c0d8a37a8c8142a1a964b525d';

/// 获取刮削元数据 Repository
///
/// Copied from [scrapingMetadataRepository].
@ProviderFor(scrapingMetadataRepository)
final scrapingMetadataRepositoryProvider =
    AutoDisposeProvider<ScrapingMetadataRepository>.internal(
      scrapingMetadataRepository,
      name: r'scrapingMetadataRepositoryProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$scrapingMetadataRepositoryHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef ScrapingMetadataRepositoryRef =
    AutoDisposeProviderRef<ScrapingMetadataRepository>;
String _$scrapingCacheRepositoryHash() =>
    r'9e1ed37f044d12ba788ba32b98edca14cd5ceaa5';

/// 获取刮削缓存 Repository
///
/// Copied from [scrapingCacheRepository].
@ProviderFor(scrapingCacheRepository)
final scrapingCacheRepositoryProvider =
    AutoDisposeProvider<ScrapingCacheRepository>.internal(
      scrapingCacheRepository,
      name: r'scrapingCacheRepositoryProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$scrapingCacheRepositoryHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef ScrapingCacheRepositoryRef =
    AutoDisposeProviderRef<ScrapingCacheRepository>;
String _$musicBrainzScraperHash() =>
    r'eb651276aabd8d4bb4c7e5762899aff5cdbf19dc';

/// 获取 MusicBrainz 刮削器
///
/// Copied from [musicBrainzScraper].
@ProviderFor(musicBrainzScraper)
final musicBrainzScraperProvider =
    AutoDisposeProvider<MusicBrainzScraper>.internal(
      musicBrainzScraper,
      name: r'musicBrainzScraperProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$musicBrainzScraperHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef MusicBrainzScraperRef = AutoDisposeProviderRef<MusicBrainzScraper>;
String _$searchMetadataHash() => r'0b460ddb3bc91c2900a69e7d01e2d2c6fdb73415';

/// Copied from Dart SDK
class _SystemHash {
  _SystemHash._();

  static int combine(int hash, int value) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + value);
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    return hash ^ (hash >> 6);
  }

  static int finish(int hash) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    // ignore: parameter_assignments
    hash = hash ^ (hash >> 11);
    return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  }
}

/// 搜索歌曲元数据
/// 返回多个可能的匹配结果
///
/// Copied from [searchMetadata].
@ProviderFor(searchMetadata)
const searchMetadataProvider = SearchMetadataFamily();

/// 搜索歌曲元数据
/// 返回多个可能的匹配结果
///
/// Copied from [searchMetadata].
class SearchMetadataFamily
    extends Family<AsyncValue<List<ScrapedMetadataResult>>> {
  /// 搜索歌曲元数据
  /// 返回多个可能的匹配结果
  ///
  /// Copied from [searchMetadata].
  const SearchMetadataFamily();

  /// 搜索歌曲元数据
  /// 返回多个可能的匹配结果
  ///
  /// Copied from [searchMetadata].
  SearchMetadataProvider call(String title, {String? artist}) {
    return SearchMetadataProvider(title, artist: artist);
  }

  @override
  SearchMetadataProvider getProviderOverride(
    covariant SearchMetadataProvider provider,
  ) {
    return call(provider.title, artist: provider.artist);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'searchMetadataProvider';
}

/// 搜索歌曲元数据
/// 返回多个可能的匹配结果
///
/// Copied from [searchMetadata].
class SearchMetadataProvider
    extends AutoDisposeFutureProvider<List<ScrapedMetadataResult>> {
  /// 搜索歌曲元数据
  /// 返回多个可能的匹配结果
  ///
  /// Copied from [searchMetadata].
  SearchMetadataProvider(String title, {String? artist})
    : this._internal(
        (ref) =>
            searchMetadata(ref as SearchMetadataRef, title, artist: artist),
        from: searchMetadataProvider,
        name: r'searchMetadataProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$searchMetadataHash,
        dependencies: SearchMetadataFamily._dependencies,
        allTransitiveDependencies:
            SearchMetadataFamily._allTransitiveDependencies,
        title: title,
        artist: artist,
      );

  SearchMetadataProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.title,
    required this.artist,
  }) : super.internal();

  final String title;
  final String? artist;

  @override
  Override overrideWith(
    FutureOr<List<ScrapedMetadataResult>> Function(SearchMetadataRef provider)
    create,
  ) {
    return ProviderOverride(
      origin: this,
      override: SearchMetadataProvider._internal(
        (ref) => create(ref as SearchMetadataRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        title: title,
        artist: artist,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<List<ScrapedMetadataResult>>
  createElement() {
    return _SearchMetadataProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is SearchMetadataProvider &&
        other.title == title &&
        other.artist == artist;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, title.hashCode);
    hash = _SystemHash.combine(hash, artist.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin SearchMetadataRef
    on AutoDisposeFutureProviderRef<List<ScrapedMetadataResult>> {
  /// The parameter `title` of this provider.
  String get title;

  /// The parameter `artist` of this provider.
  String? get artist;
}

class _SearchMetadataProviderElement
    extends AutoDisposeFutureProviderElement<List<ScrapedMetadataResult>>
    with SearchMetadataRef {
  _SearchMetadataProviderElement(super.provider);

  @override
  String get title => (origin as SearchMetadataProvider).title;
  @override
  String? get artist => (origin as SearchMetadataProvider).artist;
}

String _$scrapingStatsHash() => r'5b918c33ace079e1598471129f905c92d3649ba0';

/// 获取统计信息
///
/// Copied from [scrapingStats].
@ProviderFor(scrapingStats)
final scrapingStatsProvider =
    AutoDisposeFutureProvider<ScrapingStatsResult>.internal(
      scrapingStats,
      name: r'scrapingStatsProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$scrapingStatsHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef ScrapingStatsRef = AutoDisposeFutureProviderRef<ScrapingStatsResult>;
String _$pendingScrapingsHash() => r'6dbaeee6ed637d8b737b3a171c4536ea40ff6fc1';

/// 获取待刮削的元数据列表
///
/// Copied from [pendingScrapings].
@ProviderFor(pendingScrapings)
final pendingScrapingsProvider =
    AutoDisposeFutureProvider<List<ScrapedMetadata>>.internal(
      pendingScrapings,
      name: r'pendingScrapingsProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$pendingScrapingsHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef PendingScrapingsRef =
    AutoDisposeFutureProviderRef<List<ScrapedMetadata>>;
String _$getScrapingMetadataHash() =>
    r'88848e05911781dba31b77d98c4047466bcd6c78';

/// 获取指定文件的刮削状态
///
/// Copied from [getScrapingMetadata].
@ProviderFor(getScrapingMetadata)
const getScrapingMetadataProvider = GetScrapingMetadataFamily();

/// 获取指定文件的刮削状态
///
/// Copied from [getScrapingMetadata].
class GetScrapingMetadataFamily extends Family<AsyncValue<ScrapedMetadata?>> {
  /// 获取指定文件的刮削状态
  ///
  /// Copied from [getScrapingMetadata].
  const GetScrapingMetadataFamily();

  /// 获取指定文件的刮削状态
  ///
  /// Copied from [getScrapingMetadata].
  GetScrapingMetadataProvider call(String id) {
    return GetScrapingMetadataProvider(id);
  }

  @override
  GetScrapingMetadataProvider getProviderOverride(
    covariant GetScrapingMetadataProvider provider,
  ) {
    return call(provider.id);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'getScrapingMetadataProvider';
}

/// 获取指定文件的刮削状态
///
/// Copied from [getScrapingMetadata].
class GetScrapingMetadataProvider
    extends AutoDisposeFutureProvider<ScrapedMetadata?> {
  /// 获取指定文件的刮削状态
  ///
  /// Copied from [getScrapingMetadata].
  GetScrapingMetadataProvider(String id)
    : this._internal(
        (ref) => getScrapingMetadata(ref as GetScrapingMetadataRef, id),
        from: getScrapingMetadataProvider,
        name: r'getScrapingMetadataProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$getScrapingMetadataHash,
        dependencies: GetScrapingMetadataFamily._dependencies,
        allTransitiveDependencies:
            GetScrapingMetadataFamily._allTransitiveDependencies,
        id: id,
      );

  GetScrapingMetadataProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.id,
  }) : super.internal();

  final String id;

  @override
  Override overrideWith(
    FutureOr<ScrapedMetadata?> Function(GetScrapingMetadataRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: GetScrapingMetadataProvider._internal(
        (ref) => create(ref as GetScrapingMetadataRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        id: id,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<ScrapedMetadata?> createElement() {
    return _GetScrapingMetadataProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is GetScrapingMetadataProvider && other.id == id;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, id.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin GetScrapingMetadataRef on AutoDisposeFutureProviderRef<ScrapedMetadata?> {
  /// The parameter `id` of this provider.
  String get id;
}

class _GetScrapingMetadataProviderElement
    extends AutoDisposeFutureProviderElement<ScrapedMetadata?>
    with GetScrapingMetadataRef {
  _GetScrapingMetadataProviderElement(super.provider);

  @override
  String get id => (origin as GetScrapingMetadataProvider).id;
}

String _$applyManualScrapingResultHash() =>
    r'580ffe47598bf65ad4669d31f8a995d7f009c16c';

/// 应用手动刮削结果
///
/// Copied from [applyManualScrapingResult].
@ProviderFor(applyManualScrapingResult)
const applyManualScrapingResultProvider = ApplyManualScrapingResultFamily();

/// 应用手动刮削结果
///
/// Copied from [applyManualScrapingResult].
class ApplyManualScrapingResultFamily extends Family<AsyncValue<void>> {
  /// 应用手动刮削结果
  ///
  /// Copied from [applyManualScrapingResult].
  const ApplyManualScrapingResultFamily();

  /// 应用手动刮削结果
  ///
  /// Copied from [applyManualScrapingResult].
  ApplyManualScrapingResultProvider call(
    String fileId,
    ScrapedMetadataResult result,
  ) {
    return ApplyManualScrapingResultProvider(fileId, result);
  }

  @override
  ApplyManualScrapingResultProvider getProviderOverride(
    covariant ApplyManualScrapingResultProvider provider,
  ) {
    return call(provider.fileId, provider.result);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'applyManualScrapingResultProvider';
}

/// 应用手动刮削结果
///
/// Copied from [applyManualScrapingResult].
class ApplyManualScrapingResultProvider
    extends AutoDisposeFutureProvider<void> {
  /// 应用手动刮削结果
  ///
  /// Copied from [applyManualScrapingResult].
  ApplyManualScrapingResultProvider(String fileId, ScrapedMetadataResult result)
    : this._internal(
        (ref) => applyManualScrapingResult(
          ref as ApplyManualScrapingResultRef,
          fileId,
          result,
        ),
        from: applyManualScrapingResultProvider,
        name: r'applyManualScrapingResultProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$applyManualScrapingResultHash,
        dependencies: ApplyManualScrapingResultFamily._dependencies,
        allTransitiveDependencies:
            ApplyManualScrapingResultFamily._allTransitiveDependencies,
        fileId: fileId,
        result: result,
      );

  ApplyManualScrapingResultProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.fileId,
    required this.result,
  }) : super.internal();

  final String fileId;
  final ScrapedMetadataResult result;

  @override
  Override overrideWith(
    FutureOr<void> Function(ApplyManualScrapingResultRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: ApplyManualScrapingResultProvider._internal(
        (ref) => create(ref as ApplyManualScrapingResultRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        fileId: fileId,
        result: result,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<void> createElement() {
    return _ApplyManualScrapingResultProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is ApplyManualScrapingResultProvider &&
        other.fileId == fileId &&
        other.result == result;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, fileId.hashCode);
    hash = _SystemHash.combine(hash, result.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin ApplyManualScrapingResultRef on AutoDisposeFutureProviderRef<void> {
  /// The parameter `fileId` of this provider.
  String get fileId;

  /// The parameter `result` of this provider.
  ScrapedMetadataResult get result;
}

class _ApplyManualScrapingResultProviderElement
    extends AutoDisposeFutureProviderElement<void>
    with ApplyManualScrapingResultRef {
  _ApplyManualScrapingResultProviderElement(super.provider);

  @override
  String get fileId => (origin as ApplyManualScrapingResultProvider).fileId;
  @override
  ScrapedMetadataResult get result =>
      (origin as ApplyManualScrapingResultProvider).result;
}

String _$applyAutoScrapingResultHash() =>
    r'bbae3dd5bf6fb2ebbd8f61474357c14a29ebff5d';

/// 应用自动刮削结果
///
/// Copied from [applyAutoScrapingResult].
@ProviderFor(applyAutoScrapingResult)
const applyAutoScrapingResultProvider = ApplyAutoScrapingResultFamily();

/// 应用自动刮削结果
///
/// Copied from [applyAutoScrapingResult].
class ApplyAutoScrapingResultFamily extends Family<AsyncValue<void>> {
  /// 应用自动刮削结果
  ///
  /// Copied from [applyAutoScrapingResult].
  const ApplyAutoScrapingResultFamily();

  /// 应用自动刮削结果
  ///
  /// Copied from [applyAutoScrapingResult].
  ApplyAutoScrapingResultProvider call(
    String fileId,
    ScrapedMetadataResult result,
  ) {
    return ApplyAutoScrapingResultProvider(fileId, result);
  }

  @override
  ApplyAutoScrapingResultProvider getProviderOverride(
    covariant ApplyAutoScrapingResultProvider provider,
  ) {
    return call(provider.fileId, provider.result);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'applyAutoScrapingResultProvider';
}

/// 应用自动刮削结果
///
/// Copied from [applyAutoScrapingResult].
class ApplyAutoScrapingResultProvider extends AutoDisposeFutureProvider<void> {
  /// 应用自动刮削结果
  ///
  /// Copied from [applyAutoScrapingResult].
  ApplyAutoScrapingResultProvider(String fileId, ScrapedMetadataResult result)
    : this._internal(
        (ref) => applyAutoScrapingResult(
          ref as ApplyAutoScrapingResultRef,
          fileId,
          result,
        ),
        from: applyAutoScrapingResultProvider,
        name: r'applyAutoScrapingResultProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$applyAutoScrapingResultHash,
        dependencies: ApplyAutoScrapingResultFamily._dependencies,
        allTransitiveDependencies:
            ApplyAutoScrapingResultFamily._allTransitiveDependencies,
        fileId: fileId,
        result: result,
      );

  ApplyAutoScrapingResultProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.fileId,
    required this.result,
  }) : super.internal();

  final String fileId;
  final ScrapedMetadataResult result;

  @override
  Override overrideWith(
    FutureOr<void> Function(ApplyAutoScrapingResultRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: ApplyAutoScrapingResultProvider._internal(
        (ref) => create(ref as ApplyAutoScrapingResultRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        fileId: fileId,
        result: result,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<void> createElement() {
    return _ApplyAutoScrapingResultProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is ApplyAutoScrapingResultProvider &&
        other.fileId == fileId &&
        other.result == result;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, fileId.hashCode);
    hash = _SystemHash.combine(hash, result.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin ApplyAutoScrapingResultRef on AutoDisposeFutureProviderRef<void> {
  /// The parameter `fileId` of this provider.
  String get fileId;

  /// The parameter `result` of this provider.
  ScrapedMetadataResult get result;
}

class _ApplyAutoScrapingResultProviderElement
    extends AutoDisposeFutureProviderElement<void>
    with ApplyAutoScrapingResultRef {
  _ApplyAutoScrapingResultProviderElement(super.provider);

  @override
  String get fileId => (origin as ApplyAutoScrapingResultProvider).fileId;
  @override
  ScrapedMetadataResult get result =>
      (origin as ApplyAutoScrapingResultProvider).result;
}

String _$createScrapingRecordHash() =>
    r'96847b4a72a7878ebf1a6c7c8462e70828aaa702';

/// 创建初始刮削记录
///
/// Copied from [createScrapingRecord].
@ProviderFor(createScrapingRecord)
const createScrapingRecordProvider = CreateScrapingRecordFamily();

/// 创建初始刮削记录
///
/// Copied from [createScrapingRecord].
class CreateScrapingRecordFamily extends Family<AsyncValue<ScrapedMetadata>> {
  /// 创建初始刮削记录
  ///
  /// Copied from [createScrapingRecord].
  const CreateScrapingRecordFamily();

  /// 创建初始刮削记录
  ///
  /// Copied from [createScrapingRecord].
  CreateScrapingRecordProvider call(
    String sourceId,
    String filePath,
    String filename, {
    String? originalArtist,
  }) {
    return CreateScrapingRecordProvider(
      sourceId,
      filePath,
      filename,
      originalArtist: originalArtist,
    );
  }

  @override
  CreateScrapingRecordProvider getProviderOverride(
    covariant CreateScrapingRecordProvider provider,
  ) {
    return call(
      provider.sourceId,
      provider.filePath,
      provider.filename,
      originalArtist: provider.originalArtist,
    );
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'createScrapingRecordProvider';
}

/// 创建初始刮削记录
///
/// Copied from [createScrapingRecord].
class CreateScrapingRecordProvider
    extends AutoDisposeFutureProvider<ScrapedMetadata> {
  /// 创建初始刮削记录
  ///
  /// Copied from [createScrapingRecord].
  CreateScrapingRecordProvider(
    String sourceId,
    String filePath,
    String filename, {
    String? originalArtist,
  }) : this._internal(
         (ref) => createScrapingRecord(
           ref as CreateScrapingRecordRef,
           sourceId,
           filePath,
           filename,
           originalArtist: originalArtist,
         ),
         from: createScrapingRecordProvider,
         name: r'createScrapingRecordProvider',
         debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
             ? null
             : _$createScrapingRecordHash,
         dependencies: CreateScrapingRecordFamily._dependencies,
         allTransitiveDependencies:
             CreateScrapingRecordFamily._allTransitiveDependencies,
         sourceId: sourceId,
         filePath: filePath,
         filename: filename,
         originalArtist: originalArtist,
       );

  CreateScrapingRecordProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.sourceId,
    required this.filePath,
    required this.filename,
    required this.originalArtist,
  }) : super.internal();

  final String sourceId;
  final String filePath;
  final String filename;
  final String? originalArtist;

  @override
  Override overrideWith(
    FutureOr<ScrapedMetadata> Function(CreateScrapingRecordRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: CreateScrapingRecordProvider._internal(
        (ref) => create(ref as CreateScrapingRecordRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        sourceId: sourceId,
        filePath: filePath,
        filename: filename,
        originalArtist: originalArtist,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<ScrapedMetadata> createElement() {
    return _CreateScrapingRecordProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is CreateScrapingRecordProvider &&
        other.sourceId == sourceId &&
        other.filePath == filePath &&
        other.filename == filename &&
        other.originalArtist == originalArtist;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, sourceId.hashCode);
    hash = _SystemHash.combine(hash, filePath.hashCode);
    hash = _SystemHash.combine(hash, filename.hashCode);
    hash = _SystemHash.combine(hash, originalArtist.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin CreateScrapingRecordRef on AutoDisposeFutureProviderRef<ScrapedMetadata> {
  /// The parameter `sourceId` of this provider.
  String get sourceId;

  /// The parameter `filePath` of this provider.
  String get filePath;

  /// The parameter `filename` of this provider.
  String get filename;

  /// The parameter `originalArtist` of this provider.
  String? get originalArtist;
}

class _CreateScrapingRecordProviderElement
    extends AutoDisposeFutureProviderElement<ScrapedMetadata>
    with CreateScrapingRecordRef {
  _CreateScrapingRecordProviderElement(super.provider);

  @override
  String get sourceId => (origin as CreateScrapingRecordProvider).sourceId;
  @override
  String get filePath => (origin as CreateScrapingRecordProvider).filePath;
  @override
  String get filename => (origin as CreateScrapingRecordProvider).filename;
  @override
  String? get originalArtist =>
      (origin as CreateScrapingRecordProvider).originalArtist;
}

String _$deleteScrapingRecordHash() =>
    r'bb902c914c4430be9085c88a30cfea88375c6930';

/// 删除刮削记录
///
/// Copied from [deleteScrapingRecord].
@ProviderFor(deleteScrapingRecord)
const deleteScrapingRecordProvider = DeleteScrapingRecordFamily();

/// 删除刮削记录
///
/// Copied from [deleteScrapingRecord].
class DeleteScrapingRecordFamily extends Family<AsyncValue<void>> {
  /// 删除刮削记录
  ///
  /// Copied from [deleteScrapingRecord].
  const DeleteScrapingRecordFamily();

  /// 删除刮削记录
  ///
  /// Copied from [deleteScrapingRecord].
  DeleteScrapingRecordProvider call(List<String> ids) {
    return DeleteScrapingRecordProvider(ids);
  }

  @override
  DeleteScrapingRecordProvider getProviderOverride(
    covariant DeleteScrapingRecordProvider provider,
  ) {
    return call(provider.ids);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'deleteScrapingRecordProvider';
}

/// 删除刮削记录
///
/// Copied from [deleteScrapingRecord].
class DeleteScrapingRecordProvider extends AutoDisposeFutureProvider<void> {
  /// 删除刮削记录
  ///
  /// Copied from [deleteScrapingRecord].
  DeleteScrapingRecordProvider(List<String> ids)
    : this._internal(
        (ref) => deleteScrapingRecord(ref as DeleteScrapingRecordRef, ids),
        from: deleteScrapingRecordProvider,
        name: r'deleteScrapingRecordProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$deleteScrapingRecordHash,
        dependencies: DeleteScrapingRecordFamily._dependencies,
        allTransitiveDependencies:
            DeleteScrapingRecordFamily._allTransitiveDependencies,
        ids: ids,
      );

  DeleteScrapingRecordProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.ids,
  }) : super.internal();

  final List<String> ids;

  @override
  Override overrideWith(
    FutureOr<void> Function(DeleteScrapingRecordRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: DeleteScrapingRecordProvider._internal(
        (ref) => create(ref as DeleteScrapingRecordRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        ids: ids,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<void> createElement() {
    return _DeleteScrapingRecordProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is DeleteScrapingRecordProvider && other.ids == ids;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, ids.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin DeleteScrapingRecordRef on AutoDisposeFutureProviderRef<void> {
  /// The parameter `ids` of this provider.
  List<String> get ids;
}

class _DeleteScrapingRecordProviderElement
    extends AutoDisposeFutureProviderElement<void>
    with DeleteScrapingRecordRef {
  _DeleteScrapingRecordProviderElement(super.provider);

  @override
  List<String> get ids => (origin as DeleteScrapingRecordProvider).ids;
}

String _$clearScrapingCacheHash() =>
    r'bec5cdafbcda736c1cea4ece4d145de4d03f4a20';

/// 清除搜索缓存
///
/// Copied from [clearScrapingCache].
@ProviderFor(clearScrapingCache)
final clearScrapingCacheProvider = AutoDisposeFutureProvider<void>.internal(
  clearScrapingCache,
  name: r'clearScrapingCacheProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$clearScrapingCacheHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef ClearScrapingCacheRef = AutoDisposeFutureProviderRef<void>;
String _$clearExpiredCacheHash() => r'f0d7a63aa44b9722087f5562fe5373723f22ce20';

/// 清除过期缓存
///
/// Copied from [clearExpiredCache].
@ProviderFor(clearExpiredCache)
final clearExpiredCacheProvider = AutoDisposeFutureProvider<void>.internal(
  clearExpiredCache,
  name: r'clearExpiredCacheProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$clearExpiredCacheHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef ClearExpiredCacheRef = AutoDisposeFutureProviderRef<void>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
