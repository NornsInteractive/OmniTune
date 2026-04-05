# Debug Mode User Guide

## Overview
The Flux Music player now includes a **Debug Mode** feature that helps diagnose problems when the app encounters errors.

## Enabling Debug Mode

1. Open the **Settings** page (gear icon in top-right corner)
2. Scroll to the bottom of the settings list
3. Look for the **"Developer"** section
4. Toggle **"Debug mode"** ON
5. The setting is saved automatically

## What Debug Mode Does

When Debug Mode is enabled:
- If the app encounters any error or exception, a dialog will automatically appear
- The dialog shows:
  - **Error message**: A description of what went wrong
  - **Stack trace**: Technical details about where the error occurred
- You can select and copy any text from the error dialog

## Using the Error Dialog

1. **Reading the error**: The error message at the top describes what went wrong
2. **Understanding the stack trace**: The stack trace shows the execution path that led to the error
3. **Copying error information**:
   - Long-press any text to select it
   - Or triple-tap to select all text
   - Use the copy button that appears
4. **Sharing the error**:
   - Copy the error dialog text
   - Share it with developers or support team
   - Include: what you were doing when the error occurred

## Disabling Debug Mode

To stop seeing error dialogs:
1. Open Settings
2. Scroll to "Developer" section
3. Toggle "Debug mode" OFF
4. Error dialogs will no longer appear

## Example Error Dialog

```
Error:
Exception: WebDAV connection failed: Connection timeout

Stack Trace:
#0 WebDavRemoteClient.ping (package:music/features/sources/data/webdav/webdav_remote_client.dart:123)
#1 WebDavMusicSource.connect (package:music/features/sources/data/webdav/webdav_music_source.dart:54)
#2 WebDavMusicSource.buildPlayableTrack (package:music/features/sources/data/webdav/webdav_music_source.dart:119)
#3 PlayerController._playRemoteEntry (package:music/features/player/application/player_controller.dart:208)
...
```

## When to Use Debug Mode

### ✅ Enable Debug Mode If:
- You're troubleshooting a problem
- The app keeps crashing
- Something isn't working as expected
- Support staff asks you to enable it

### ❌ Turn Off Debug Mode:
- In normal use (dialogs may distract from listening)
- When the issue is resolved
- If you prefer not to see technical information

## Common Errors

### "WebDAV connection failed"
- Check your WebDAV server address
- Verify username and password
- Ensure the server is online

### "Playback could not be started"
- The file format might not be supported
- The file might be corrupted
- Check server connectivity

### "File not found"
- The file or path no longer exists
- The source may have been moved or deleted
- Re-scan the library

## Sharing Error Information

If you encounter an error:
1. **Note the time** when it occurred
2. **Note what you were doing** (playing, scanning, etc.)
3. **Enable Debug Mode**
4. **Reproduce the error** if possible
5. **Copy the error dialog**
6. **Share with support**:
   - Include the error message and stack trace
   - Include what action triggered it
   - Include the timestamp

## Privacy

The error information shown in Debug Mode is local to your device. It is NOT automatically sent anywhere unless you manually share it.

## Advanced: Interpreting Stack Traces

For technical users, the stack trace shows:
- **File path**: Where in the code the error occurred
- **Line number**: Which line in the source code
- **Function name**: Which function was running
- **Call stack**: The sequence of function calls that led to the error

## Troubleshooting Debug Mode

### "Debug Mode toggle doesn't work"
- Make sure you're in Settings (gear icon)
- Scroll to the bottom to find Developer section
- Try toggling it off and on again

### "Error dialog won't close"
- Tap the "Close" button in the dialog
- Or back out with the back button

### "I don't see error dialogs even with Debug Mode ON"
- The app might not be experiencing errors
- Errors only appear when something actually goes wrong
- Try to reproduce the error

## Questions?

For questions about Debug Mode or to report issues:
- Check the app settings
- Review this guide
- Contact support with the error information from Debug Mode

---

**Version**: 1.0.22+23  
**Last Updated**: 2024  
**Languages**: English, 中文
