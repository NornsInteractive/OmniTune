import 'package:flutter/material.dart';

void showTopSnackBar(
  BuildContext context,
  String message, {
  Duration duration = const Duration(seconds: 3),
}) {
  final messenger = ScaffoldMessenger.of(context);
  final mediaQuery = MediaQuery.of(context);
  final topInset = mediaQuery.padding.top + 12;

  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        duration: duration,
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.fromLTRB(
          16,
          topInset,
          16,
          (mediaQuery.size.height - topInset - 76).clamp(24.0, double.infinity),
        ),
      ),
    );
}
