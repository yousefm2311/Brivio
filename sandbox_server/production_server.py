#!/usr/bin/env python3
import argparse
import json
import os
import secrets
import shutil
import stat
import subprocess
import tempfile
import time
from collections import defaultdict, deque
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer


MAX_CODE_BYTES = int(os.getenv("SANDBOX_MAX_CODE_BYTES", "20000"))
MAX_STDIN_BYTES = int(os.getenv("SANDBOX_MAX_STDIN_BYTES", "4000"))
RUN_TIMEOUT_SECONDS = int(os.getenv("SANDBOX_RUN_TIMEOUT_SECONDS", "5"))
COMPILE_TIMEOUT_SECONDS = int(os.getenv("SANDBOX_COMPILE_TIMEOUT_SECONDS", "10"))
MEMORY_LIMIT = os.getenv("SANDBOX_MEMORY_LIMIT", "128m")
CPU_LIMIT = os.getenv("SANDBOX_CPU_LIMIT", "0.5")
PIDS_LIMIT = os.getenv("SANDBOX_PIDS_LIMIT", "64")
PYTHON_IMAGE = os.getenv("SANDBOX_PYTHON_IMAGE", "python:3.12-alpine")
CPP_IMAGE = os.getenv("SANDBOX_CPP_IMAGE", "gcc:14-bookworm")
DART_IMAGE = os.getenv("SANDBOX_DART_IMAGE", "dart:stable")
API_KEY = os.getenv("SANDBOX_API_KEY", "").strip()
RATE_LIMIT_PER_MINUTE = int(os.getenv("SANDBOX_RATE_LIMIT_PER_MINUTE", "30"))
_REQUEST_LOG = defaultdict(deque)


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


def _client_ip(handler):
    forwarded = handler.headers.get("X-Forwarded-For", "")
    if forwarded:
        return forwarded.split(",")[0].strip()
    return handler.client_address[0]


def _log_event(event, **fields):
    payload = {"event": event, "ts": int(time.time()), **fields}
    print(json.dumps(payload, sort_keys=True), flush=True)


def _is_authorized(handler):
    if not API_KEY:
        return True
    provided = handler.headers.get("X-Sandbox-Key", "").strip()
    return secrets.compare_digest(provided, API_KEY)


def _rate_limited(ip):
    now = time.time()
    bucket = _REQUEST_LOG[ip]
    while bucket and now - bucket[0] > 60:
        bucket.popleft()
    if len(bucket) >= RATE_LIMIT_PER_MINUTE:
        return True
    bucket.append(now)
    return False


def _base_docker_args(image, workdir):
    return [
        "docker",
        "run",
        "--rm",
        "--network",
        "none",
        "--memory",
        MEMORY_LIMIT,
        "--memory-swap",
        MEMORY_LIMIT,
        "--cpus",
        CPU_LIMIT,
        "--pids-limit",
        PIDS_LIMIT,
        "--cap-drop",
        "ALL",
        "--security-opt",
        "no-new-privileges",
        "--read-only",
        "--tmpfs",
        "/tmp:rw,noexec,nosuid,size=16m",
        "--user",
        "65534:65534",
        "-v",
        f"{workdir}:/workspace:rw",
        "-w",
        "/workspace",
        image,
    ]


