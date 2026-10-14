#!/usr/bin/env python3
"""
OmniTune Android playback fixture & evidence tool.

Generates 90s PCM WAV, serves via WebDAV (PROPFIND/GET/HEAD/Range),
performs ADB evidence capture (logcat/gfxinfo/surfaceflinger), and self-tests.
"""
import argparse
import http.server
import math
import re
import shlex
import socket
import struct
import subprocess
import sys
import threading
import time
import urllib.request
import urllib.error
from pathlib import Path
from typing import Optional, Tuple

FIXTURE_DIR = Path("build/validation/android-fixture")
WAV_PATH = FIXTURE_DIR / "OmniTune-Performance.wav"
WAV_DURATION = 90
WAV_RATE = 44100
WAV_CHANNELS = 2
WAV_SAMPWIDTH = 2
WAV_FREQ = 441
SERVER_HOST = "127.0.0.1"
SERVER_PORT = 18765
DEFAULT_SERIAL = "127.0.0.1:14251"
PKG = "com.norns.omnitune"
DAV_NAME = "OmniTune performance fixture"


def ensure_fixture_dir() -> None:
    FIXTURE_DIR.mkdir(parents=True, exist_ok=True)
    root_wav = Path("OmniTune-Performance.wav")
    if root_wav.exists() and not WAV_PATH.exists():
        root_wav.rename(WAV_PATH)


