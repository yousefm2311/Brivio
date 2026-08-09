# Academy Code Sandbox

Local HTTP server used by the Study Workspace code playground.

See `docs/CODE_SANDBOX_DEPLOYMENT.md` for the full no-Docker and Docker
deployment guide.

## Local trusted mode

```powershell
cd D:\flutter_application_1\sandbox_server
py -3 server.py --host 127.0.0.1 --port 8787
```

Run Flutter with:

```powershell
flutter run --dart-define=CODE_SANDBOX_URL=http://127.0.0.1:8787
```

Android emulator traffic is automatically mapped to `10.0.2.2` by `AppConfig`.

Python uses the same Python executable that starts this server. C++ requires `g++`
to be installed and available in `PATH`.

This mode is only for trusted local development.

## Production Docker mode

Use production mode when real students can submit code. It keeps the public API
the same (`GET /health`, `POST /run`) but executes every run inside an ephemeral
Docker container.

```bash
cd sandbox_server
docker compose -f docker-compose.production.yml up --build -d
docker pull python:3.12-alpine
docker pull gcc:14-bookworm
```

Run Flutter with the public HTTPS URL of this service:

```powershell
flutter run --dart-define=CODE_SANDBOX_URL=https://sandbox.your-domain.com
```

With API key enabled:

```powershell
flutter run --dart-define=CODE_SANDBOX_URL=https://sandbox.your-domain.com --dart-define=CODE_SANDBOX_API_KEY=replace-with-a-long-random-secret
```

Current production limits:

- No network inside runner containers: `--network none`
- Memory limit: `128m`
- CPU limit: `0.5`
- PID limit: `64`
- Dropped Linux capabilities: `--cap-drop ALL`
- No privilege escalation: `no-new-privileges`
- Read-only runner root filesystem with small `/tmp`
- Per-request timeout: 5 seconds
- C++ compile timeout: 10 seconds
- Code size limit: 20 KB
- stdin size limit: 4 KB
- Optional API key header: `X-Sandbox-Key`
- IP rate limit: 30 requests/minute by default
- JSON execution logs

Health check:

```bash
curl http://127.0.0.1:8787/health
```

Run test:

```bash
curl -X POST http://127.0.0.1:8787/run \
  -H "Content-Type: application/json" \
  -d '{"language":"python","code":"print(2 + 2)","stdin":""}'
```

Deploy this service on a dedicated host or VM. Mounting the Docker socket gives
the service control over Docker on that host, so do not colocate it with the
database or other sensitive production workloads.
