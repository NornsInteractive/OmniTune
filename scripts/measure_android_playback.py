#!/usr/bin/env python3
'''OmniTune Android playback measurement script.'''

import argparse
import csv
import io
import json
import math
import os
import re
import shlex
import subprocess
import sys
import tempfile
import time
import urllib.parse
import urllib.request
from contextlib import redirect_stdout, redirect_stderr
from datetime import datetime
from pathlib import Path

PKG = "com.norns.omnitune"
DEFAULT_SECONDS = 1800
DEFAULT_OUTPUT_DIR = "measurement_output"
SAMPLE_INTERVAL = 5


def parse_meminfo(stdout: str):
    m = re.search(r"TOTAL PSS:\s*(\d+)\s+TOTAL RSS:\s*(\d+)", stdout)
    if not m:
        return None, None
    return int(m.group(1)), int(m.group(2))


def parse_media_session(stdout: str):
    state = None
    position_ms = None
    track = {"title": "", "artist": ""}

    idx = stdout.find("package=" + PKG)
    if idx == -1:
        return state, position_ms, track

    next_idx = stdout.find("package=", idx + len("package=" + PKG))
    segment = stdout[idx:] if next_idx == -1 else stdout[idx:next_idx]

    m = re.search(
        r"state=PlaybackState\s*\{[^}]*?state=(\w+)\((\d+)\)[^}]*?position=(\d+)",
        segment,
    )
    if m:
        state = int(m.group(2))
        position_ms = int(m.group(3))
    else:
        m = re.search(r"state=(?:(\w+)\()?(\d+)\)?", segment)
        if m:
            state = int(m.group(2))

    m = re.search(r"metadata:\s*size=\d+,\s*description=(.*)", segment)
    if m:
        parts = [p.strip() for p in m.group(1).split(",")]
        if len(parts) >= 2:
            track["title"] = parts[0]
            track["artist"] = parts[1]
        elif len(parts) == 1 and parts[0]:
            track["title"] = parts[0]

    return state, position_ms, track


def parse_foreground_activity(stdout: str) -> str | None:
    if not stdout:
        return None
    for line in stdout.splitlines():
        m = re.search(
            r"\b(?:topResumedActivity|mResumedActivity|ResumedActivity)\s*[=:]\s*"
            r"ActivityRecord\{[^}]*?\s([\w.]+)/",
            line,
        )
        if m:
            return m.group(1)
    return None


def _vm_get(base_url: str, path: str, params: dict | None = None) -> str | None:
    try:
        url = "%s/%s" % (base_url.rstrip("/"), path)
        if params:
            url += "?" + urllib.parse.urlencode(params)
        req = urllib.request.Request(url)
        with urllib.request.urlopen(req, timeout=10) as resp:
            return resp.read().decode(errors="replace")
    except Exception:
        return None


def vm_set_flags(base_url: str) -> bool:
    result = _vm_get(base_url, "setVMTimelineFlags", {"recordedStreams": "[Dart,Embedder]"})
    if result is None:
        return False
    try:
        body = json.loads(result)
    except (ValueError, TypeError):
        return False
    if not isinstance(body, dict):
        return False
    rpc_result = body.get("result")
    if not isinstance(rpc_result, dict):
        return False
    return rpc_result.get("type") == "Success"


def vm_get_timeline_raw(base_url: str) -> str | None:
    return _vm_get(base_url, "getVMTimeline")


def _timeline_from_raw(raw: str | None) -> dict | None:
    if raw is None:
        return None
    try:
        body = json.loads(raw)
    except (ValueError, TypeError):
        return None
    if not isinstance(body, dict):
        return None
    result = body.get("result")
    return result if isinstance(result, dict) else None


def vm_get_timeline(base_url: str) -> dict | None:
    return _timeline_from_raw(vm_get_timeline_raw(base_url))


def vm_clear_timeline(base_url: str) -> bool:
    raw = _vm_get(base_url, "clearVMTimeline")
    if raw is None:
        return False
    try:
        body = json.loads(raw)
    except (ValueError, TypeError):
        return False
    if not isinstance(body, dict):
        return False
    rpc_result = body.get("result")
    if not isinstance(rpc_result, dict):
        return False
    return rpc_result.get("type") == "Success"


def _percentile(sorted_vals: list[float], pct: float) -> float:
    if not sorted_vals:
        return 0.0
    idx = min(int(len(sorted_vals) * pct / 100), len(sorted_vals) - 1)
    return sorted_vals[idx]


def _stats(vals_ms: list[float]):
    if not vals_ms:
        return "not measured"
    s = sorted(vals_ms)
    return {
        "count": len(s),
        "p50": _percentile(s, 50),
        "p95": _percentile(s, 95),
        "p99": _percentile(s, 99),
        "max": s[-1],
        "over_16_67ms": sum(1 for v in s if v > 16.67),
    }


def _finite_num(value):
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        return None
    try:
        f = float(value)
    except (TypeError, ValueError):
        return None
    return f if math.isfinite(f) else None


