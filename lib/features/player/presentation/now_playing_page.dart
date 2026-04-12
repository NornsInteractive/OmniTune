import 'package:flutter/material.dart';

import '../../../core/widgets/studio_chrome.dart';
import 'widgets/now_playing_panel.dart';

class NowPlayingPage extends StatelessWidget {
  const NowPlayingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface.withValues(alpha: 0),
      body: StudioBackdrop(
        maxContentWidth: 980,
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
        child: const SafeArea(child: NowPlayingPanel()),
      ),
    );
  }
}
