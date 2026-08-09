# Code Sandbox Deployment

The app can work in three levels:

1. Offline study mode inside Flutter.
2. Local trusted execution without Docker.
3. Production execution with Docker isolation.

## 1. Offline study mode

No server is required.

Students can use the Code tab and press `Visualize` to see code flow line by
line. This is for studying and explanation, not real execution.

## 2. Run without Docker

Use this on your own machine or a trusted classroom laptop only.

Requirements:

- Python installed.
- For C++, install `g++` and make sure it exists in `PATH`.

Start the local sandbox:

```powershell
cd D:\flutter_application_1\sandbox_server
py -3 server.py --host 127.0.0.1 --port 8787
```

Run Flutter:

```powershell
flutter run --dart-define=CODE_SANDBOX_URL=http://127.0.0.1:8787
```

For Android emulator, the app automatically maps `127.0.0.1` to `10.0.2.2`
through `AppConfig`.

This mode is not safe for public student submissions because code runs on the
host machine.

## 3. Production Docker sandbox

Use this when students can submit code online.

Recommended deployment:

- Use a separate VPS/VM dedicated only to code execution.
- Do not deploy it on the database server.
- Put HTTPS in front of it using Nginx/Caddy/Cloudflare Tunnel.
- Keep the service private if possible, and point the app to its URL.

Start service:

```bash
cd sandbox_server
export SANDBOX_API_KEY="replace-with-a-long-random-secret"
docker compose -f docker-compose.production.yml up --build -d
docker pull python:3.12-alpine
docker pull gcc:14-bookworm
```

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

Run Flutter against production sandbox:

```powershell
flutter run --dart-define=CODE_SANDBOX_URL=https://sandbox.your-domain.com
```

If `SANDBOX_API_KEY` is enabled on the server, run Flutter with:

```powershell
flutter run --dart-define=CODE_SANDBOX_URL=https://sandbox.your-domain.com --dart-define=CODE_SANDBOX_API_KEY=replace-with-a-long-random-secret
```

Production runner limits:

- One ephemeral Docker container per run.
- Network disabled inside runner containers.
- Memory limit: `128m`.
- CPU limit: `0.5`.
- PID limit: `64`.
- Dropped Linux capabilities.
- No privilege escalation.
- Read-only root filesystem.
- Small temporary `/tmp`.
- Python run timeout: 5 seconds.
- C++ compile timeout: 10 seconds.
- Code size limit: 20 KB.
- stdin size limit: 4 KB.
- Optional API key header: `X-Sandbox-Key`.
- IP rate limit: 30 requests per minute by default.
- JSON logs for rejected and completed runs.

Important security note:

The production service mounts `/var/run/docker.sock` so it can create runner
containers. That gives it powerful control over Docker on that host. Use a
dedicated server for this service.

## Student experience

The Code tab is designed for learning:

- `Visualize` shows a line-by-line educational trace.
- `Run preview` works without a server and summarizes the code.
- `Run code` sends code to the configured sandbox and returns stdout/stderr.
- Challenges compare stdout against teacher-defined test cases.
