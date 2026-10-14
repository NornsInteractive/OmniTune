#!/usr/bin/env python3
'''OmniTune Android playback measurement script.'''

import argparse
import csv
import io
import json
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


def vm_get_timeline(base_url: str) -> dict | None:
    raw = _vm_get(base_url, "getVMTimeline")
    if raw is None:
        return None
    try:
        return json.loads(raw).get("result")
    except (json.JSONDecodeError, AttributeError):
        return None


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


def parse_timeline_events(trace_events, pending_ui=None, pending_raster=None):
    if pending_ui is None:
        pending_ui = {}
    if pending_raster is None:
        pending_raster = {}
    ui_ms = []
    raster_ms = []

    for ev in trace_events or []:
        name = ev.get("name", "")
        phase = ev.get("ph", "")
        ts = ev.get("ts", 0)

        if name == "Frame":
            if phase == "X":
                dur = ev.get("dur", 0)
                if dur:
                    ui_ms.append(dur / 1000.0)
            else:
                eid = ev.get("id")
                if eid is None:
                    continue
                if phase == "b":
                    pending_ui[eid] = ts
                elif phase == "e" and eid in pending_ui:
                    ui_ms.append((ts - pending_ui.pop(eid)) / 1000.0)
        elif name == "GPURasterizer::Draw":
            if phase == "X":
                dur = ev.get("dur", 0)
                if dur:
                    raster_ms.append(dur / 1000.0)
            else:
                tid = ev.get("tid")
                if tid is None:
                    continue
                if phase == "B":
                    pending_raster[tid] = ts
                elif phase == "E" and tid in pending_raster:
                    raster_ms.append((ts - pending_raster.pop(tid)) / 1000.0)

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
            main()
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

    print("\n=== Self-test PASSED ===")


def main():
    ap = argparse.ArgumentParser(description="OmniTune Android playback measurement")
    ap.add_argument("--serial", default="", help="Device serial (adb -s)")
    ap.add_argument("--seconds", type=int, default=DEFAULT_SECONDS)
    ap.add_argument("--output-dir", default=DEFAULT_OUTPUT_DIR)
    ap.add_argument("--vm-service-url", default=None)
    ap.add_argument("--self-test", action="store_true")
    args = ap.parse_args()

    if args.self_test:
        self_test()
        return

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
        "vm": {"ui": "not measured", "raster": "not measured"},
    }

    try:
        while time.time() < end_ts:
            elapsed = int(time.time() - start_ts)

            mem_out, _ = adb(args.serial, "shell dumpsys meminfo %s" % PKG)
            pss, rss = parse_meminfo(mem_out)

            sess_out, _ = adb(args.serial, "shell dumpsys media_session")
            state, position_ms, track = parse_media_session(sess_out)

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

            if vm_url and vm_available:
                timeline = vm_get_timeline(vm_url)
                if timeline and timeline.get("traceEvents"):
                    ui_batch, raster_batch, ui_pending, raster_pending = parse_timeline_events(
                        timeline["traceEvents"], ui_pending, raster_pending
                    )
                    ui_all.extend(ui_batch)
                    raster_all.extend(raster_batch)
                if not vm_clear_timeline(vm_url):
                    vm_incomplete = True
                    vm_available = False

            time.sleep(SAMPLE_INTERVAL)

    except KeyboardInterrupt:
        print("\nCtrl+C: preserving acquired samples...")
    except Exception:
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

    if vm_url and vm_available:
        summary["vm"]["ui"] = _stats(ui_all)
        summary["vm"]["raster"] = _stats(raster_all)
    elif vm_url and vm_incomplete:
        summary["vm"]["ui"] = "incomplete"
        summary["vm"]["raster"] = "incomplete"

    with open(summary_path, "w") as f:
        json.dump(summary, f, indent=2, ensure_ascii=False)

    print("\nMeasurement complete.")
    print("  Samples: %d" % summary["samples"])
    print("  CSV: %s" % csv_path)
    print("  Summary: %s" % summary_path)


if __name__ == "__main__":
    main()
