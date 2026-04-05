import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/settings/application/app_settings_controller.dart';

/// Global exception handler that shows error dialogs when debug mode is enabled.
class GlobalExceptionHandler {
  static void setup(WidgetRef ref) {
    FlutterError.onError = (FlutterErrorDetails details) {
      // Always report to console
      FlutterError.presentError(details);

      // Show debug dialog if debug mode is enabled
      final settingsAsync = ref.read(appSettingsControllerProvider);
      final isDebugEnabled = settingsAsync.valueOrNull?.enableDebugMode ?? false;

      if (isDebugEnabled) {
        _showErrorDialog(details.exception.toString(), details.stack?.toString() ?? '');
      }
    };

    // Also handle uncaught exceptions in async contexts
    PlatformDispatcher.instance.onError = (error, stack) {
      final settingsAsync = ref.read(appSettingsControllerProvider);
      final isDebugEnabled = settingsAsync.valueOrNull?.enableDebugMode ?? false;

      if (isDebugEnabled) {
        _showErrorDialog(error.toString(), stack.toString());
      }

      return true;
    };
  }

  static void _showErrorDialog(String error, String stackTrace) {
    // We can't show a dialog here without BuildContext
    // Instead, we'll use a more reliable approach with a global key
    _lastError = (error: error, stackTrace: stackTrace);
    _errorStreamController.add((error: error, stackTrace: stackTrace));
  }

  static final _errorStreamController = StreamController<({String error, String stackTrace})>.broadcast();

  static Stream<({String error, String stackTrace})> get errorStream => _errorStreamController.stream;

  static ({String error, String stackTrace})? _lastError;

  static ({String error, String stackTrace})? get lastError => _lastError;

  static void dispose() {
    _errorStreamController.close();
  }
}
