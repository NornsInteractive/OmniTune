import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/database/library_scan_cache_repository.dart';

part 'scan_cache_provider.g.dart';

/// 提供 LibraryScanCacheRepository 实例
@riverpod
Future<LibraryScanCacheRepository> scanCacheRepository(Ref ref) async {
  return createScanCacheRepository();
}