def parse_timeline_events(trace_events, pending_ui=None, pending_raster=None):
    if pending_ui is None:
        pending_ui = {}
    if pending_raster is None:
        pending_raster = {}
    ui_ms = []
    raster_ms = []

    for ev in trace_events or []:
        if not isinstance(ev, dict):
            continue
        name = ev.get("name", "")
        phase = ev.get("ph", "")
        ts = _finite_num(ev.get("ts", 0))
        if ts is None:
            continue
        dur = _finite_num(ev.get("dur", 0))

        if name == "Frame":
            if phase == "X":
                if dur and dur > 0:
                    ui_ms.append(dur / 1000.0)
            else:
                eid = ev.get("id")
                if eid is None:
                    continue
                if phase == "b":
                    pending_ui[eid] = ts
                elif phase == "e" and eid in pending_ui:
                    delta = ts - pending_ui.pop(eid)
                    if delta >= 0:
                        ui_ms.append(delta / 1000.0)
        elif name == "GPURasterizer::Draw":
            if phase == "X":
                if dur and dur > 0:
                    raster_ms.append(dur / 1000.0)
            else:
                tid = ev.get("tid")
                if tid is None:
                    continue
                if phase == "B":
                    pending_raster[tid] = ts
                elif phase == "E" and tid in pending_raster:
                    delta = ts - pending_raster.pop(tid)
                    if delta >= 0:
                        raster_ms.append(delta / 1000.0)

    return ui_ms, raster_ms, pending_ui, pending_raster


def adb(serial: str | None, cmd) -> tuple[str, int]:
    prefix = ["adb", "-s", serial] if serial else ["adb"]
    args_list = shlex.split(cmd) if isinstance(cmd, str) else list(cmd)
    try:
        result = subprocess.run(prefix + args_list, capture_output=True, text=True, timeout=30)
        return result.stdout, result.returncode
    except Exception:
        return "", -1


def adb_pid(serial: str | None) -> str | None:
    out, rc = adb(serial, "shell pidof %s" % PKG)
    if rc != 0:
        return None
    return out.strip() or None


def count_fatal(serial: str | None, pid: str | None):
    if not pid:
        return None, False
    out, rc = adb(serial, "logcat -d -b crash --pid=%s" % pid)
    if rc != 0:
        return None, False
    return len(re.findall(r"FATAL EXCEPTION", out)), True


def _save_raw_timeline(output_dir: str, sample: int, raw: str) -> bool:
    path = Path(output_dir, "timeline-%d.json" % sample)
    try:
        with open(path, "w") as f:
            f.write(raw)
        return True
    except OSError:
        return False


