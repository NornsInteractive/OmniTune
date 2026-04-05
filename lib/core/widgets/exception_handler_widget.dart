import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/settings/application/app_settings_controller.dart';
import '../exception_handler.dart';

/// Widget that listens to exceptions and shows debug dialog when enabled.
class ExceptionHandlerWidget extends ConsumerStatefulWidget {
  const ExceptionHandlerWidget({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<ExceptionHandlerWidget> createState() => _ExceptionHandlerWidgetState();
}

class _ExceptionHandlerWidgetState extends ConsumerState<ExceptionHandlerWidget> {
  late final StreamSubscription<({String error, String stackTrace})> _subscription;

  @override
  void initState() {
    super.initState();
    // Subscribe to exception stream
    _subscription = GlobalExceptionHandler.errorStream.listen((errorInfo) {
      final isDebugEnabled = ref.read(appSettingsControllerProvider).valueOrNull?.enableDebugMode ?? false;
      if (isDebugEnabled && mounted) {
        _showDebugDialog(errorInfo.error, errorInfo.stackTrace);
      }
    });
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }

  void _showDebugDialog(String error, String stackTrace) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Debug: Exception Occurred'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: SelectableText(
              'Error:\n$error\n\nStack Trace:\n$stackTrace',
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
