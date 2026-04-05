import 'package:flutter_riverpod/flutter_riverpod.dart' show Ref;
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../app/app_shell.dart';
import '../../features/library/presentation/albums_page.dart';
import '../../features/library/presentation/library_page.dart';
import '../../features/player/presentation/now_playing_page.dart';
import '../../features/settings/presentation/add_source_page.dart';
import '../../features/settings/presentation/settings_page.dart';

part 'app_router.g.dart';

@Riverpod(keepAlive: true)
GoRouter appRouter(Ref ref) {
  return GoRouter(
    initialLocation: '/albums',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return MusicAppShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/albums',
                builder: (context, state) => const AlbumsPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/collection',
                builder: (context, state) => const LibraryPage(),
                routes: [
                  GoRoute(
                    path: 'list/:section',
                    builder: (context, state) {
                      final section = LibraryCollectionSectionX.fromRouteValue(
                        state.pathParameters['section'] ?? 'all',
                      );
                      return LibrarySongsPage(section: section);
                    },
                  ),
                  GoRoute(
                    path: 'browser',
                    builder: (context, state) => const LibraryBrowserPage(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsPage(),
      ),
      GoRoute(
        path: '/player',
        builder: (context, state) => const NowPlayingPage(),
      ),
      GoRoute(
        path: '/settings/add-source',
        builder: (context, state) => const AddSourcePage(),
      ),
      GoRoute(
        path: '/settings/source/:sourceId',
        builder: (context, state) =>
            AddSourcePage(sourceId: state.pathParameters['sourceId']),
      ),
    ],
  );
}
