import 'package:flutter/material.dart';
import 'package:music/l10n/app_localizations.dart';

import 'widgets/now_playing_panel.dart';

class NowPlayingPage extends StatelessWidget {
  const NowPlayingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.playerTitle)),
      body: const NowPlayingPanel(),
    );
  }
}
