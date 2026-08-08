# Educational Academy Platform - Non-Functional Requirements (NON_FUNCTIONAL_REQUIREMENTS.md)

## 1. Performance & Response Time SLAs
- **UI Render Latency:** All Flutter views must render initial frame in under 16ms (60 FPS minimum, 120 FPS supported on modern mobile/desktop hardware).
- **API Response Times:** 
  - Standard REST/Postgrest queries: 95th percentile $< 200\text{ ms}$.
  - Auth token verification: $< 100\text{ ms}$.
  - Code Playground execution latency: $< 2.5\text{ s}$ total roundtrip.
- **Offline Resilience:** Local caching via `shared_preferences` / SQLite storage allowing students to view previously downloaded PDFs and cached lessons without network connectivity.

---

## 2. Security & RLS Enforcement Architecture

### 2.1 Critical Security Principle: Client vs Server Security Boundaries
> [!CAUTION]
> **Client-Side `RbacGuard` is NOT a Security Boundary:**
> Flutter client-side route guards (`RbacGuard`, screen redirects, button hiding) exist exclusively for User Experience (UX) and navigation control.
> They DO NOT constitute an authorization security boundary. 
> 
> All actual data security and privilege escalation protection MUST be enforced strictly by:
> 1. PostgreSQL Row Level Security (RLS) policies evaluated on the database server.
> 2. Supabase Storage bucket access control policies.
> 3. Server-side Edge Functions / Postgres Functions for privileged operations.

### 2.2 Row Level Security (RLS) Requirements
- 100% of public schema tables (`profiles`, `branches`, `subjects`, `groups`, `enrollments`, `lessons`, `homework`, `submissions`, `exams`, `attendance`, `invoices`, `payments`, `messages`, `study_telemetry_events`) MUST have RLS enabled (`ALTER TABLE ... ENABLE ROW LEVEL SECURITY;`).
- Client requests using `anon_key` or authenticated JWTs MUST satisfy RLS predicates for `SELECT`, `INSERT`, `UPDATE`, `DELETE`.
- Direct database connection strings or `service_role` keys MUST NEVER be bundled inside any Flutter app artifact or web client script.

---

## 3. Code Playground Sandbox Isolation Requirements
- Code execution MUST occur inside ephemeral containerized microservices (Docker/gVisor runtime).
- Container resource limits per run:
  - Memory: 128 MB max.
  - CPU: 0.5 vCPU max.
  - Disk: Ephemeral read-only root with 10MB tmpfs for script execution.
  - Network: Complete outbound network block (`--net none`) to prevent SSRF or port scanning attacks.
  - Execution Timeout: Hard kill after 5.0 seconds.

---

## 4. Real-Time & Push Notification Scalability
- Realtime Supabase WebSockets configured with channel filters for direct 1-on-1 chat and group announcements.
- Push Notifications powered by Firebase Cloud Messaging (FCM) / APNs with token lifecycle management.
- System must support up to 50,000 active concurrent WebSocket connections per branch deployment.

---

## 5. Storage & Media Streaming
- PDF files stored in encrypted Supabase Storage buckets with signed URL expiration (15 minute TTL).
- Video lessons streamed using adaptive bitrate HLS / MP4 with chunked caching.
