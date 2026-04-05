# Quick Reference: Debug Mode Feature

## What Was Added
A global debug mode feature that shows exception dialogs with copyable error text when enabled.

## How to Use

### For Users
1. Open Settings (gear icon top-right)
2. Scroll to bottom, find "Developer" section
3. Toggle "Debug mode" ON
4. If the app encounters an error, a dialog will appear with the error details
5. Select and copy the error text if needed
6. Toggle OFF when done debugging

### For Developers
To manually test the feature, create a debug-triggering button:

```dart
FilledButton(
  onPressed: () => throw Exception('Test error'),
  child: const Text('Trigger Debug Dialog'),
)
```

## Files Changed
- `lib/core/storage/library_preferences_repository.dart` - Added debug flag storage
- `lib/features/settings/application/app_settings_controller.dart` - Added toggle method
- `lib/app/app.dart` - Integrated exception handler widget
- `lib/features/settings/presentation/settings_page.dart` - Added settings UI
- `lib/l10n/app_en.arb` - English strings
- `lib/l10n/app_zh.arb` - Chinese strings

## Files Created
- `lib/core/exception_handler.dart` - Global exception handling logic
- `lib/core/widgets/exception_handler_widget.dart` - Exception dialog UI

## Version
- Current: v1.0.22+23
- Previous: v1.0.21+22

## Status
✅ Complete and tested. Ready for production.
