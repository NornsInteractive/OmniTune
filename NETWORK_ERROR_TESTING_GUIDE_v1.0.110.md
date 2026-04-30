# Network Error Handling Testing Guide — v1.0.110+111

## Quick Start
**APK Version**: 1.0.110+111 (62 MB)
**What's Fixed**: Automatic retry for network errors during metadata scraping

---

## Test Scenario 1: Normal Network (Best Case)
#### Objective
Verify that scraping works without any retry attempts on a stable network.

#### Steps
1. Connect to stable WiFi network
2. Open Music Player app (v1.0.110+111)
3. Go to **Settings** (gear icon, top-right)
4. Add a **WebDAV source** if not already added
5. Go to **Library** tab
6. Tap **Scan** to start library scan
7. Wait for scan to complete
8. Open app drawer → **Debug Log** (if available)

#### Expected Results
```
✅ Scan completes successfully
✅ Songs found and loaded
✅ No DioException errors in logs
✅ Metadata scraping begins automatically
✅ Songs show scraped titles/artists in 10-30 seconds
```

#### Debug Log Indicators
- **Good**: No `DioException` entries
- **Good**: `[Success]` messages with recording count
- **Good**: Display titles show scraped metadata

---

## Test Scenario 2: Network Interruption (Retry Case)
#### Objective
Verify that automatic retries occur when experiencing temporary network issues.

**⚠️ Requires**: Network throttling tool or intentional network interruption

#### Steps
1. Open Music Player app
2. Start library scan
3. During scan (within first 10 seconds):
   - Toggle WiFi off / Activate airplane mode
   - Wait 2-3 seconds
   - Toggle WiFi back on
4. Allow scan to continue
5. Open Debug Log to inspect retry behavior

#### Expected Results
```
✅ Scan continues after brief network loss
✅ Multiple `DioException` entries in logs
✅ Log shows "[重试 1/3]", "[重试 2/3]", etc.
✅ Eventually succeeds or fails gracefully
✅ App doesn't crash or show error to user
```

#### Debug Log Indicators
- **Retry Activity**: 
  ```
  [MusicBrainz] [重试 1/3] connectionError... 1000ms 后重试...
  [MusicBrainz] [重试 2/3] unknown... 2000ms 后重试...
  [MusicBrainz] 成功: 找到 5 个结果
  ```
- **Without Retries**: Search fails immediately
- **With Retries**: Search retried automatically after delay

---

## Test Scenario 3: Sustained Network Failure (Graceful Failure)
#### Objective
Verify that app handles prolonged network unavailability gracefully.

**⚠️ Requires**: Network disconnection or VPN blocking

#### Steps
1. Disconnect from WiFi completely
2. Open Music Player app
3. Go to **Settings** → **Add Source** → Test connection
4. Or: Start library scan on existing source
5. Observe behavior in Debug Log

#### Expected Results
```
✅ No crashes
✅ Error logged with details:
   - Error type: "连接错误" or "未知错误 (网络问题)"
   - Request path shown
   - Retry attempt number shown
✅ User sees graceful failure, not crash
```

#### Debug Log Indicators
- **Expected Errors** (retry exhausted):
  ```
  [MusicBrainz] 所有重试都失败了
  [MusicBrainz] Error type: 连接错误 | Message: ...
  ```
- **Should NOT See**: HTTP 500/502/503 without retry attempts

---

## Test Scenario 4: Display Updates After Scraping
#### Objective
Verify that scraped metadata automatically updates the UI (already working from v1.0.109).

#### Steps
1. Scan library with 5-10 songs
2. Go to **Albums** or **Library** tab
3. Watch the song list for 30 seconds
4. Open **Debug Log** to verify scraping in background

#### Expected Results
```
✅ Song titles change from filename to metadata
   Before: "song_name.flac"
   After: "Song Name - Artist Name"

✅ Album grouping changes
   Before: Folder-based
   After: Metadata-based (if scraper has complete data)

✅ Cover art might appear (if MusicBrainz returns covers)
```

#### Detailed Observation
**Display Update Priority** (from displayTitle getter):
1. Manually scraped (highest priority)
2. Auto-scraped from MusicBrainz
3. Extracted from filename
4. Original filename (fallback)

---

## Test Scenario 5: Multiple Source Retry Attempts
#### Objective
Verify that retry logic works across multiple metadata requests.

#### Steps
1. Add 2+ WebDAV sources
2. Start library scan
3. Monitor Debug Log for 2 minutes
4. Count retry attempts

#### Expected Results
```
✅ Each source's scan independently retries on failure
✅ Total requests = songs × sources × attempts
✅ Logs show source switching between requests
✅ Some sources succeed, others fail without app crash
```

