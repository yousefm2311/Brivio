# Academy Code Sandbox

Local HTTP server used by the Study Workspace code playground.

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

This server is suitable for local trusted use. Production code execution should
run inside isolated containers with CPU, memory, network, and filesystem limits.