def _run_docker(command, timeout, stdin=""):
    started = time.perf_counter()
    try:
        process = subprocess.run(
            command,
            input=stdin,
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


def _prepare_workdir():
    workdir = tempfile.mkdtemp(prefix="academy_prod_sandbox_")
    os.chmod(
        workdir,
        stat.S_IRWXU
        | stat.S_IRWXG
        | stat.S_IRWXO,
    )
    return workdir


def _run_python(workdir, code, stdin):
    script_path = os.path.join(workdir, "main.py")
    with open(script_path, "w", encoding="utf-8") as handle:
        handle.write(code)
    os.chmod(script_path, 0o644)
    command = [
        *_base_docker_args(PYTHON_IMAGE, workdir),
        "python",
        "/workspace/main.py",
    ]
    return _run_docker(command, RUN_TIMEOUT_SECONDS, stdin)


def _run_cpp(workdir, code, stdin):
    source_path = os.path.join(workdir, "main.cpp")
    with open(source_path, "w", encoding="utf-8") as handle:
        handle.write(code)
    os.chmod(source_path, 0o644)

    exe_name = f"main_{secrets.token_hex(6)}"
    compile_command = [
        *_base_docker_args(CPP_IMAGE, workdir),
        "g++",
        "/workspace/main.cpp",
        "-std=c++17",
        "-O2",
        "-pipe",
        "-o",
        f"/workspace/{exe_name}",
    ]
    compile_result = _run_docker(compile_command, COMPILE_TIMEOUT_SECONDS)
    if not compile_result["success"]:
        return compile_result

    exe_path = os.path.join(workdir, exe_name)
    if os.path.exists(exe_path):
        os.chmod(exe_path, 0o755)

    run_command = [
        *_base_docker_args(CPP_IMAGE, workdir),
        f"/workspace/{exe_name}",
    ]
    return _run_docker(run_command, RUN_TIMEOUT_SECONDS, stdin)


def _run_dart(workdir, code, stdin):
    script_path = os.path.join(workdir, "main.dart")
    with open(script_path, "w", encoding="utf-8") as handle:
        handle.write(code)
    os.chmod(script_path, 0o644)
    command = [
        *_base_docker_args(DART_IMAGE, workdir),
        "dart",
        "run",
        "/workspace/main.dart",
    ]
    return _run_docker(command, RUN_TIMEOUT_SECONDS, stdin)


class ProductionSandboxHandler(BaseHTTPRequestHandler):
    def log_message(self, fmt, *args):
        print("%s - %s" % (self.address_string(), fmt % args))

    def do_OPTIONS(self):
        _json_response(self, 200, {"ok": True})

    def do_GET(self):
        if self.path == "/health":
            docker_ready = shutil.which("docker") is not None
            _json_response(
                self,
                200 if docker_ready else 503,
                {
                    "ok": docker_ready,
                    "service": "academy-code-sandbox",
                    "mode": "production-docker",
                    "limits": {
                        "timeoutSeconds": RUN_TIMEOUT_SECONDS,
                        "compileTimeoutSeconds": COMPILE_TIMEOUT_SECONDS,
                        "memory": MEMORY_LIMIT,
                        "cpus": CPU_LIMIT,
                        "pids": PIDS_LIMIT,
                        "network": "none",
                        "rateLimitPerMinute": RATE_LIMIT_PER_MINUTE,
                        "apiKeyRequired": bool(API_KEY),
                    },
                },
            )
            return
        _json_response(self, 404, {"success": False, "error": "Not found"})

    def do_POST(self):
        if self.path != "/run":
            _json_response(self, 404, {"success": False, "error": "Not found"})
            return

        ip = _client_ip(self)
        if not _is_authorized(self):
            _log_event("sandbox_rejected", reason="unauthorized", ip=ip)
            _json_response(
                self,
                401,
                {
                    "success": False,
                    "stdout": "",
                    "stderr": "Unauthorized sandbox request.",
                    "exitCode": -1,
                    "durationMs": 0,
                },
            )
            return

        if _rate_limited(ip):
            _log_event("sandbox_rejected", reason="rate_limited", ip=ip)
            _json_response(
                self,
                429,
                {
                    "success": False,
                    "stdout": "",
                    "stderr": "Sandbox rate limit exceeded. Try again shortly.",
                    "exitCode": -1,
                    "durationMs": 0,
                },
            )
            return

        if shutil.which("docker") is None:
            _json_response(
                self,
                503,
                {
                    "success": False,
                    "stdout": "",
                    "stderr": "Docker CLI is not available to the sandbox service.",
                    "exitCode": -1,
                    "durationMs": 0,
                },
            )
            return

        workdir = None
        try:
            length = int(self.headers.get("Content-Length", "0"))
            raw_body = self.rfile.read(length)
            payload = json.loads(raw_body.decode("utf-8"))
            language = str(payload.get("language", "")).lower().strip()
            code = str(payload.get("code", ""))
            stdin = str(payload.get("stdin", ""))
            started = time.perf_counter()

            if len(code.encode("utf-8")) > MAX_CODE_BYTES:
                _log_event(
                    "sandbox_rejected",
                    reason="code_too_large",
                    ip=ip,
                    language=language,
                    codeBytes=len(code.encode("utf-8")),
                )
                _json_response(
                    self,
                    400,
                    {"success": False, "stderr": "Code is too large.", "exitCode": -1},
                )
                return
            if len(stdin.encode("utf-8")) > MAX_STDIN_BYTES:
                _log_event(
                    "sandbox_rejected",
                    reason="stdin_too_large",
                    ip=ip,
                    language=language,
                    stdinBytes=len(stdin.encode("utf-8")),
                )
                _json_response(
                    self,
                    400,
                    {"success": False, "stderr": "stdin is too large.", "exitCode": -1},
                )
                return

            workdir = _prepare_workdir()
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
            _log_event(
                "sandbox_run",
                ip=ip,
                language=language,
                success=result["success"],
                exitCode=result["exitCode"],
                durationMs=result.get("durationMs", 0),
                requestMs=int((time.perf_counter() - started) * 1000),
                codeBytes=len(code.encode("utf-8")),
            )
            _json_response(self, 200 if result["success"] else 400, result)
        except Exception as exc:
            _log_event("sandbox_error", ip=_client_ip(self), error=str(exc))
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
        finally:
            if workdir:
                shutil.rmtree(workdir, ignore_errors=True)


def main():
    parser = argparse.ArgumentParser(
        description="Academy production Docker code sandbox server"
    )
    parser.add_argument("--host", default=os.getenv("SANDBOX_HOST", "0.0.0.0"))
    parser.add_argument("--port", type=int, default=int(os.getenv("SANDBOX_PORT", "8787")))
    args = parser.parse_args()

    server = ThreadingHTTPServer((args.host, args.port), ProductionSandboxHandler)
    print(f"Production sandbox listening on http://{args.host}:{args.port}")
    print(
        "Each request runs in an ephemeral Docker container with no network, "
        "memory/CPU/PID limits, read-only rootfs, and dropped capabilities."
    )
    server.serve_forever()


if __name__ == "__main__":
    main()
