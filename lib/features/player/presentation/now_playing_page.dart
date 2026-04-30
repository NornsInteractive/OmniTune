import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/studio_chrome.dart';
import '../application/player_controller.dart';
import 'widgets/now_playing_panel.dart';

class NowPlayingPage extends ConsumerWidget {
  const NowPlayingPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasTrack = ref.watch(
      playerControllerProvider.select((state) => state.hasTrack),
    );

    return Scaffold(
      backgroundColor: colorScheme.surface.withValues(alpha: 0),
      body: StudioBackdrop(
        maxContentWidth: 980,
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
        showBackgroundImage: !hasTrack,
        child: const SafeArea(child: NowPlayingPanel()),
      ),
    );
  }
}
