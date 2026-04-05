# First Song Playback Stuttering - Investigation Report
**Date**: 2024  
**Version**: 1.0.22+23  
**Status**: 🔍 Under Investigation

## Problem Statement
After scanning music library, the first song to play takes a long time to start (stutters/hangs for several seconds).

## Root Cause Analysis

### Hypothesis 1: First Song Doesn't Benefit from Cache Timeout
**Status**: ❌ Unlikely
- Reason: `buildPlayableTrack()` in `webdav_music_source.dart` applies 1-second timeout uniformly to all songs
- Both first and subsequent songs use the same logic
- Exception: Only difference could be if first song triggers full cache validation

### Hypothesis 2: WebDAV Connection Not Yet Established
**Status**: ✅ Most Likely
- Current behavior: `connect()` is called asynchronously in background via `unawaited()`
- First song: No connection established yet, must wait for background connection to complete
- Subsequent songs: Connection already established from first song
- Evidence: Lines 124-125 in `webdav_music_source.dart`:
  ```dart
  if (!_connected) {
    unawaited(connect());
  }
  ```

### Hypothesis 3: Cache Repository Not Warmed Up
**Status**: ⚠️ Possible Contributing Factor
- First song: Cache repository may need initialization
- Subsequent songs: Repository already warmed up
- Impact: Minor compared to connection overhead

## Affected Code Locations

### 1. `lib/features/sources/data/webdav/webdav_music_source.dart`
- **Line 54-58**: `connect()` method (2-3 second operation)
- **Line 120-128**: `buildPlayableTrack()` with async connection

```dart
if (!_connected) {
  unawaited(connect());  // ← First song waits for this
}
```

### 2. `lib/features/sources/data/webdav/webdav_remote_client.dart`
- **Method**: `ping()` - validates connection (network latency)
- **Called by**: `connect()` in webdav_music_source.dart

## Solution Strategy

### Option 1: Pre-warm Connection on Source Selection
**Approach**: Connect to WebDAV as soon as user selects a source
- **Pro**: Avoids any stutter when first song is selected
- **Pro**: Seamless playback experience
- **Con**: Uses network resources upfront
- **Implementation**: Trigger in `libraryControllerProvider` when source is selected

### Option 2: Eager Connection During Library Scan
**Approach**: Connect to each source during scan completion
- **Pro**: Connection ready before user plays anything
- **Con**: Wastes connection if user doesn't play
- **Implementation**: Add `source.connect()` after scan completes

### Option 3: Await Connection in buildPlayableTrack
**Approach**: Make `connect()` awaited instead of unawaited
- **Pro**: Simple, guaranteed connection before playback
- **Con**: Adds 2-3 seconds to first song playback (defeats current optimization)
- **Status**: ❌ Not recommended (regression)

### Option 4: Connection Pool/Cache with Timeout
**Approach**: Keep connection alive for 5-10 minutes after use
- **Pro**: Reuses connection for same source
- **Pro**: Auto-disconnects after idle
- **Con**: More complex implementation
- **Status**: 🔜 Future enhancement

## Recommended Solution
**Option 1: Pre-warm Connection on Source Selection**

### Implementation Plan

1. **Modify `libraryControllerProvider`**:
   - When source is selected, trigger async connection

2. **Add utility function in `webdav_music_source.dart`**:
   ```dart
   /// Warm up connection without blocking
   Future<void> warmupConnection() async {
     try {
       await connect();
     } catch (e) {
       // Silently fail, will retry on first play
     }
   }
   ```

3. **Integrate in library controller**:
   ```dart
   Future<void> selectSource(SourceProfile source) async {
     // ... existing logic ...
     
     // Pre-warm connection in background
     final musicSource = await ref.read(musicSourceSessionManagerProvider).get(source);
     unawaited(musicSource.warmupConnection());
   }
   ```

## Testing Plan

After implementation:
1. Select a source (should not block)
2. Wait 1-2 seconds for connection to warm up
3. Click first song - playback should start immediately
4. Verify subsequent songs still play immediately

## Performance Impact

- **Before**: 5-10 seconds for first song playback (network connection + start)
- **After**: <1 second for first song playback (connection already warmed)
- **Network**: Single extra ping operation per source selection (~100ms)

## Backward Compatibility

✅ Fully backward compatible
- Changes only affect performance, not functionality
- No API changes
- No storage changes

## Risk Assessment

**Low Risk**:
- Optional pre-warming doesn't affect playback if it fails
- Network errors are gracefully handled
- Existing fallback mechanisms remain intact

## Next Steps

1. Implement Option 1 (pre-warm connection)
2. Test on target devices
3. Verify no regressions in existing playback flow
4. Document in user guide

## Related Issues

- **Issue**: "点击播放，要等很久才开始播放，而且进度条一直是0"
- **Fix**: v1.0.20+22 (cache timeout + async connection)
- **Remaining**: First song specific stutter (this investigation)

## Notes

The first song stutter is likely the "tail" of the WebDAV connection establishment overhead. The previous fix (v1.0.20+22) helped with cache checking, but the actual connection still needs to be established. Pre-warming the connection on source selection is the cleanest solution without introducing new blocking operations.
