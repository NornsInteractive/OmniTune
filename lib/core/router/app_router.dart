import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show Ref;
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../app/app_shell.dart';
import '../../core/models/source_protocol.dart';
import '../../features/debug/presentation/debug_logs_page.dart';
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
                    redirect: (context, state) => '/browser',
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/browser',
                builder: (context, state) => const LibraryBrowserPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/debug-logs',
                builder: (context, state) => const DebugLogsPage(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(path: '/home', redirect: (context, state) => '/albums'),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsPage(),
      ),
      GoRoute(
        path: '/player',
        pageBuilder: (context, state) => CustomTransitionPage<void>(
          key: state.pageKey,
          child: const NowPlayingPage(),
          transitionDuration: const Duration(milliseconds: 260),
          reverseTransitionDuration: const Duration(milliseconds: 220),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final curvedAnimation = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            );

            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 1),
                end: Offset.zero,
              ).animate(curvedAnimation),
              child: child,
            );
          },
        ),
      ),
      GoRoute(
        path: '/settings/add-source',
        builder: (context, state) => const SourceTypeSelectionPage(),
        routes: [
          GoRoute(
            path: ':protocol',
            builder: (context, state) {
              final protocol = SourceProtocolX.fromStorageValue(
                state.pathParameters['protocol'] ?? '',
              );
              return AddSourcePage(initialProtocol: protocol);
            },
          ),
        ],
      ),
      GoRoute(
        path: '/settings/source/:sourceId',
        builder: (context, state) =>
            AddSourcePage(sourceId: state.pathParameters['sourceId']),
      ),
    ],
  );
}