def generate_wav(path: Path) -> None:
    """Generate 90s stereo 44.1kHz 16-bit PCM WAV (~16MB)."""
    if path.exists() and path.stat().st_size > 15_000_000:
        return
    frames = WAV_RATE * WAV_DURATION
    period = WAV_RATE // WAV_FREQ
    assert frames % period == 0
    vol = 0.25
    mono_period = [int(vol * 32767 * math.sin(2 * math.pi * i / period)) for i in range(period)]
    stereo_period = b"".join(struct.pack("<hh", s, s) for s in mono_period)
    stereo_data = stereo_period * (frames // period)
    import wave
    with wave.open(str(path), "wb") as wf:
        wf.setnchannels(WAV_CHANNELS)
        wf.setsampwidth(WAV_SAMPWIDTH)
        wf.setframerate(WAV_RATE)
        wf.writeframes(stereo_data)


class DAVHandler(http.server.BaseHTTPRequestHandler):
    server_version = "OmniTune-DAV/1.0"

    @property
    def wav_size(self) -> int:
        return getattr(self.server, "wav_size", 0)

    def log_message(self, fmt, *args):
        pass

    def do_OPTIONS(self):
        self.send_response(200)
        self.send_header("Allow", "GET, HEAD, PROPFIND, OPTIONS")
        self.send_header("DAV", "1")
        self.end_headers()

    def do_HEAD(self):
        self._handle_get_head(include_body=False)

    def do_GET(self):
        self._handle_get_head(include_body=True)

    def _handle_get_head(self, include_body: bool):
        path = self.path
        if path == "/" or path == "":
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.end_headers()
            if include_body:
                html = f"<html><body><h1>{DAV_NAME}</h1><a href='/OmniTune-Performance.wav'>OmniTune-Performance.wav</a></body></html>"
                self.wfile.write(html.encode())
            return

        if path == "/OmniTune-Performance.wav":
            self._serve_wav(include_body)
            return

        self.send_error(404)

    def _serve_wav(self, include_body: bool):
        start = 0
        end = self.wav_size - 1
        range_header = self.headers.get("Range")
        status = 200
        if range_header:
            m = re.match(r"bytes=(\d*)-(\d*)", range_header)
            if m:
                s, e = m.groups()
                if s and not e:
                    start = int(s)
                    end = self.wav_size - 1
                elif not s and e:
                    end = self.wav_size - 1
                    start = max(0, end - int(e) + 1)
                elif s and e:
                    start = int(s)
                    end = int(e)
                else:
                    start = 0
                    end = self.wav_size - 1
                if start <= end < self.wav_size:
                    status = 206
                else:
                    self.send_error(416, "Range Not Satisfiable")
                    self.send_header("Content-Range", f"bytes */{self.wav_size}")
                    self.end_headers()
                    return

        length = end - start + 1
        self.send_response(status)
        self.send_header("Content-Type", "audio/wav")
        self.send_header("Content-Length", str(length))
        self.send_header("Accept-Ranges", "bytes")
        if status == 206:
            self.send_header("Content-Range", f"bytes {start}-{end}/{self.wav_size}")
        self.end_headers()
        if include_body:
            try:
                with open(WAV_PATH, "rb") as f:
                    f.seek(start)
                    remaining = length
                    while remaining > 0:
                        chunk = f.read(min(65536, remaining))
                        if not chunk:
                            break
                        self.wfile.write(chunk)
                        remaining -= len(chunk)
            except (BrokenPipeError, ConnectionResetError):
                pass

    def do_PROPFIND(self):
        path = self.path
        depth = self.headers.get("Depth", "infinity").lower()
        depth_val = 0 if depth == "0" else 1 if depth == "1" else 2

        responses = []

        def add_entry(href: str, is_collection: bool, size: int = 0, name: str = ""):
            prop = []
            if is_collection:
                prop.append('<D:resourcetype><D:collection/></D:resourcetype>')
            else:
                prop.append('<D:resourcetype/>')
            prop.append(f'<D:displayname>{name or href.strip("/")}</D:displayname>')
            if not is_collection:
                prop.append(f'<D:getcontentlength>{size}</D:getcontentlength>')
                prop.append('<D:getcontenttype>audio/wav</D:getcontenttype>')
                prop.append(f'<D:getlastmodified>{time.strftime("%a, %d %b %Y %H:%M:%S GMT", time.gmtime())}</D:getlastmodified>')
            responses.append(f"""<D:response>
 <D:href>{href}</D:href>
 <D:propstat>
  <D:prop>{"".join(prop)}</D:prop>
  <D:status>HTTP/1.1 200 OK</D:status>
 </D:propstat>
</D:response>""")

        if path == "/" or path == "":
            add_entry("/", True, name=DAV_NAME)
            if depth_val != 0:
                add_entry("/OmniTune-Performance.wav", False, self.wav_size, "OmniTune-Performance.wav")
        elif path == "/OmniTune-Performance.wav":
            add_entry("/OmniTune-Performance.wav", False, self.wav_size, "OmniTune-Performance.wav")
        else:
            self.send_error(404)
            return

        body = f"""<?xml version="1.0" encoding="utf-8"?>
<D:multistatus xmlns:D="DAV:">
{"".join(responses)}
</D:multistatus>""".encode()

        self.send_response(207)
        self.send_header("Content-Type", "application/xml; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)


class ThreadingHTTPServer(http.server.ThreadingHTTPServer):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.wav_size = WAV_PATH.stat().st_size if WAV_PATH.exists() else 0


def run_server(port: int, ready_event: threading.Event) -> ThreadingHTTPServer:
    server = ThreadingHTTPServer((SERVER_HOST, port), DAVHandler)
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    for _ in range(50):
        try:
            urllib.request.urlopen(f"http://{SERVER_HOST}:{port}/", timeout=0.5)
            ready_event.set()
            break
        except Exception:
            time.sleep(0.1)
    return server


def adb_reverse(serial: str, port: int) -> bool:
    try:
        subprocess.run(["adb", "-s", serial, "reverse", f"tcp:{port}", f"tcp:{port}"],
                       check=True, capture_output=True)
        return True
    except subprocess.CalledProcessError:
        return False


def get_pid(serial: str) -> Optional[int]:
    try:
        out = subprocess.run(["adb", "-s", serial, "shell", "pidof", PKG],
                             capture_output=True, text=True, check=True).stdout.strip()
        return int(out.split()[0]) if out else None
    except Exception:
        return None


def capture_logcat(serial: str, pid: int, out_dir: Path, duration: int) -> Path:
    log_path = out_dir / f"logcat_pid{pid}.txt"
    proc = subprocess.Popen(["adb", "-s", serial, "logcat", f"--pid={pid}"],
                            stdout=log_path.open("w"), stderr=subprocess.STDOUT)
    time.sleep(duration)
    proc.terminate()
    try:
        proc.wait(timeout=2)
    except subprocess.TimeoutExpired:
        proc.kill()
    return log_path


def capture_gfxinfo(serial: str, out_dir: Path) -> Tuple[Path, Path]:
    summary_path = out_dir / "gfxinfo_summary.txt"
    frames_path = out_dir / "gfxinfo_framestats.csv"
    subprocess.run(["adb", "-s", serial, "shell", "dumpsys", "gfxinfo", PKG],
                   stdout=summary_path.open("w"), stderr=subprocess.STDOUT)
    subprocess.run(["adb", "-s", serial, "shell", "dumpsys", "gfxinfo", PKG, "framestats"],
                   stdout=frames_path.open("w"), stderr=subprocess.STDOUT)
    return summary_path, frames_path


def parse_gfxinfo_summary(path: Path) -> dict:
    data = {}
    text = path.read_text()
    for line in text.splitlines():
        line = line.strip()
        if line.startswith("Total frames rendered:"):
            data["total_frames"] = int(re.search(r"(\d+)", line).group(1))
        elif line.startswith("Janky frames:"):
            m = re.search(r"\((\d+(?:\.\d+)?)%\)", line)
            if m:
                data["janky_percent"] = float(m.group(1))
    return data


def capture_surfaceflinger_latency(serial: str, out_dir: Path) -> Optional[Tuple[Path, str]]:
    """Capture SurfaceFlinger raw latency for package's BLAST surface.
    Returns (path, surface_name) or None."""
    try:
        list_out = subprocess.run(["adb", "-s", serial, "shell", "dumpsys", "SurfaceFlinger", "--list"],
                                  capture_output=True, text=True, timeout=10)
        if list_out.returncode != 0:
            return None
        surface_name = None
        for line in list_out.stdout.splitlines():
            if PKG in line and "SurfaceView" in line and "(BLAST)" in line:
                surface_name = line.strip()
                break
        if not surface_name:
            return None
        quoted = shlex.quote(surface_name)
        cmd = f"dumpsys SurfaceFlinger --latency {quoted}"
        out = subprocess.run(["adb", "-s", serial, "shell", cmd],
                             capture_output=True, text=True, timeout=10)
        if out.returncode != 0 or not out.stdout.strip():
            return None
        latency_path = out_dir / "surfaceflinger_latency.txt"
        header = f"# Surface: {surface_name}\n"
        latency_path.write_text(header + out.stdout)
        return latency_path, surface_name
    except Exception:
        return None


def self_test(port: int) -> bool:
    base = f"http://{SERVER_HOST}:{port}"
    ok = True

    def check(name: str, cond: bool):
        nonlocal ok
        if not cond:
            print(f"FAIL: {name}")
            ok = False
        else:
            print(f"OK: {name}")
        return cond

    # PROPFIND root
    req = urllib.request.Request(base + "/", method="PROPFIND", data=b"")
    try:
        with urllib.request.urlopen(req, timeout=5) as resp:
            body = resp.read().decode()
            check("PROPFIND / 207", resp.status == 207)
            check("PROPFIND has collection", '<D:resourcetype><D:collection/></D:resourcetype>' in body)
            check("PROPFIND has wav", "OmniTune-Performance.wav" in body)
            check("PROPFIND displayname", DAV_NAME in body)
    except Exception as e:
        check("PROPFIND /", False)
        print(f"  error: {e}")

    # PROPFIND Depth:0
    req = urllib.request.Request(base + "/", method="PROPFIND", data=b"")
    req.add_header("Depth", "0")
    try:
        with urllib.request.urlopen(req, timeout=5) as resp:
            body = resp.read().decode()
            check("PROPFIND Depth:0 single", body.count("<D:response>") == 1)
    except Exception as e:
        check("PROPFIND Depth:0", False)
        print(f"  error: {e}")

    # GET file
    try:
        with urllib.request.urlopen(base + "/OmniTune-Performance.wav", timeout=5) as resp:
            data = resp.read(12)
            check("GET 200", resp.status == 200)
            check("GET RIFF header", data[:4] == b"RIFF")
            check("GET Content-Length", int(resp.headers.get("Content-Length", "0")) > 15_000_000)
            check("GET Accept-Ranges", resp.headers.get("Accept-Ranges") == "bytes")
    except Exception as e:
        check("GET file", False)
        print(f"  error: {e}")

    # HEAD file
    try:
        req = urllib.request.Request(base + "/OmniTune-Performance.wav", method="HEAD")
        with urllib.request.urlopen(req, timeout=5) as resp:
            check("HEAD 200", resp.status == 200)
            check("HEAD Content-Length", int(resp.headers.get("Content-Length", "0")) > 15_000_000)
    except Exception as e:
        check("HEAD file", False)
        print(f"  error: {e}")

    # Range 0-99
    try:
        req = urllib.request.Request(base + "/OmniTune-Performance.wav")
        req.add_header("Range", "bytes=0-99")
        with urllib.request.urlopen(req, timeout=5) as resp:
            data = resp.read()
            check("Range 0-99 206", resp.status == 206)
            check("Range 0-99 length", len(data) == 100)
            cr = resp.headers.get("Content-Range", "")
            check("Range 0-99 Content-Range", cr == "bytes 0-99/" + str(WAV_PATH.stat().st_size))
    except Exception as e:
        check("Range 0-99", False)
        print(f"  error: {e}")

    # Range suffix -100
    try:
        size = WAV_PATH.stat().st_size
        req = urllib.request.Request(base + "/OmniTune-Performance.wav")
        req.add_header("Range", "bytes=-100")
        with urllib.request.urlopen(req, timeout=5) as resp:
            data = resp.read()
            check("Range -100 206", resp.status == 206)
            check("Range -100 length", len(data) == 100)
            cr = resp.headers.get("Content-Range", "")
            check("Range -100 Content-Range", cr == f"bytes {size-100}-{size-1}/{size}")
    except Exception as e:
        check("Range -100", False)
        print(f"  error: {e}")

    # Unsatisfiable range
    try:
        req = urllib.request.Request(base + "/OmniTune-Performance.wav")
        req.add_header("Range", "bytes=999999999999-")
        with urllib.request.urlopen(req, timeout=5) as resp:
            check("Unsatisfiable 416", False)
    except urllib.error.HTTPError as e:
        check("Unsatisfiable 416", e.code == 416)
    except Exception as e:
        check("Unsatisfiable 416", False)
        print(f"  error: {e}")

    # PROPFIND on file
    try:
        req = urllib.request.Request(base + "/OmniTune-Performance.wav", method="PROPFIND", data=b"")
        with urllib.request.urlopen(req, timeout=5) as resp:
            body = resp.read().decode()
            check("PROPFIND file 207", resp.status == 207)
            check("PROPFIND file has wav", "OmniTune-Performance.wav" in body)
    except Exception as e:
        check("PROPFIND file", False)
        print(f"  error: {e}")

    # Synthetic assert: round-trip parse decimal janky
    synthetic = "Janky frames: (12.34%)"
    m = re.search(r"\((\d+(?:\.\d+)?)%\)", synthetic)
    check("Synthetic decimal janky parse", m and float(m.group(1)) == 12.34)

    return ok


def capture_only(args) -> int:
    """Sample evidence without generating WAV or starting server."""
    if not args.output_dir:
        print("--output-dir required with --capture-only", file=sys.stderr)
        return 1
    args.output_dir.mkdir(parents=True, exist_ok=True)

    pid = get_pid(args.serial)
    if pid is None:
        print(f"Package {PKG} not running", file=sys.stderr)
        return 1

    print(f"Capturing evidence for {args.sample_seconds}s (pid={pid})...")
    logcat_path = capture_logcat(args.serial, pid, args.output_dir, args.sample_seconds)
    summary_path, frames_path = capture_gfxinfo(args.serial, args.output_dir)
    sf_result = capture_surfaceflinger_latency(args.serial, args.output_dir)
    parsed = parse_gfxinfo_summary(summary_path)

    import json
    meta = {
        "package": PKG,
        "pid": pid,
        "sample_seconds": args.sample_seconds,
        "logcat": str(logcat_path),
        "gfxinfo_summary": str(summary_path),
        "gfxinfo_framestats": str(frames_path),
        "parsed": parsed,
        "note": "Values from dumpsys gfxinfo/surfaceflinger; not a Flutter FPS measurement"
    }
    if sf_result:
        sf_path, surface_name = sf_result
        meta["surfaceflinger_latency"] = str(sf_path)
        meta["surfaceflinger_surface"] = surface_name
    meta_path = args.output_dir / "evidence_summary.json"
    meta_path.write_text(json.dumps(meta, indent=2))
    print(f"Evidence written to {args.output_dir}")
    for k, v in parsed.items():
        print(f"  {k}: {v}")
    return 0


def main():
    ap = argparse.ArgumentParser(description="OmniTune Android playback fixture & evidence tool")
    ap.add_argument("--serve-only", action="store_true", help="Run WebDAV server only (no ADB operations)")
    ap.add_argument("--self-test", action="store_true", help="Run protocol self-test on ephemeral port")
    ap.add_argument("--capture-only", action="store_true", help="Capture evidence only (no WAV gen, no server)")
    ap.add_argument("--port", type=int, default=SERVER_PORT, help=f"Server port (default {SERVER_PORT})")
    ap.add_argument("--serial", default=DEFAULT_SERIAL, help=f"ADB serial (default {DEFAULT_SERIAL})")
    ap.add_argument("--apk", type=Path, help="APK path to install with -r (no uninstall)")
    ap.add_argument("--sample-seconds", type=int, help="Capture logcat/gfxinfo/surfaceflinger for N seconds")
    ap.add_argument("--output-dir", type=Path, help="Directory for evidence output")
    ap.add_argument("--no-reverse", action="store_true", help="Skip adb reverse")
    args = ap.parse_args()

    if args.self_test:
        ensure_fixture_dir()
        generate_wav(WAV_PATH)
        with socket.socket() as s:
            s.bind((SERVER_HOST, 0))
            test_port = s.getsockname()[1]
        ready = threading.Event()
        server = run_server(test_port, ready)
        if not ready.wait(5):
            print("Self-test server failed to start", file=sys.stderr)
            sys.exit(1)
        success = self_test(test_port)
        server.shutdown()
        sys.exit(0 if success else 1)

    if args.capture_only:
        sys.exit(capture_only(args))

    if args.serve_only:
        ensure_fixture_dir()
        generate_wav(WAV_PATH)
        ready = threading.Event()
        server = run_server(args.port, ready)
        if not ready.wait(5):
            print("Server failed to start", file=sys.stderr)
            sys.exit(1)
        print(f"Server ready on http://{SERVER_HOST}:{args.port}/")
        print(f"WAV: {WAV_PATH} ({WAV_PATH.stat().st_size} bytes)")
        if not args.no_reverse:
            if adb_reverse(args.serial, args.port):
                print(f"adb reverse tcp:{args.port} tcp:{args.port} -> OK")
            else:
                print(f"adb reverse tcp:{args.port} tcp:{args.port} -> FAILED (adb unavailable or device offline)")
        print("Serving... (Ctrl+C to stop)")
        try:
            while True:
                time.sleep(1)
        except KeyboardInterrupt:
            pass
        finally:
            server.shutdown()
        return

    ensure_fixture_dir()
    generate_wav(WAV_PATH)

    if args.apk:
        if not args.apk.exists():
            print(f"APK not found: {args.apk}", file=sys.stderr)
            sys.exit(1)
        try:
            subprocess.run(["adb", "-s", args.serial, "install", "-r", str(args.apk)],
                           check=True, capture_output=True)
            print(f"APK installed: {args.apk}")
        except subprocess.CalledProcessError as e:
            print(f"APK install failed: {e.stderr.decode().strip()}", file=sys.stderr)
            sys.exit(1)

    if not args.no_reverse:
        if not adb_reverse(args.serial, args.port):
            print("Warning: adb reverse failed", file=sys.stderr)

    ready = threading.Event()
    server = run_server(args.port, ready)
    if not ready.wait(5):
        print("Server failed to start", file=sys.stderr)
        sys.exit(1)
    print(f"Server ready on http://{SERVER_HOST}:{args.port}/")
    print(f"WAV: {WAV_PATH} ({WAV_PATH.stat().st_size} bytes)")

    if args.sample_seconds and args.output_dir:
        args.output_dir.mkdir(parents=True, exist_ok=True)
        pid = get_pid(args.serial)
        if pid is None:
            print(f"Package {PKG} not running", file=sys.stderr)
        else:
            print(f"Capturing evidence for {args.sample_seconds}s (pid={pid})...")
            logcat_path = capture_logcat(args.serial, pid, args.output_dir, args.sample_seconds)
            summary_path, frames_path = capture_gfxinfo(args.serial, args.output_dir)
            sf_result = capture_surfaceflinger_latency(args.serial, args.output_dir)
            parsed = parse_gfxinfo_summary(summary_path)

            import json
            meta = {
                "package": PKG,
                "pid": pid,
                "sample_seconds": args.sample_seconds,
                "logcat": str(logcat_path),
                "gfxinfo_summary": str(summary_path),
                "gfxinfo_framestats": str(frames_path),
                "parsed": parsed,
                "note": "Values from dumpsys gfxinfo/surfaceflinger; not a Flutter FPS measurement"
            }
            if sf_result:
                sf_path, surface_name = sf_result
                meta["surfaceflinger_latency"] = str(sf_path)
                meta["surfaceflinger_surface"] = surface_name
            meta_path = args.output_dir / "evidence_summary.json"
            meta_path.write_text(json.dumps(meta, indent=2))
            print(f"Evidence written to {args.output_dir}")
            for k, v in parsed.items():
                print(f"  {k}: {v}")

    if not args.sample_seconds:
        print("Serving... (Ctrl+C to stop)")
        try:
            while True:
                time.sleep(1)
        except KeyboardInterrupt:
            pass
    server.shutdown()


if __name__ == "__main__":
    main()