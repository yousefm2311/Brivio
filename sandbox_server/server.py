#!/usr/bin/env python3
import argparse
import json
import os
import shutil
import subprocess
import sys
import tempfile
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer


MAX_CODE_BYTES = 20000
MAX_STDIN_BYTES = 4000
RUN_TIMEOUT_SECONDS = 5
COMPILE_TIMEOUT_SECONDS = 10


def _json_response(handler, status, payload):
    body = json.dumps(payload).encode("utf-8")
    handler.send_response(status)
    handler.send_header("Content-Type", "application/json; charset=utf-8")
    handler.send_header("Access-Control-Allow-Origin", "*")
    handler.send_header("Access-Control-Allow-Headers", "Content-Type")
    handler.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
    handler.send_header("Content-Length", str(len(body)))
    handler.end_headers()
    handler.wfile.write(body)


def _run_process(command, cwd, stdin, timeout):
    started = time.perf_counter()
    try:
        process = subprocess.run(
            command,
            input=stdin,
            cwd=cwd,
            capture_output=True,
            text=True,
            timeout=timeout,
        )
        return {
            "success": process.returncode == 0,
            "stdout": process.stdout,
            "stderr": process.stderr,
            "exitCode": process.returncode,
            "durationMs": int((time.perf_counter() - started) * 1000),
        }
    except subprocess.TimeoutExpired as exc:
        return {
            "success": False,
            "stdout": exc.stdout or "",
            "stderr": f"Execution timed out after {timeout} seconds.",
            "exitCode": -1,
            "durationMs": int((time.perf_counter() - started) * 1000),
        }


def _run_python(workdir, code, stdin):
    script_path = os.path.join(workdir, "main.py")
    with open(script_path, "w", encoding="utf-8") as handle:
        handle.write(code)
    return _run_process([sys.executable, script_path], workdir, stdin, RUN_TIMEOUT_SECONDS)


def _run_cpp(workdir, code, stdin):
    compiler = shutil.which("g++")
    if compiler is None:
        return {
            "success": False,
            "stdout": "",
            "stderr": "g++ was not found. Install MinGW-w64 or GCC to run C++ code.",
            "exitCode": -1,
            "durationMs": 0,
        }

    source_path = os.path.join(workdir, "main.cpp")
    exe_path = os.path.join(workdir, "main.exe" if os.name == "nt" else "main")
    with open(source_path, "w", encoding="utf-8") as handle:
        handle.write(code)

    compile_result = _run_process(
        [compiler, source_path, "-std=c++17", "-O2", "-pipe", "-o", exe_path],
        workdir,
        "",
        COMPILE_TIMEOUT_SECONDS,
    )
    if not compile_result["success"]:
        return compile_result

    return _run_process([exe_path], workdir, stdin, RUN_TIMEOUT_SECONDS)


def _run_dart(workdir, code, stdin):
    dart = shutil.which("dart")
    if dart is None:
        return {
            "success": False,
            "stdout": "",
            "stderr": "Dart SDK was not found. Install Dart/Flutter and ensure dart is available in PATH.",
            "exitCode": -1,
            "durationMs": 0,
        }

    source_path = os.path.join(workdir, "main.dart")
    with open(source_path, "w", encoding="utf-8") as handle:
        handle.write(code)
    return _run_process([dart, "run", source_path], workdir, stdin, RUN_TIMEOUT_SECONDS)


class SandboxHandler(BaseHTTPRequestHandler):
    def log_message(self, fmt, *args):
        print("%s - %s" % (self.address_string(), fmt % args))

    def do_OPTIONS(self):
        _json_response(self, 200, {"ok": True})

    def do_GET(self):
        if self.path == "/health":
            _json_response(self, 200, {"ok": True, "service": "academy-code-sandbox"})
            return
        _json_response(self, 404, {"success": False, "error": "Not found"})

    def do_POST(self):
        if self.path != "/run":
            _json_response(self, 404, {"success": False, "error": "Not found"})
            return

        try:
            length = int(self.headers.get("Content-Length", "0"))
            raw_body = self.rfile.read(length)
            payload = json.loads(raw_body.decode("utf-8"))
            language = str(payload.get("language", "")).lower().strip()
            code = str(payload.get("code", ""))
            stdin = str(payload.get("stdin", ""))

            if len(code.encode("utf-8")) > MAX_CODE_BYTES:
                _json_response(
                    self,
                    400,
                    {"success": False, "stderr": "Code is too large.", "exitCode": -1},
                )
                return
            if len(stdin.encode("utf-8")) > MAX_STDIN_BYTES:
                _json_response(
                    self,
                    400,
                    {"success": False, "stderr": "stdin is too large.", "exitCode": -1},
                )
                return

            with tempfile.TemporaryDirectory(prefix="academy_sandbox_") as workdir:
                if language in ("python", "py"):
                    result = _run_python(workdir, code, stdin)
                elif language in ("cpp", "c++"):
                    result = _run_cpp(workdir, code, stdin)
                elif language in ("dart",):
                    result = _run_dart(workdir, code, stdin)
                else:
                    result = {
                        "success": False,
                        "stdout": "",
                        "stderr": "Unsupported language. Use python, cpp, or dart.",
                        "exitCode": -1,
                        "durationMs": 0,
                    }
            _json_response(self, 200 if result["success"] else 400, result)
        except Exception as exc:
            _json_response(
                self,
                500,
                {
                    "success": False,
                    "stdout": "",
                    "stderr": str(exc),
                    "exitCode": -1,
                    "durationMs": 0,
                },
            )


def main():
    parser = argparse.ArgumentParser(description="Academy local code sandbox server")
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=8787)
    args = parser.parse_args()

    server = ThreadingHTTPServer((args.host, args.port), SandboxHandler)
    print(f"Sandbox server listening on http://{args.host}:{args.port}")
    print("Use only in a trusted local/dev environment. Deploy production sandboxing in containers.")
    server.serve_forever()


if __name__ == "__main__":
    main()