def self_test():
    print("=== Self-test: parsing validation ===")

    mem = (
        "** MEMINFO in pid 12345 [com.norns.omnitune] **\n"
        "           Pss  Private  Private     Swap      Rss\n"
        "         Total    Dirty    Clean    Dirty    Total\n"
        " Native Heap    54321    54200        0        0    32100\n"
        "Dalvik Heap    12345    12000        0        0    15000\n"
        "TOTAL PSS: 282383 TOTAL RSS: 417496\n"
    )
    pss, rss = parse_meminfo(mem)
    assert pss == 282383 and rss == 417496
    print("  meminfo TOTAL PSS/RSS: OK (PSS=%d, RSS=%d)" % (pss, rss))

    pss2, rss2 = parse_meminfo("** MEMINFO in pid 1 [other.app] **\n")
    assert pss2 is None and rss2 is None
    print("  meminfo without TOTAL: OK (None, None)")

    session = (
        "Global priority session is com.android.server.telecom/HeadsetMediaButton (userId=0)\n"
        "  HeadsetMediaButton com.android.server.telecom/HeadsetMediaButton (userId=0)\n"
        "    package=com.android.server.telecom\n"
        "    state=PlaybackState {state=STOPPED(1), position=0, ...}\n"
        "    metadata: size=3, description=Other, Artist, x\n"
        "User Records:\n"
        "  FlutterMainActivity com.norns.omnitune/FlutterMainActivity (userId=0)\n"
        "    ownerPid=27055, ownerUid=10046, userId=0\n"
        "    package=com.norns.omnitune\n"
        "    state=PlaybackState {state=PLAYING(3), position=23321, bufferedPosition=90000, speed=1.0}\n"
        "    metadata: size=17, description=以父之名, 周杰伦 • 叶惠美, api.cloud.189.cn\n"
        "    queueTitle=null, size=0\n"
        "User Records:\n"
        "  Another com.other.app/Activity (userId=0)\n"
        "    package=com.other.app\n"
        "    state=PlaybackState {state=PAUSED(2), position=999, ...}\n"
        "    metadata: size=5, description=Wrong, Track, y\n"
    )
    state, pos, track = parse_media_session(session)
    assert state == 3 and pos == 23321
    assert track["title"] == "以父之名"
    assert track["artist"] == "周杰伦 • 叶惠美"
    print("  media_session PLAYING+position+metadata: OK")

    s2, p2, t2 = parse_media_session("")
    assert s2 is None and p2 is None
    assert t2 == {"title": "", "artist": ""}
    print("  media_session empty: OK")

    s3, p3, t3 = parse_media_session("package=com.other.app\nstate=PlaybackState {state=PLAYING(3), position=100, ...}\n")
    assert s3 is None and p3 is None
    print("  media_session cross-app isolation: OK")

    events = [
        {"name": "Frame", "ph": "b", "id": 1, "ts": 1000000},
        {"name": "Frame", "ph": "e", "id": 1, "ts": 1020000},
        {"name": "GPURasterizer::Draw", "ph": "B", "tid": 5, "ts": 1001000},
        {"name": "GPURasterizer::Draw", "ph": "E", "tid": 5, "ts": 1009000},
        {"name": "Frame", "ph": "X", "ts": 2000000, "dur": 8000},
        {"name": "GPURasterizer::Draw", "ph": "X", "ts": 2001000, "dur": 5000},
        {"name": "Frame Request Pending", "ph": "X", "dur": 9999},
        {"name": "Other Rasterizer", "ph": "X", "dur": 7777},
        {"name": "OtherEvent", "ph": "b", "id": 99, "ts": 1},
    ]
    ui, raster, _, _ = parse_timeline_events(events, {}, {})
    assert len(ui) == 2 and abs(ui[0] - 20.0) < 0.01 and abs(ui[1] - 8.0) < 0.01
    assert len(raster) == 2 and abs(raster[0] - 8.0) < 0.01 and abs(raster[1] - 5.0) < 0.01
    print("  VM timeline exact-name pairing: OK (ui=%d, raster=%d)" % (len(ui), len(raster)))

    ui_e, raster_e, _, _ = parse_timeline_events([], {}, {})
    assert ui_e == [] and raster_e == []
    print("  VM timeline empty: OK")

    # Cross-batch retention
    pending_ui = {}
    pending_raster = {}
    batch1 = [
        {"name": "Frame", "ph": "b", "id": 2, "ts": 5000000},
        {"name": "GPURasterizer::Draw", "ph": "B", "tid": 7, "ts": 5001000},
    ]
    ui1, raster1, pending_ui, pending_raster = parse_timeline_events(batch1, pending_ui, pending_raster)
    assert ui1 == [] and raster1 == []
    assert 2 in pending_ui and 7 in pending_raster
    batch2 = [
        {"name": "Frame", "ph": "e", "id": 2, "ts": 5018000},
        {"name": "GPURasterizer::Draw", "ph": "E", "tid": 7, "ts": 5009000},
    ]
    ui2, raster2, pending_ui, pending_raster = parse_timeline_events(batch2, pending_ui, pending_raster)
    assert len(ui2) == 1 and abs(ui2[0] - 18.0) < 0.01
    assert len(raster2) == 1 and abs(raster2[0] - 8.0) < 0.01
    print("  VM timeline cross-batch retention: OK")

    st = _stats(ui)
    assert st["count"] == 2 and st["over_16_67ms"] == 1
    assert _stats([]) == "not measured"
    print("  VM stats + not-measured on empty: OK")

    assert urllib.parse.urlencode({"recordedStreams": "[Dart,Embedder]"}) == "recordedStreams=%5BDart%2CEmbedder%5D"
    print("  VM set_flags recordedStreams=[Dart,Embedder] (no quotes): OK")

    # mock main --seconds 0 integration
    url = "http://secret.invalid/token/abc123"
    tmp = tempfile.mkdtemp()
    old_argv = sys.argv
    old_adb = globals()["adb"]
    old_vm_get = globals().get("_vm_get")
    globals()["adb"] = lambda serial, cmd: ("", 0) if "pidof" in cmd else (
        "TOTAL PSS: 10 TOTAL RSS: 20\n" if "meminfo" in cmd else ("", 0)
    )
    globals()["_vm_get"] = lambda *a, **k: None
    buf = io.StringIO()
    try:
        sys.argv = ["measure_android_playback.py", "--seconds", "0", "--output-dir", tmp,
                    "--vm-service-url", url]
        with redirect_stdout(buf), redirect_stderr(buf):
            assert main() == 0
    finally:
        sys.argv = old_argv
        globals()["adb"] = old_adb
        if old_vm_get is not None:
            globals()["_vm_get"] = old_vm_get
    out = buf.getvalue()
    summary_path = Path(tmp, "summary.json")
    summary_raw = summary_path.read_text()
    assert url not in summary_raw and url not in out, "FAIL: vm url leaked"
    summary_obj = json.loads(summary_raw)
    assert "vm_service_url" not in summary_obj
    assert summary_obj["vm"]["ui"] == "not measured"
    assert summary_obj["vm"]["raster"] == "not measured"
    assert summary_obj["logcat"]["fatal"] == "not measured"
    assert summary_obj["logcat"]["anr"] == "not measured"
    assert summary_obj["network"] == "not measured"
    print("  mock main --seconds 0: OK (no url, no device metrics)")

    # VM success checks
    old_vm_get_self = globals().get("_vm_get")
    cases = [
        (json.dumps({"result": {"type": "Success"}}), True),
        (json.dumps({"error": {"code": -32000, "message": "boom"}}), False),
        (None, False),
        ("{not json", False),
        (json.dumps({}), False),
        (json.dumps({"result": None}), False),
        (json.dumps({"result": {"type": "Error"}}), False),
        (json.dumps({"result": "Success"}), False),
    ]
    try:
        for text, expected in cases:
            globals()["_vm_get"] = (lambda t: (lambda *a, **k: t))(text)
            assert vm_set_flags("http://x") is expected, (text, expected)
            assert vm_clear_timeline("http://x") is expected, (text, expected)
        print("  VM success checks: OK")
    finally:
        if old_vm_get_self is not None:
            globals()["_vm_get"] = old_vm_get_self
        else:
            globals().pop("_vm_get", None)

    # Foreground activity parsing (resumed/topResumed only; not stale/last)
    assert parse_foreground_activity(
        "  mResumedActivity: ActivityRecord{1f2e u0 %s/.FlutterMainActivity t42}\n" % PKG
    ) == PKG
    assert parse_foreground_activity(
        "    topResumedActivity=ActivityRecord{aa u0a210 com.other.app/.Main t9}\n"
    ) == "com.other.app"
    assert parse_foreground_activity(
        "    ResumedActivity: ActivityRecord{bb u0 %s/.MainActivity t3}\n" % PKG) == PKG
    assert parse_foreground_activity(
        "  mLastResumedActivity: ActivityRecord{9 u0 com.stale.app/.Old t1}\n") is None
    assert parse_foreground_activity("") is None
    assert parse_foreground_activity("nothing here\n") is None
    print("  foreground resumed/topResumed activity parsing: OK")

    # Guarded parse: negative/nonfinite/untyped/non-dict events must not corrupt
    bad_events = [
        {"name": "Frame", "ph": "X", "ts": 1, "dur": -5},
        {"name": "Frame", "ph": "X", "ts": 2},
        {"name": "Frame", "ph": "X", "ts": 3, "dur": "8000"},
        {"name": "Frame", "ph": "X", "ts": 4, "dur": float("nan")},
        {"name": "Frame", "ph": "X", "ts": 5, "dur": float("inf")},
        {"name": "Frame", "ph": "X", "ts": 6, "dur": True},
        {"name": "GPURasterizer::Draw", "ph": "X", "ts": 7, "dur": -1},
        {"name": "GPURasterizer::Draw", "ph": "B", "ts": 10, "tid": 3},
        {"name": "GPURasterizer::Draw", "ph": "E", "ts": 8, "tid": 3},
        {"name": "Frame", "ph": "b", "id": 5, "ts": 20},
        {"name": "Frame", "ph": "e", "id": 5, "ts": 15},
        "not-a-dict", None, 42,
    ]
    ui_b, raster_b, pui_b, praster_b = parse_timeline_events(bad_events, {}, {})
    assert ui_b == [] and raster_b == [] and pui_b == {} and praster_b == {}
    print("  VM timeline guarded parse (negative/nonfinite/untyped/non-dict): OK")

    # Dropped batch clears pending: a later end event cannot pair across it
    pui_d = {}
    praster_d = {}
    parse_timeline_events([{"name": "Frame", "ph": "b", "id": 7, "ts": 100}], pui_d, praster_d)
    assert 7 in pui_d
    pui_d.clear()
    praster_d.clear()
    ui_d, raster_d, _, _ = parse_timeline_events(
        [{"name": "Frame", "ph": "e", "id": 7, "ts": 900}], pui_d, praster_d
    )
    assert ui_d == [] and raster_d == []
    print("  pending cleared after dropped batch (later end cannot pair): OK")

    # VM timeline fetch: valid empty is valid; missing/malformed are not
    tl_cases = [
        (json.dumps({"result": {"traceEvents": []}}), {"traceEvents": []}),
        (json.dumps({"result": {"other": 1}}), {"other": 1}),
        (json.dumps({"result": {"traceEvents": {}}}), {"traceEvents": {}}),
        (json.dumps({"result": {"traceEvents": "x"}}), {"traceEvents": "x"}),
        (json.dumps({"result": "Success"}), None),
        (json.dumps([1, 2]), None),
        ("{not json", None),
        (None, None),
    ]
    old_vm_get_tl = globals().get("_vm_get")
    try:
        for text, expected in tl_cases:
            globals()["_vm_get"] = (lambda t: (lambda *a, **k: t))(text)
            got = vm_get_timeline("http://x")
            assert got == expected, (text, got)
        print("  VM timeline fetch valid-empty/missing/malformed: OK")
    finally:
        if old_vm_get_tl is not None:
            globals()["_vm_get"] = old_vm_get_tl
        else:
            globals().pop("_vm_get", None)

    # Mocked main runs: raw save, incomplete paths, foreground validation, no leak
    class _FakeClock:
        def __init__(self):
            self.t = 0.0

        def time(self):
            self.t += SAMPLE_INTERVAL + 1.0
            return self.t

        def sleep(self, _s):
            pass

    resumed_ok = ("  mResumedActivity: ActivityRecord{aa11 u0 %s/.FlutterMainActivity t5}\n"
                  "  mLastResumedActivity: ActivityRecord{bb22 u0 com.stale.app/.Old t6}\n" % PKG)
    resumed_foreign = "  mResumedActivity: ActivityRecord{cc33 u0 com.other.app/.Main t7}\n"

    def _adb_ok(serial, cmd):
        if "pidof" in cmd:
            return ("1234\n", 0)
        if "meminfo" in cmd:
            return ("TOTAL PSS: 111 TOTAL RSS: 222\n", 0)
        if "dumpsys activity activities" in cmd:
            return (resumed_ok, 0)
        return ("", 0)

    def _adb_foreign_second(counter):
        def _fn(serial, cmd):
            if "pidof" in cmd:
                return ("1234\n", 0)
            if "meminfo" in cmd:
                return ("TOTAL PSS: 111 TOTAL RSS: 222\n", 0)
            if "dumpsys activity activities" in cmd:
                counter["n"] += 1
                return (resumed_ok if counter["n"] == 1 else resumed_foreign, 0)
            return ("", 0)
        return _fn

    url = "http://vm.invalid/auth/token123"

    def _run_mocked_main(tmp, seconds, adb_fn, vm_bodies, extra_args=None):
        old_argv2 = sys.argv
        old_clock = globals()["time"]
        old_adb2 = globals()["adb"]
        old_vm2 = globals().get("_vm_get")
        bodies = iter(vm_bodies)

        def _vm(base, path, params=None):
            if path == "getVMTimeline":
                return next(bodies, None)
            return json.dumps({"result": {"type": "Success"}})

        buf = io.StringIO()
        rc = 0
        globals()["adb"] = adb_fn
        globals()["_vm_get"] = _vm
        globals()["time"] = _FakeClock()
        try:
            sys.argv = ["measure_android_playback.py", "--seconds", str(seconds),
                        "--output-dir", tmp, "--vm-service-url", url]
            sys.argv.extend(extra_args or [])
            with redirect_stdout(buf), redirect_stderr(buf):
                rc = main()
        finally:
            sys.argv = old_argv2
            globals()["adb"] = old_adb2
            globals()["time"] = old_clock
            if old_vm2 is not None:
                globals()["_vm_get"] = old_vm2
            else:
                globals().pop("_vm_get", None)
        return buf.getvalue(), rc

    def _assert_no_leak(tmp, out):
        for p in Path(tmp).iterdir():
            assert "vm.invalid" not in p.read_text() and "token123" not in p.read_text(), p
        assert "vm.invalid" not in out and "token123" not in out

    frame_pair = [{"name": "Frame", "ph": "b", "id": 1, "ts": 1000000},
                  {"name": "Frame", "ph": "e", "id": 1, "ts": 1020000},
                  {"name": "GPURasterizer::Draw", "ph": "X", "ts": 1005000, "dur": 4000}]
    b_pair = json.dumps({"result": {"traceEvents": frame_pair}})
    b_empty = json.dumps({"result": {"traceEvents": []}})

    # Case 1: success + valid empty second batch; raw bodies saved verbatim
    tmp_c1 = tempfile.mkdtemp()
    out_c1, rc_c1 = _run_mocked_main(tmp_c1, 30, _adb_ok, [b_pair, b_empty])
    assert rc_c1 == 0, rc_c1
    assert Path(tmp_c1, "timeline-1.json").read_text() == b_pair, "FAIL: raw timeline not saved"
    assert Path(tmp_c1, "timeline-2.json").read_text() == b_empty
    s1 = json.loads(Path(tmp_c1, "summary.json").read_text())
    assert s1["samples"] == 2, s1["samples"]
    assert s1["valid"] is True and s1["reasons"] == []
    assert s1["foreground_packages"] == [PKG, PKG]
    assert isinstance(s1["vm"]["ui"], dict) and s1["vm"]["ui"]["count"] == 1
    assert isinstance(s1["vm"]["raster"], dict) and s1["vm"]["raster"]["count"] == 1
    _assert_no_leak(tmp_c1, out_c1)
    print("  mock main VM success + valid empty raw save: OK")

    # Case 2: malformed first batch -> incomplete, raw saved, no further VM fetch
    tmp_c2 = tempfile.mkdtemp()
    out_c2, rc_c2 = _run_mocked_main(tmp_c2, 30, _adb_ok, ["{not json", b_pair])
    assert rc_c2 == 0, rc_c2
    assert Path(tmp_c2, "timeline-1.json").read_text() == "{not json"
    assert not Path(tmp_c2, "timeline-2.json").exists(), "FAIL: VM kept fetching after drop"
    s2 = json.loads(Path(tmp_c2, "summary.json").read_text())
    assert s2["vm"]["ui"] == "incomplete" and s2["vm"]["raster"] == "incomplete"
    assert s2["valid"] is False and len(s2["reasons"]) > 0
    _assert_no_leak(tmp_c2, out_c2)
    print("  mock main malformed timeline -> incomplete + raw saved: OK")

    # Case 3: missing traceEvents after a good batch -> incomplete overrides numbers
    b_missing = json.dumps({"result": {"noTraceEvents": True}})
    tmp_c3 = tempfile.mkdtemp()
    out_c3, rc_c3 = _run_mocked_main(tmp_c3, 30, _adb_ok, [b_pair, b_missing])
    assert rc_c3 == 0, rc_c3
    assert Path(tmp_c3, "timeline-2.json").read_text() == b_missing
    s3 = json.loads(Path(tmp_c3, "summary.json").read_text())
    assert s3["vm"]["ui"] == "incomplete" and s3["vm"]["raster"] == "incomplete"
    _assert_no_leak(tmp_c3, out_c3)
    print("  mock main missing traceEvents -> incomplete overrides numbers: OK")

    # Case 4: other app foreground -> invalid + pending cleared, end cannot pair
    b_open = json.dumps({"result": {"traceEvents": [
        {"name": "Frame", "ph": "b", "id": 9, "ts": 500000}]}})
    b_close = json.dumps({"result": {"traceEvents": [
        {"name": "Frame", "ph": "e", "id": 9, "ts": 590000}]}})
    counter = {"n": 0}
    tmp_c4 = tempfile.mkdtemp()
    out_c4, rc_c4 = _run_mocked_main(tmp_c4, 30, _adb_foreign_second(counter), [b_open, b_close])
    assert rc_c4 == 0, rc_c4
    s4 = json.loads(Path(tmp_c4, "summary.json").read_text())
    assert s4["samples"] == 2, s4["samples"]
    assert s4["valid"] is False
    assert any("com.other.app" in r for r in s4["reasons"]), s4["reasons"]
    assert s4["foreground_packages"] == [PKG, "com.other.app"]
    assert s4["vm"]["ui"] == "incomplete" and s4["vm"]["raster"] == "incomplete"
    assert Path(tmp_c4, "timeline-2.json").read_text() == b_close
    _assert_no_leak(tmp_c4, out_c4)
    print("  mock main other app foreground -> invalid + pending cleared: OK")

    # Case 5: raw timeline write failure -> invalid, reason recorded, no file
    tmp_c5 = tempfile.mkdtemp()
    old_save_raw = globals()["_save_raw_timeline"]
    globals()["_save_raw_timeline"] = lambda output_dir, sample, raw: False
    try:
        out_c5, rc_c5 = _run_mocked_main(tmp_c5, 30, _adb_ok, [b_pair])
    finally:
        globals()["_save_raw_timeline"] = old_save_raw
    assert rc_c5 == 0, rc_c5
    assert not Path(tmp_c5, "timeline-1.json").exists(), "FAIL: timeline file written on failure"
    s5 = json.loads(Path(tmp_c5, "summary.json").read_text())
    assert s5["samples"] == 2, s5["samples"]
    assert s5["valid"] is False
    assert s5["vm"]["ui"] == "incomplete" and s5["vm"]["raster"] == "incomplete"
    assert any("raw timeline save failed" in r for r in s5["reasons"]), s5["reasons"]
    _assert_no_leak(tmp_c5, out_c5)
    print("  mock main raw timeline save failure -> invalid + reason + no file: OK")

    # Gated playback/title validation via real mocked main runs
    def _session(state_word, state_num, title):
        return (
            "package=%s\n"
            "state=PlaybackState {state=%s(%d), position=1000, ...}\n"
            "metadata: size=1, description=%s, Artist\n"
            % (PKG, state_word, state_num, title)
        )

    def _adb_session(session_out):
        def _fn(serial, cmd):
            if "media_session" in cmd:
                return (session_out, 0)
            return _adb_ok(serial, cmd)
        return _fn

    def _adb_session_sequence(sessions):
        counter = {"n": 0}

        def _fn(serial, cmd):
            if "media_session" in cmd:
                index = min(counter["n"], len(sessions) - 1)
                counter["n"] += 1
                return (sessions[index], 0)
            return _adb_ok(serial, cmd)
        return _fn

    playing_title = _session("PLAYING", 3, "以父之名")
    paused_title = _session("PAUSED", 2, "以父之名")

    # Gated: matching PLAYING state + exact unicode title succeeds
    tmp_c6 = tempfile.mkdtemp()
    out_c6, rc_c6 = _run_mocked_main(
        tmp_c6, 30, _adb_session(playing_title), [b_pair, b_empty],
        ["--require-playing", "--expected-track-title", "以父之名"],
    )
    s6 = json.loads(Path(tmp_c6, "summary.json").read_text())
    assert s6["valid"] is True and s6["reasons"] == [], s6["reasons"]
    assert s6["samples"] == 2, s6["samples"]
    assert rc_c6 == 0, rc_c6
    print("  gated main matching PLAYING + exact title -> valid/exit 0: OK")

    # Gated: wrong unicode title with PLAYING invalid
    tmp_c7 = tempfile.mkdtemp()
    out_c7, rc_c7 = _run_mocked_main(
        tmp_c7, 30, _adb_session(playing_title), [b_pair, b_empty],
        ["--require-playing", "--expected-track-title", "另一个标题"],
    )
    s7 = json.loads(Path(tmp_c7, "summary.json").read_text())
    assert s7["valid"] is False
    assert any("expected-track-title" in r and "sample 1" in r for r in s7["reasons"]), s7["reasons"]
    assert rc_c7 == 1, rc_c7
    print("  gated main wrong title + PLAYING -> invalid/exit 1: OK")

    # Gated: correct title but PAUSED invalid
    tmp_c8 = tempfile.mkdtemp()
    out_c8, rc_c8 = _run_mocked_main(
        tmp_c8, 30, _adb_session(paused_title), [b_pair, b_empty],
        ["--require-playing", "--expected-track-title", "以父之名"],
    )
    s8 = json.loads(Path(tmp_c8, "summary.json").read_text())
    assert s8["valid"] is False
    assert any("require-playing" in r and "sample 1" in r and "state=2" in r
               for r in s8["reasons"]), s8["reasons"]
    assert rc_c8 == 1, rc_c8
    print("  gated main correct title + PAUSED -> invalid/exit 1: OK")

    # Gated: later sample failure invalidates whole summary
    tmp_c9 = tempfile.mkdtemp()
    out_c9, rc_c9 = _run_mocked_main(
        tmp_c9, 30, _adb_session_sequence([playing_title, paused_title]),
        [b_pair, b_empty],
        ["--require-playing", "--expected-track-title", "以父之名"],
    )
    s9 = json.loads(Path(tmp_c9, "summary.json").read_text())
    assert s9["samples"] == 2, s9["samples"]
    assert s9["valid"] is False
    assert any("require-playing" in r and "sample 2" in r and "state=2" in r
               for r in s9["reasons"]), s9["reasons"]
    assert rc_c9 == 1, rc_c9
    print("  gated main later-sample failure -> invalid/exit 1: OK")

    # Gated: missing state and title invalid
    tmp_c10 = tempfile.mkdtemp()
    out_c10, rc_c10 = _run_mocked_main(
        tmp_c10, 30, _adb_session("package=%s\n" % PKG), [b_pair, b_empty],
        ["--require-playing", "--expected-track-title", "以父之名"],
    )
    s10 = json.loads(Path(tmp_c10, "summary.json").read_text())
    assert s10["valid"] is False
    assert any("require-playing" in r and "sample 1" in r and "missing" in r
               for r in s10["reasons"]), s10["reasons"]
    assert any("expected-track-title" in r and "sample 1" in r
               for r in s10["reasons"]), s10["reasons"]
    assert rc_c10 == 1, rc_c10
    print("  gated main missing state/title -> invalid/exit 1: OK")

    # Gated: no samples invalid
    tmp_c11 = tempfile.mkdtemp()
    out_c11, rc_c11 = _run_mocked_main(
        tmp_c11, 0, _adb_session(playing_title), [],
        ["--require-playing"],
    )
    s11 = json.loads(Path(tmp_c11, "summary.json").read_text())
    assert s11["samples"] == 0, s11["samples"]
    assert s11["valid"] is False
    assert any("no samples" in r for r in s11["reasons"]), s11["reasons"]
    assert rc_c11 == 1, rc_c11
    print("  gated main no samples -> invalid/exit 1: OK")

    # Ungated: paused state keeps legacy valid behavior and exit 0
    tmp_c12 = tempfile.mkdtemp()
    out_c12, rc_c12 = _run_mocked_main(
        tmp_c12, 30, _adb_session(paused_title), [b_pair, b_empty],
    )
    s12 = json.loads(Path(tmp_c12, "summary.json").read_text())
    assert s12["valid"] is True and s12["reasons"] == [], s12["reasons"]
    assert s12["samples"] == 2, s12["samples"]
    assert rc_c12 == 0, rc_c12
    print("  ungated paused state -> legacy valid/exit 0: OK")

    # Gated: expected title only, matching title with PAUSED state succeeds
    tmp_c13 = tempfile.mkdtemp()
    out_c13, rc_c13 = _run_mocked_main(
        tmp_c13, 30, _adb_session(paused_title), [b_pair, b_empty],
        ["--expected-track-title", "以父之名"],
    )
    s13 = json.loads(Path(tmp_c13, "summary.json").read_text())
    assert s13["valid"] is True and s13["reasons"] == [], s13["reasons"]
    assert s13["samples"] == 2, s13["samples"]
    assert rc_c13 == 0, rc_c13
    _assert_no_leak(tmp_c13, out_c13)
    print("  gated main expected-title-only + PAUSED matching -> valid/exit 0: OK")

    # Gated: require-playing only, PLAYING with any title succeeds
    wrong_title_playing = _session("PLAYING", 3, "Wrong Title")
    tmp_c14 = tempfile.mkdtemp()
    out_c14, rc_c14 = _run_mocked_main(
        tmp_c14, 30, _adb_session(wrong_title_playing), [b_pair, b_empty],
        ["--require-playing"],
    )
    s14 = json.loads(Path(tmp_c14, "summary.json").read_text())
    assert s14["valid"] is True and s14["reasons"] == [], s14["reasons"]
    assert s14["samples"] == 2, s14["samples"]
    assert rc_c14 == 0, rc_c14
    _assert_no_leak(tmp_c14, out_c14)
    print("  gated main require-playing-only + PLAYING wrong title -> valid/exit 0: OK")

    # Gated: expected title only, second sample wrong title invalidates at sample 2
    tmp_c15 = tempfile.mkdtemp()
    out_c15, rc_c15 = _run_mocked_main(
        tmp_c15, 30,
        _adb_session_sequence([playing_title, wrong_title_playing]),
        [b_pair, b_empty],
        ["--expected-track-title", "以父之名"],
    )
    s15 = json.loads(Path(tmp_c15, "summary.json").read_text())
    assert s15["samples"] == 2, s15["samples"]
    assert s15["valid"] is False
    assert any("expected-track-title" in r and "sample 2" in r
               for r in s15["reasons"]), s15["reasons"]
    assert rc_c15 == 1, rc_c15
    _assert_no_leak(tmp_c15, out_c15)
    print("  gated main expected-title-only second wrong title -> invalid/exit 1: OK")

    # Gated: expected title only with no samples invalid
    tmp_c16 = tempfile.mkdtemp()
    out_c16, rc_c16 = _run_mocked_main(
        tmp_c16, 0, _adb_session(playing_title), [],
        ["--expected-track-title", "以父之名"],
    )
    s16 = json.loads(Path(tmp_c16, "summary.json").read_text())
    assert s16["samples"] == 0, s16["samples"]
    assert s16["valid"] is False
    assert any("no samples" in r for r in s16["reasons"]), s16["reasons"]
    assert rc_c16 == 1, rc_c16
    _assert_no_leak(tmp_c16, out_c16)
    print("  gated main expected-title-only no samples -> invalid/exit 1: OK")

    print("\n=== Self-test PASSED ===")