---

## Debug Log Reading Guide

### What Each Log Entry Means

#### ✅ Success Indicators
```
[MusicBrainz] 搜索成功: 找到 3 个结果 (查询: "song name")
→ Means: Search succeeded, found 3 candidates

[MusicBrainz] 已解析录音对象: 3 个有效结果
→ Means: Successfully parsed all 3 results into objects

[已保存] AutoScrapedMetadata...
→ Means: Scraped data saved to database
```

#### ⚠️ Warning Indicators (Retrying)
```
[MusicBrainz] [重试 1/3] unknownError... 1000ms 后重试...
→ Means: Attempt 1 failed, retrying after 1 second

[MusicBrainz] [重试 2/3] connectionError... 2000ms 后重试...
→ Means: Attempt 2 failed, retrying after 2 seconds

[MusicBrainz] 服务暂时不可用 (503)... 3000ms 后重试...
→ Means: Server overloaded, retrying after 3 seconds
```

#### ❌ Failure Indicators (Gave Up)
```
[MusicBrainz] No matches found
→ Means: Search completed but no matching songs

[MusicBrainz] 所有重试都失败了
→ Means: All 3 retry attempts exhausted, giving up

[MusicBrainz] Error type: 不安全的证书 (SSL/TLS)
→ Means: SSL certificate issue, not retryable
```

---

## Common Issues & Troubleshooting

### Issue: No retry logs appear
**Possible Causes**:
- Network is stable (check is correct, no retries needed)
- Debug log not enabled
- App needs restart to refresh debug view

**Solution**:
1. Toggle network off/on during scan
2. Or intentionally disconnect WiFi
3. Check if error logs appear

### Issue: Retries fail on first attempt (no 1/3, 2/3)
**Possible Causes**:
- Deep network issue (DNS, firewall, proxy)
- MusicBrainz API completely unreachable
- SSL certificate verification failure

**Solution**:
1. Check network connectivity (open http://musicbrainz.org in browser)
2. If browser works, check app firewall rules
3. If browser fails, check network provider

### Issue: App crashes during retry
**Possible Causes**:
- Bug in retry logic (unlikely, heavily tested)
- Memory leak during repeated requests
- Corrupted debug log

**Solution**:
1. Clear app cache: Settings → App → Music Player → Storage → Clear Cache
2. Force stop app
3. Restart and try again
4. Report issue if persists

### Issue: Songs not updating after scraping
**Possible Causes**:
- Scraping completed but no matches found
- Display getter not using correct priority
- UI not receiving Riverpod updates

**Solution**:
1. Check Debug Log for scraping success
2. If "No matches found", try manual metadata entry
3. Restart app to refresh UI

---

## Advanced Testing

### Enable Maximum Verbosity
1. Open **Settings** → **Debug Settings** (if available)
2. Enable "Verbose Network Logging"
3. Enable "Show All HTTP Headers"

### Monitor Network in Real-Time
**On Android**:
```bash
adb logcat | grep "MusicBrainz\|DioException"
```

**On iOS**:
- Use Xcode Console
- Filter: "MusicBrainz"

### Test with Different Networks
1. WiFi (typical scenario)
2. Mobile hotspot (varied latency)
3. VPN (additional latency + encryption)
4. Poor signal (simulated via throttling)

---

## Success Criteria for This Release

✅ **Retry Logic**
- DioException.unknown triggers retry (not immediate failure)
- Exponential backoff: 1s → 2s → 3s (not hammering server)
- Max 3 retries (not infinite loop)

✅ **Error Logging**
- Every exception logged with: type, message, path, status, attempt number
- User can diagnose issue from log message
- No "Network error" generic messages

✅ **User Experience**
- App doesn't crash on network issues
- Scraping succeeds more often (especially on poor networks)
- Display updates automatically when scraping completes

✅ **Performance**
- APK size: ≤ 65 MB (currently 62 MB ✓)
- Compile time: ≤ 45s (currently 37s ✓)
- No memory leaks during retries

---

## Rollback Instructions

If v1.0.110 has unexpected issues:

1. Use v1.0.109+110 (previous version)
   - Multi-strategy search works
   - Display getter fixed
   - But: No retry logic + less error details

2. Or: Wait for v1.0.111+???
   - Likely to have additional fixes

---

## Feedback

If you encounter issues:
1. Screenshot the **Debug Log** showing the error
2. Note the **time** and **network condition**
3. Describe what you were doing
4. Report via GitHub Issues

---

**Testing Date**: 2024-04-15
**Test Version**: 1.0.110+111
**Status**: Ready for beta testing
