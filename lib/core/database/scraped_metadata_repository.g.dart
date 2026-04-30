// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'scraped_metadata_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$scrapedMetadataRepositoryHash() =>
    r'6d32ffa68e709686bbe39b50d333b4d04a605eed';

/// See also [scrapedMetadataRepository].
@ProviderFor(scrapedMetadataRepository)
final scrapedMetadataRepositoryProvider =
    AutoDisposeFutureProvider<ScrapedMetadataRepository>.internal(
      scrapedMetadataRepository,
      name: r'scrapedMetadataRepositoryProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$scrapedMetadataRepositoryHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef ScrapedMetadataRepositoryRef =
    AutoDisposeFutureProviderRef<ScrapedMetadataRepository>;
String _$scrapedMetadataCacheHash() =>
    r'e78737783d5c7279bfeffa48177349ab3a3318b0';

/// 已加载的刮削结果缓存
///
/// Copied from [ScrapedMetadataCache].
@ProviderFor(ScrapedMetadataCache)
final scrapedMetadataCacheProvider =
    AutoDisposeAsyncNotifierProvider<
      ScrapedMetadataCache,
      Map<String, ScrapedSongMetadata>
    >.internal(
      ScrapedMetadataCache.new,
      name: r'scrapedMetadataCacheProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$scrapedMetadataCacheHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$ScrapedMetadataCache =
    AutoDisposeAsyncNotifier<Map<String, ScrapedSongMetadata>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