def main():
    ap = argparse.ArgumentParser(description="OmniTune Android playback measurement")
    ap.add_argument("--serial", default="", help="Device serial (adb -s)")
    ap.add_argument("--seconds", type=int, default=DEFAULT_SECONDS)
    ap.add_argument("--output-dir", default=DEFAULT_OUTPUT_DIR)
    ap.add_argument("--vm-service-url", default=None)
    ap.add_argument("--require-playing", action="store_true",
                    help="Require every sample to report PlaybackState PLAYING(3)")
    ap.add_argument("--expected-track-title", default=None,
                    help="Require every sample's track title to match exactly")
    ap.add_argument("--self-test", action="store_true")
    args = ap.parse_args()

    if args.self_test:
        self_test()
        return 0

    os.makedirs(args.output_dir, exist_ok=True)
    csv_path = os.path.join(args.output_dir, "measurement.csv")
    summary_path = os.path.join(args.output_dir, "summary.json")

    vm_url = args.vm_service_url
    vm_available = False
    vm_incomplete = False
    if vm_url:
        vm_available = vm_set_flags(vm_url)
        if vm_available:
            if not vm_clear_timeline(vm_url):
                vm_available = False
                vm_incomplete = True
        if not vm_available:
            print("WARNING: VMTimelineFlags not set – VM stats unavailable", file=sys.stderr)

    pid = adb_pid(args.serial)

    fatal_baseline, baseline_ok = (None, False)
    if pid:
        fatal_baseline, baseline_ok = count_fatal(args.serial, pid)

    start_ts = time.time()
    end_ts = start_ts + max(0, args.seconds)

    ui_all = []
    raster_all = []
    ui_pending = {}
    raster_pending = {}

    with open(csv_path, "w", newline="") as f:
        writer = csv.writer(f)
        writer.writerow([
            "timestamp", "elapsed_seconds", "pss_kb", "rss_kb",
            "playback_state", "position_ms", "track_title", "track_artist",
        ])

    summary = {
        "samples": 0,
        "pss_values": [],
        "rss_values": [],
        "state_counts": {},
        "position_values": [],
        "track_titles": [],
        "track_artists": [],
        "logcat": {"fatal": "not measured", "anr": "not measured"},
        "network": "not measured",
        "valid": True,
        "reasons": [],
        "foreground_packages": [],
        "vm": {"ui": "not measured", "raster": "not measured"},
    }

    vm_sample = 0

    try:
        while time.time() < end_ts:
            elapsed = int(time.time() - start_ts)

            mem_out, _ = adb(args.serial, "shell dumpsys meminfo %s" % PKG)
            pss, rss = parse_meminfo(mem_out)

            sess_out, _ = adb(args.serial, "shell dumpsys media_session")
            state, position_ms, track = parse_media_session(sess_out)

            act_out, _ = adb(args.serial, "shell dumpsys activity activities")
            fg_pkg = parse_foreground_activity(act_out)
            summary["foreground_packages"].append(fg_pkg if fg_pkg else "unknown")
            if not fg_pkg or fg_pkg != PKG:
                summary["valid"] = False
                summary["reasons"].append(
                    "foreground foreign app: %s at sample %d"
                    % (fg_pkg if fg_pkg else "unknown", summary["samples"] + 1)
                )
                vm_incomplete = True
                ui_pending.clear()
                raster_pending.clear()

            with open(csv_path, "a", newline="") as f:
                writer = csv.writer(f)
                writer.writerow([
                    datetime.now().isoformat(), elapsed,
                    pss if pss is not None else "",
                    rss if rss is not None else "",
                    state if state is not None else 0,
                    position_ms if position_ms is not None else 0,
                    track.get("title", ""), track.get("artist", ""),
                ])

            summary["samples"] += 1
            if pss is not None:
                summary["pss_values"].append(pss)
            if rss is not None:
                summary["rss_values"].append(rss)
            if state is not None:
                key = str(state)
                summary["state_counts"][key] = summary["state_counts"].get(key, 0) + 1
            if position_ms is not None:
                summary["position_values"].append(position_ms)
            if track.get("title"):
                summary["track_titles"].append(track["title"])
            if track.get("artist"):
                summary["track_artists"].append(track["artist"])

            sample_index = summary["samples"]
            if args.require_playing and state != 3:
                summary["valid"] = False
                summary["reasons"].append(
                    "require-playing: sample %d state=%s"
                    % (sample_index, state if state is not None else "missing")
                )
            if args.expected_track_title is not None:
                actual_title = track.get("title", "")
                if not actual_title or actual_title != args.expected_track_title:
                    summary["valid"] = False
                    summary["reasons"].append(
                        "expected-track-title: sample %d expected %r got %r"
                        % (sample_index, args.expected_track_title,
                           actual_title if actual_title else None)
                    )

            if vm_url and vm_available:
                vm_sample += 1
                raw = vm_get_timeline_raw(vm_url)
                if raw is not None:
                    saved = _save_raw_timeline(args.output_dir, vm_sample, raw)
                    if not saved:
                        vm_incomplete = True
                        vm_available = False
                        ui_pending.clear()
                        raster_pending.clear()
                        summary["valid"] = False
                        summary["reasons"].append(
                            "raw timeline save failed at sample %d" % vm_sample
                        )
                timeline = _timeline_from_raw(raw)
                trace_events = timeline.get("traceEvents") if timeline else None
                if not isinstance(trace_events, list):
                    vm_incomplete = True
                    vm_available = False
                    ui_pending.clear()
                    raster_pending.clear()
                else:
                    ui_batch, raster_batch, ui_pending, raster_pending = parse_timeline_events(
                        trace_events, ui_pending, raster_pending
                    )
                    ui_all.extend(ui_batch)
                    raster_all.extend(raster_batch)
                if not vm_clear_timeline(vm_url):
                    vm_incomplete = True
                    vm_available = False
                    ui_pending.clear()
                    raster_pending.clear()

            time.sleep(SAMPLE_INTERVAL)

    except KeyboardInterrupt:
        vm_incomplete = True
        ui_pending.clear()
        raster_pending.clear()
        print("\nCtrl+C: preserving acquired samples...")
    except Exception:
        vm_incomplete = True
        ui_pending.clear()
        raster_pending.clear()
        print("\nError: measurement interrupted – preserving acquired samples...", file=sys.stderr)

    # logcat fatal since sampling start (best-effort; ANR not reliable)
    fatal_after, after_ok = (None, False)
    if pid:
        fatal_after, after_ok = count_fatal(args.serial, pid)
    if pid and baseline_ok and after_ok and fatal_baseline is not None and fatal_after is not None:
        if fatal_after >= fatal_baseline:
            fatal_count = fatal_after - fatal_baseline
        else:
            fatal_count = "not measured"
    else:
        fatal_count = "not measured"
    summary["logcat"] = {"fatal": fatal_count, "anr": "not measured"}

    if vm_url and vm_incomplete:
        summary["vm"]["ui"] = "incomplete"
        summary["vm"]["raster"] = "incomplete"
        summary["valid"] = False
        summary["reasons"].append("vm timeline incomplete")
    elif vm_url and vm_available:
        summary["vm"]["ui"] = _stats(ui_all)
        summary["vm"]["raster"] = _stats(raster_all)

    gates_enabled = args.require_playing or args.expected_track_title is not None
    if gates_enabled and summary["samples"] == 0:
        summary["valid"] = False
        summary["reasons"].append("no samples collected")

    with open(summary_path, "w") as f:
        json.dump(summary, f, indent=2, ensure_ascii=False)

    print("\nMeasurement complete.")
    print("  Samples: %d" % summary["samples"])
    print("  Valid: %s%s" % (
        summary["valid"],
        ("" if summary["valid"] else " (%s)" % "; ".join(summary["reasons"][:3])),
    ))
    print("  CSV: %s" % csv_path)
    print("  Summary: %s" % summary_path)

    if gates_enabled and not summary["valid"]:
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main() or 0)
