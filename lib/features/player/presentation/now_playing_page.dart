import 'package:flutter/material.dart';

import 'widgets/now_playing_panel.dart';

class NowPlayingPage extends StatelessWidget {
  const NowPlayingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.surface,
      body: const SafeArea(child: NowPlayingPanel()),
    );
  }
}
