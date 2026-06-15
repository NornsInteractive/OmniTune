import 'library_scan_cache_repository_impl_web.dart'
    if (dart.library.io) 'library_scan_cache_repository_impl_io.dart' as impl;
import 'library_scan_cache_repository_contract.dart';

export 'library_scan_cache_repository_contract.dart';

Future<LibraryScanCacheRepository> createScanCacheRepository() {
  return impl.createScanCacheRepository();
}
