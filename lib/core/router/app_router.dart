import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show Ref;
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../app/app_shell.dart';
import '../../core/models/source_protocol.dart';
import '../../features/debug/presentation/debug_logs_page.dart';
import '../../features/landing/presentation/web_landing_page.dart';
import '../../features/library/presentation/albums_page.dart';
import '../../features/library/presentation/library_page.dart';
import '../../features/player/presentation/now_playing_page.dart';
import '../../features/settings/presentation/add_source_page.dart';
import '../../features/settings/presentation/settings_page.dart';

part 'app_router.g.dart';

@Riverpod(keepAlive: true)
GoRouter appRouter(Ref ref) {
  return GoRouter(
    initialLocation: kIsWeb ? '/' : '/albums',
    routes: [
      GoRoute(
        path: '/',
        redirect: (context, state) => kIsWeb ? null : '/albums',
        builder: (context, state) => const WebLandingPage(),
      ),
      GoRoute(path: '/app', redirect: (context, state) => '/albums'),
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
        pageBuilder: (context, state) {
          final disableAnimations = MediaQuery.disableAnimationsOf(context);
          return CustomTransitionPage<void>(
            key: state.pageKey,
            child: const NowPlayingPage(),
            transitionDuration: disableAnimations
                ? Duration.zero
                : const Duration(milliseconds: 220),
            reverseTransitionDuration: disableAnimations
                ? Duration.zero
                : const Duration(milliseconds: 180),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
                  if (disableAnimations) {
                    return child;
                  }
                  final curvedAnimation = CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                    reverseCurve: Curves.easeInCubic,
                  );

                  return SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.2),
                      end: Offset.zero,
                    ).animate(curvedAnimation),
                    child: FadeTransition(
                      opacity: curvedAnimation,
                      child: child,
                    ),
                  );
                },
          );
        },
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
